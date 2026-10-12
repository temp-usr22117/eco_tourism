import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:eco_tourism/services/location_state_service.dart';

class AddTrailScreen extends StatefulWidget {
  const AddTrailScreen({super.key});

  @override
  State<AddTrailScreen> createState() => _AddTrailScreenState();
}

class _AddTrailScreenState extends State<AddTrailScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _policeController = TextEditingController(text: '112');
  final _ambulanceController = TextEditingController(text: '108');
  final _rescueController = TextEditingController(text: '1070');
  final _localContactController = TextEditingController();
  final _searchLocationController = TextEditingController();

  // Map & Location State
  final MapController _mapController = MapController();
  LatLng _selectedLocation = const LatLng(32.2598, 76.3526); // Default: Himachal/Dhauladhar
  bool _isLocating = false;
  bool _isSearchingLocation = false;
  List<dynamic> _searchResults = [];
  String _locationAddress = '';

  // Trail Attributes
  String _selectedDifficulty = 'MODERATE';
  final List<String> _difficultyLevels = ['EASY', 'MODERATE', 'HARD', 'EXTREME'];

  bool _isSaving = false;

  // Preset scenic cover images
  final List<Map<String, String>> _presetImages = [
    {
      'label': 'Snow Summit',
      'url':
          'https://images.unsplash.com/photo-1605649487212-47bdab064df7?auto=format&fit=crop&w=1000&q=80',
    },
    {
      'label': 'Himalayan Ridge',
      'url':
          'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?auto=format&fit=crop&w=1000&q=80',
    },
    {
      'label': 'Green Shola',
      'url':
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1000&q=80',
    },
    {
      'label': 'Alpine Valley',
      'url':
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1000&q=80',
    },
  ];

  // Preset safety tips selectable by the user
  final List<Map<String, dynamic>> _availableTips = [
    {
      'title': 'High Altitude & Cold Gear',
      'description':
          'Temperatures drop drastically near ridge summits. Carry insulated thermal layers and windproof jackets.',
      'type': 'SPECIFIC',
      'icon': 'ac_unit',
      'selected': true,
    },
    {
      'title': 'Carry Sufficient Drinking Water',
      'description':
          'Natural springs may be dry or unpotable. Trekkers should carry at least 2 liters of water.',
      'type': 'COMMON',
      'icon': 'water',
      'selected': true,
    },
    {
      'title': 'Forest Entry Permits',
      'description':
          'Check-in at the local forest range office or checkpoint before commencing the trek.',
      'type': 'COMMON',
      'icon': 'shield',
      'selected': false,
    },
    {
      'title': 'Sturdy Footwear Required',
      'description':
          'Steep scree slopes and loose rocks require high-ankle trekking shoes with good grip.',
      'type': 'COMMON',
      'icon': 'hiking',
      'selected': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initDefaultLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _imageUrlController.dispose();
    _policeController.dispose();
    _ambulanceController.dispose();
    _rescueController.dispose();
    _localContactController.dispose();
    _searchLocationController.dispose();
    super.dispose();
  }

  void _initDefaultLocation() {
    final cached = LocationStateService.getLastLocation();
    if (cached != null) {
      _selectedLocation = LatLng(cached.$1, cached.$2);
    }
  }

  Color _difficultyColor(String level) {
    switch (level) {
      case 'EASY':
        return Colors.greenAccent;
      case 'MODERATE':
        return Colors.amber;
      case 'HARD':
        return Colors.orangeAccent;
      case 'EXTREME':
        return Colors.redAccent;
      default:
        return Colors.greenAccent;
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'TrailSafe_EcoTourism_App/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _locationAddress = (data['display_name'] ?? '').toString();
          });
        }
      }
    } catch (_) {
      // Ignore reverse-geocode errors on network timeout
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location service disabled on device.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack('Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = point;
      });
      _mapController.move(point, 13);
      _fetchAddress(point.latitude, point.longitude);
    } catch (_) {
      _showSnack('Unable to detect current GPS location.');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearchingLocation = true;
      _searchResults = [];
    });

    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&limit=5';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'TrailSafe_EcoTourism_App/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() {
            _searchResults = data;
          });
        }
      }
    } catch (_) {
      _showSnack('Search request failed. Check your internet connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
        });
      }
    }
  }

  void _onSelectSearchResult(dynamic place) {
    final lat = double.tryParse(place['lat'].toString());
    final lon = double.tryParse(place['lon'].toString());

    if (lat == null || lon == null) return;

    final target = LatLng(lat, lon);
    setState(() {
      _selectedLocation = target;
      _locationAddress = (place['display_name'] ?? '').toString();
      _searchResults = [];
      _searchLocationController.clear();
    });

    _mapController.move(target, 14);
    FocusScope.of(context).unfocus();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        content: Text(msg),
      ),
    );
  }

  Future<void> _submitTrail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final trailName = _nameController.text.trim();

      // Normalize document ID from trail name (e.g., 'triund_trek')
      final normalizedId = trailName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');

      final safeDocId = normalizedId.isNotEmpty
          ? '${normalizedId}_${DateTime.now().millisecondsSinceEpoch % 10000}'
          : 'trail_${DateTime.now().millisecondsSinceEpoch}';

      final trailRef = firestore.collection('trails').doc(safeDocId);

      final bgImage = _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : _presetImages.first['url']!;

      final trailData = {
        'name': trailName,
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
        'baseStatus': _selectedDifficulty,
        'checkInCount': 0,
        'trailBg': bgImage,
        'aboutTrail': _aboutController.text.trim().isNotEmpty
            ? _aboutController.text.trim()
            : '$trailName is a scenic trail location. Follow live weather updates and crowd density before starting your hike.',
        'emergency': {
          'police': _policeController.text.trim().isNotEmpty
              ? _policeController.text.trim()
              : '112',
          'ambulance': _ambulanceController.text.trim().isNotEmpty
              ? _ambulanceController.text.trim()
              : '108',
          'rescue': _rescueController.text.trim().isNotEmpty
              ? _rescueController.text.trim()
              : '1070',
          'local_contact': _localContactController.text.trim(),
        },
        'lastUpdated': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = firestore.batch();
      batch.set(trailRef, trailData);

      // Save checked safety tips linked to this new trail
      int tipIdx = 0;
      for (final tip in _availableTips) {
        if (tip['selected'] == true) {
          final tipDoc = firestore
              .collection('safetyTips')
              .doc('${safeDocId}_tip_$tipIdx');
          batch.set(tipDoc, {
            'trailId': safeDocId,
            'title': tip['title'],
            'description': tip['description'],
            'type': tip['type'],
            'icon': tip['icon'],
            'createdAt': FieldValue.serverTimestamp(),
          });
          tipIdx++;
        }
      }

      await batch.commit();

      _showSnack('Trail "$trailName" successfully created!');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnack('Failed to save trail: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
        title: const Text(
          'Add New Trail',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _submitTrail,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.greenAccent,
                    ),
                  )
                : const Icon(Icons.check, color: Colors.greenAccent),
            label: Text(
              _isSaving ? 'Saving...' : 'Publish',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildSectionHeader(
              '1. TRAILHEAD LOCATION',
              subtitle: 'Tap anywhere on the map to drop the trail marker',
            ),
            const SizedBox(height: 8),
            _buildMapSection(),
            const SizedBox(height: 20),

            _buildSectionHeader('2. BASIC INFORMATION'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              label: 'Trail Name *',
              hint: 'e.g. Kedarkantha Summit Trek',
              icon: Icons.terrain,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a trail name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildDifficultySelector(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _aboutController,
              label: 'About this Trail',
              hint: 'Describe altitude, terrain, highlights, and route difficulty...',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('3. COVER PHOTO'),
            const SizedBox(height: 8),
            _buildImagePickerSection(),
            const SizedBox(height: 20),

            _buildSectionHeader(
              '4. EMERGENCY & LOCAL HELPLINES',
              subtitle: 'Contacts surfaced in the Emergency Hub during SOS',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _policeController,
                    label: 'Police',
                    hint: '112 / 100',
                    icon: Icons.shield_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _ambulanceController,
                    label: 'Ambulance',
                    hint: '108',
                    icon: Icons.medical_services_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _rescueController,
                    label: 'Mountain Rescue',
                    hint: '1070',
                    icon: Icons.emergency_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _localContactController,
                    label: 'Local Helpline',
                    hint: 'Forest checkpost / Base',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionHeader(
              '5. SAFETY PROTOCOLS & TIPS',
              subtitle: 'Select relevant guidelines to attach to this trail',
            ),
            const SizedBox(height: 8),
            _buildSafetyTipsSelector(),

            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSaving ? null : _submitTrail,
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'SAVING TO FIRESTORE...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'PUBLISH TRAIL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.1,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Locate Me Header
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _searchLocationController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search city or mountain...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                        suffixIcon: _isSearchingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                color: Colors.greenAccent,
                                onPressed: () =>
                                    _searchLocation(_searchLocationController.text),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: _searchLocation,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Use current GPS location',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.15),
                    foregroundColor: Colors.greenAccent,
                  ),
                  onPressed: _isLocating ? null : _useCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 20),
                ),
              ],
            ),
          ),

          // Search results popup list
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      place['display_name'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _onSelectSearchResult(place),
                  );
                },
              ),
            ),

          // Interactive Map Area
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 11,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                        _fetchAddress(point.latitude, point.longitude);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.eco_tourism',
                        tileDisplay: const TileDisplay.instantaneous(opacity: 0.9),
                      ),
                      TileLayer(
                        urlTemplate:
                            'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.eco_tourism',
                        tileDimension: 256,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.redAccent,
                              size: 46,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app, color: Colors.greenAccent, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Tap map to set pin',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Coordinates & Address Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Selected Coordinates:',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (_locationAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _locationAddress,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Difficulty Level',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Row(
          children: _difficultyLevels.map((level) {
            final isSelected = _selectedDifficulty == level;
            final color = _difficultyColor(level);

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDifficulty = level;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      level,
                      style: TextStyle(
                        color: isSelected ? color : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _imageUrlController,
          label: 'Cover Image URL',
          hint: 'Paste web image URL (or tap preset below)',
          icon: Icons.image_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Quick Presets:',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _presetImages.map((preset) {
              final isChosen = _imageUrlController.text == preset['url'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _imageUrlController.text = preset['url']!;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isChosen
                        ? Colors.greenAccent.withValues(alpha: 0.18)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChosen ? Colors.greenAccent : Colors.white24,
                    ),
                  ),
                  child: Text(
                    preset['label']!,
                    style: TextStyle(
                      color: isChosen ? Colors.greenAccent : Colors.white70,
                      fontSize: 11,
                      fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_imageUrlController.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _imageUrlController.text,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 60,
                color: Colors.white10,
                alignment: Alignment.center,
                child: const Text(
                  'Invalid Image URL',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSafetyTipsSelector() {
    return Column(
      children: _availableTips.map((tip) {
        final isSelected = tip['selected'] as bool;

        return GestureDetector(
          onTap: () {
            setState(() {
              tip['selected'] = !isSelected;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.greenAccent.withValues(alpha: 0.08)
                  : const Color(0xFF101827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white12,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.greenAccent : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip['title'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip['description'] as String,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.greenAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFF101827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.greenAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
