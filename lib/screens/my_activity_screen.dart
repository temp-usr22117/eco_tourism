import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eco_tourism/services/checkin_service.dart';
import 'package:eco_tourism/services/bookmark_service.dart';

class MyActivityScreen extends StatefulWidget {
  final int initialTab;

  const MyActivityScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;
  late Future<List<Map<String, dynamic>>> _savedTreksFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = CheckInService.getCheckInHistory();
    _savedTreksFuture = BookmarkService.getBookmarkedTrails();
    BookmarkService.bookmarkedIdsNotifier.addListener(_onBookmarksChanged);
  }

  @override
  void dispose() {
    BookmarkService.bookmarkedIdsNotifier.removeListener(_onBookmarksChanged);
    super.dispose();
  }

  void _onBookmarksChanged() {
    if (!mounted) return;
    setState(() {
      _savedTreksFuture = BookmarkService.getBookmarkedTrails();
    });
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _historyFuture = CheckInService.getCheckInHistory();
    });
    await _historyFuture;
  }

  Future<void> _refreshSavedTreks() async {
    setState(() {
      _savedTreksFuture = BookmarkService.getBookmarkedTrails();
    });
    await _savedTreksFuture;
  }

  Future<void> _undoCheckIn(Map<String, dynamic> item) async {
    final trailId = (item['trailId'] ?? '').toString();
    if (trailId.isEmpty) return;

    final result = await CheckInService.undoCheckIn(trailId);
    if (!mounted) return;

    if (result == UndoCheckInResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in undone. You can check in another trek now.')),
      );
      await _refreshHistory();
      return;
    }

    if (result == UndoCheckInResult.notCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trek is not currently active for this device.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to undo check-in right now.')),
    );
  }

  Future<void> _removeSavedTrek(String trailId, String trailName) async {
    await BookmarkService.removeBookmark(trailId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        content: Text('Removed "$trailName" from Wishlist'),
      ),
    );
    await _refreshSavedTreks();
  }

  Future<void> _openInMap(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available.')),
      );
      return;
    }

    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map application.')),
      );
    }
  }

  String _formatTime(String? rawIso) {
    final dt = DateTime.tryParse(rawIso ?? '');
    if (dt == null) return '--';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _difficultyColor(String status) {
    final s = status.toUpperCase();
    if (s == 'HARD' || s == 'EXTREME' || s == 'DANGER') return Colors.redAccent;
    if (s == 'MODERATE' || s == 'RISKY' || s == 'CAUTION') return Colors.amber;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.greenAccent,
          title: const Text(
            'My Activity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.greenAccent,
            indicatorWeight: 3,
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(
                icon: Icon(Icons.history_rounded, size: 20),
                text: 'Check-in History',
              ),
              Tab(
                icon: Icon(Icons.favorite_rounded, size: 20),
                text: 'Wishlist / Saved',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCheckInHistoryTab(),
            _buildSavedTreksTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.white38),
                  SizedBox(height: 12),
                  Text(
                    'No check-ins yet.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Check in to a trail to activate safety notifications and track your activity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshHistory,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final isActive = item['isActive'] == true;
              final trailName = (item['trailName'] ?? 'Unknown Trail').toString();
              final checkedAt = _formatTime(item['checkedInAt']?.toString());
              final undoneAt = _formatTime(item['undoneAt']?.toString());

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? Colors.cyanAccent : Colors.white24,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trailName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.cyanAccent.withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'UNDONE',
                            style: TextStyle(
                              color: isActive ? Colors.cyanAccent : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Checked in: $checkedAt',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (!isActive)
                      Text(
                        'Undone: $undoneAt',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    if (isActive) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _undoCheckIn(item),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          side: const BorderSide(color: Colors.orangeAccent),
                        ),
                        child: const Text(
                          'UNDO CHECK-IN',
                          style: TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSavedTreksTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _savedTreksFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final saved = snapshot.data!;
        if (saved.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.pinkAccent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Wishlist is Empty',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save your dream treks by tapping the heart icon on any trail card. They will stay saved offline so you can plan anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text(
                      'Browse Trails',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshSavedTreks,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final item = saved[index];
              final trailId = (item['id'] ?? '').toString();
              final name = (item['name'] ?? 'Unnamed Trail').toString();
              final status = (item['baseStatus'] ?? 'SAFE').toString().toUpperCase();
              final statusColor = _difficultyColor(status);
              final checkInCount = item['checkInCount']?.toString() ?? '0';
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lng = double.tryParse(item['lng']?.toString() ?? '');
              final about = (item['aboutTrail'] ?? '').toString();
              final savedAt = _formatTime(item['savedAt']?.toString());

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF101827),
                  borderRadius: BorderRadius.circular(18),
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
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(
                          'Check-ins: $checkInCount',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.bookmark_added_outlined, size: 14, color: Colors.pinkAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Saved: $savedAt',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    if (about.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        about,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white30),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _openInMap(lat, lng),
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('Map'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.pinkAccent),
                              foregroundColor: Colors.pinkAccent,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _removeSavedTrek(trailId, name),
                            icon: const Icon(Icons.favorite, size: 16),
                            label: const Text('Remove'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
