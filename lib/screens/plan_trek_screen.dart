import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:eco_tourism/services/weather_service.dart';
import 'package:eco_tourism/services/safety_service.dart';
import 'package:eco_tourism/widgets/safety_badge.dart';
import 'package:eco_tourism/services/location_state_service.dart';

class PlanTrekScreen extends StatefulWidget {
  const PlanTrekScreen({super.key});

  @override
  State<PlanTrekScreen> createState() => _PlanTrekScreenState();
}

class _PlanTrekScreenState extends State<PlanTrekScreen> {
  final TextEditingController _distanceController = TextEditingController();
  String _selectedStatus = 'ANY';
  String _selectedDifficulty = 'ANY';
  bool _loading = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _suggestedTrails = [];

  @override
  void initState() {
    super.initState();
    _initializePlanScreen();
  }

  Future<void> _initializePlanScreen() async {
    try {
      // Match Home screen flow by attempting location before first suggestions.
      await _ensureCurrentPosition();
    } catch (_) {
      // Keep suggestion flow resilient when location isn't ready yet.
    }

    if (!mounted) return;
    _planTrek();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _ensureCurrentPosition() async {
    if (_currentPosition != null) return;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      _currentPosition = lastKnown;
      LocationStateService.setLastLocation(lastKnown.latitude, lastKnown.longitude);
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );

    LocationStateService.setLastLocation(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  double? _calculateDistanceKm(double trailLat, double trailLng) {
    final originLat =
        _currentPosition?.latitude ?? LocationStateService.getLastLocation()?.$1;
    final originLng =
        _currentPosition?.longitude ?? LocationStateService.getLastLocation()?.$2;

    if (originLat == null || originLng == null) return null;

    return Geolocator.distanceBetween(
          originLat,
          originLng,
          trailLat,
          trailLng,
        ) /
        1000;
  }

  double? _calculatedDistanceFromCurrent(Map<String, dynamic> trail) {
    final lat = _trailLat(trail);
    final lng = _trailLng(trail);
    if (lat == null || lng == null) return null;

    // Same approach as Home screen: geodesic distance between current location and trail.
    return _calculateDistanceKm(lat, lng);
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  double? _trailLat(Map<String, dynamic> trail) {
    return _toDouble(trail['lat']) ?? _toDouble(trail['latitude']);
  }

  double? _trailLng(Map<String, dynamic> trail) {
    return _toDouble(trail['lng']) ?? _toDouble(trail['longitude']);
  }

  SafetyAssessment _trailSafety(Map<String, dynamic> trail) {
    final safety = trail['safety'];
    return safety is SafetyAssessment ? safety : SafetyAssessment.unknown;
  }

  String _trailDifficulty(Map<String, dynamic> trail) {
    // baseStatus in Firestore holds the trail's difficulty, not its safety.
    return (trail['baseStatus'] ?? 'UNKNOWN').toString().toUpperCase();
  }

  Future<Map<String, dynamic>> _enrichTrail(Map<String, dynamic> trail) async {
    final lat = _trailLat(trail);
    final lng = _trailLng(trail);

    trail['calculatedDistanceKm'] = _calculatedDistanceFromCurrent(trail);
    trail['safety'] = SafetyAssessment.unknown;

    if (lat == null || lng == null) return trail;

    try {
      final weather = await WeatherService().getTrailWeather(lat, lng);
      trail['safety'] = SafetyService.assess(weather);
    } catch (_) {
      // Leave as UNKNOWN — never fall back to difficulty as a safety signal.
    }
    return trail;
  }

  Future<void> _planTrek() async {
    final maxDistance = double.tryParse(_distanceController.text.trim());

    setState(() {
      _loading = true;
      _suggestedTrails = [];
    });

    try {
      // Only location-dependent filtering needs current GPS. If it fails, continue
      // without distance filtering instead of failing the whole suggestion flow.
      if (maxDistance != null) {
        try {
          await _ensureCurrentPosition();
        } catch (e) {
          debugPrint('[PLAN TREK] Location unavailable on device: $e');
        }

        final sharedLocation = LocationStateService.getLastLocation();
        if (_currentPosition == null && sharedLocation == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Open Home once to detect location, then filter by distance in Plan My Trek.'),
              ),
            );
          }
          setState(() {
            _suggestedTrails = [];
          });
          return;
        }
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance.collection('trails').get();
      } on FirebaseException catch (e) {
        debugPrint('[PLAN TREK] Firestore server read failed: ${e.code} ${e.message}');
        snapshot = await FirebaseFirestore.instance
            .collection('trails')
            .get(const GetOptions(source: Source.cache));
      }
      final trails = snapshot.docs.map<Map<String, dynamic>>((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      final enriched = await Future.wait(
        trails.map((trail) async {
          try {
            return await _enrichTrail(trail);
          } catch (_) {
            trail['calculatedDistanceKm'] = null;
            trail['safety'] = SafetyAssessment.unknown;
            return trail;
          }
        }),
      );

      final filtered = enriched.where((trail) {
        final status = _trailSafety(trail).label;
        final difficulty = _trailDifficulty(trail);
        final distance = (trail['calculatedDistanceKm'] as num?)?.toDouble();

        final statusOk = _selectedStatus == 'ANY' || status == _selectedStatus;
        final difficultyOk =
            _selectedDifficulty == 'ANY' || difficulty == _selectedDifficulty;
        final distanceOk =
          maxDistance == null || (distance != null && distance <= maxDistance);

        return statusOk && difficultyOk && distanceOk;
      }).toList();

      // Safest first (SAFE → RISKY → DANGER → UNKNOWN), then most popular.
      int safetyOrder(Map<String, dynamic> t) => switch (_trailSafety(t).level) {
            SafetyLevel.safe => 0,
            SafetyLevel.risky => 1,
            SafetyLevel.danger => 2,
            SafetyLevel.unknown => 3,
          };
      filtered.sort((a, b) {
        final bySafety = safetyOrder(a).compareTo(safetyOrder(b));
        if (bySafety != 0) return bySafety;
        final countA = (a['checkInCount'] is num) ? (a['checkInCount'] as num).toInt() : 0;
        final countB = (b['checkInCount'] is num) ? (b['checkInCount'] as num).toInt() : 0;
        return countB.compareTo(countA);
      });

      setState(() {
        _suggestedTrails = filtered;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch trek suggestions right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        title: const Text('Plan My Trek'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your preferences',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Max distance (km)',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              dropdownColor: const Color(0xFF121212),
              style: const TextStyle(color: Colors.white),
              items: const ['ANY', 'SAFE', 'RISKY', 'DANGER']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? 'ANY';
                });
              },
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedDifficulty,
              dropdownColor: const Color(0xFF121212),
              style: const TextStyle(color: Colors.white),
              items: const ['ANY', 'EASY', 'MODERATE', 'HARD', 'EXTREME']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value ?? 'ANY';
                });
              },
              decoration: InputDecoration(
                labelText: 'Difficulty',
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _planTrek,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(_loading ? 'Finding...' : 'Suggest Treks'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Suggested Treks',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_suggestedTrails.isEmpty && !_loading)
              const Text(
                'No suggestions yet. Set filters and tap Suggest Treks.',
                style: TextStyle(color: Colors.white60),
              ),
            ..._suggestedTrails.map((trail) {
              final name = (trail['name'] ?? 'Unnamed Trail').toString();
              final safety = _trailSafety(trail);
              final difficulty = _trailDifficulty(trail);
              final distance = (trail['calculatedDistanceKm'] as num?)?.toDouble();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SafetyBadge(assessment: safety, placeName: name, compact: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      safety.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: safety.color.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Difficulty',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          difficulty,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distance',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          distance != null ? '${distance.toStringAsFixed(1)} km' : 'N/A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
