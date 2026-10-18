import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkService {
  BookmarkService._();

  static const String _bookmarkedIdsKey = 'bookmarked_trail_ids';
  static const String _bookmarkedTrailsKey = 'bookmarked_trails_data';

  static final ValueNotifier<Set<String>> bookmarkedIdsNotifier =
      ValueNotifier<Set<String>>({});

  static Set<String>? _cachedIds;
  static Map<String, Map<String, dynamic>>? _cachedTrailData;

  /// Loads bookmarked trail IDs from SharedPreferences.
  static Future<Set<String>> getBookmarkedIds() async {
    if (_cachedIds != null) {
      return Set.from(_cachedIds!);
    }

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_bookmarkedIdsKey) ?? [];
    _cachedIds = list.toSet();
    bookmarkedIdsNotifier.value = Set.from(_cachedIds!);
    return Set.from(_cachedIds!);
  }

  /// Synchronous check using memory cache if available.
  static bool isBookmarkedSync(String trailId) {
    if (_cachedIds == null) return false;
    return _cachedIds!.contains(trailId);
  }

  /// Asynchronous check that loads from SharedPreferences if not cached.
  static Future<bool> isBookmarked(String trailId) async {
    final ids = await getBookmarkedIds();
    return ids.contains(trailId);
  }

  /// Toggles bookmark status for a trail.
  /// Returns `true` if added, `false` if removed.
  static Future<bool> toggleBookmark({
    required String trailId,
    Map<String, dynamic>? trailData,
  }) async {
    if (trailId.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final ids = await getBookmarkedIds();
    final trailsMap = await _loadTrailsDataMap(prefs);

    final isCurrentlySaved = ids.contains(trailId);

    if (isCurrentlySaved) {
      ids.remove(trailId);
      trailsMap.remove(trailId);
    } else {
      ids.add(trailId);
      final dataToSave = Map<String, dynamic>.from(trailData ?? {});
      dataToSave['id'] = trailId;
      dataToSave['savedAt'] = DateTime.now().toIso8601String();
      trailsMap[trailId] = dataToSave;
    }

    _cachedIds = ids;
    _cachedTrailData = trailsMap;

    await prefs.setStringList(_bookmarkedIdsKey, ids.toList());
    await prefs.setString(_bookmarkedTrailsKey, jsonEncode(trailsMap));

    bookmarkedIdsNotifier.value = Set.from(ids);
    return !isCurrentlySaved;
  }

  /// Removes a trail from bookmarks.
  static Future<void> removeBookmark(String trailId) async {
    if (trailId.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final ids = await getBookmarkedIds();
    final trailsMap = await _loadTrailsDataMap(prefs);

    if (ids.remove(trailId)) {
      trailsMap.remove(trailId);
      _cachedIds = ids;
      _cachedTrailData = trailsMap;

      await prefs.setStringList(_bookmarkedIdsKey, ids.toList());
      await prefs.setString(_bookmarkedTrailsKey, jsonEncode(trailsMap));

      bookmarkedIdsNotifier.value = Set.from(ids);
    }
  }

  /// Retrieves list of all bookmarked trails from local cache (offline first).
  static Future<List<Map<String, dynamic>>> getBookmarkedTrails() async {
    final prefs = await SharedPreferences.getInstance();
    final trailsMap = await _loadTrailsDataMap(prefs);
    final ids = await getBookmarkedIds();

    final List<Map<String, dynamic>> results = [];
    for (final id in ids) {
      if (trailsMap.containsKey(id)) {
        results.add(trailsMap[id]!);
      } else {
        results.add({
          'id': id,
          'name': 'Saved Trail',
          'baseStatus': 'SAFE',
          'savedAt': DateTime.now().toIso8601String(),
        });
      }
    }

    // Sort by savedAt descending (most recently saved first)
    results.sort((a, b) {
      final aDate = DateTime.tryParse((a['savedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['savedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return results;
  }

  static Future<Map<String, Map<String, dynamic>>> _loadTrailsDataMap(
    SharedPreferences prefs,
  ) async {
    if (_cachedTrailData != null) {
      return _cachedTrailData!;
    }

    final rawJson = prefs.getString(_bookmarkedTrailsKey);
    if (rawJson == null || rawJson.isEmpty) {
      _cachedTrailData = {};
      return _cachedTrailData!;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final parsed = <String, Map<String, dynamic>>{};
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            parsed[key] = value;
          } else if (value is Map) {
            parsed[key] = Map<String, dynamic>.from(value);
          }
        });
        _cachedTrailData = parsed;
        return _cachedTrailData!;
      }
    } catch (_) {
      _cachedTrailData = {};
    }

    _cachedTrailData = {};
    return _cachedTrailData!;
  }
}
