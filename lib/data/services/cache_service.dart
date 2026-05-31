import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/debug_log.dart';

class CacheService {
  static const _likedSongsBox = 'cache_liked_songs';
  static const _searchHistoryBox = 'cache_search_history';
  static const _queueBox = 'cache_queue';
  static const _lastTrackBox = 'cache_last_track';
  static const _recentlyPlayedBox = 'cache_recently_played';
  static const _authBox = 'netease_auth';

  static const allBoxNames = [
    _likedSongsBox,
    _searchHistoryBox,
    _queueBox,
    _lastTrackBox,
    _recentlyPlayedBox,
    _authBox,
  ];

  static Future<String> getCachePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}\\vibe_music';
    } catch (e) { return 'Unknown'; }
  }

  static Future<List<CacheItem>> getCacheItems() async {
    final items = <CacheItem>[];
    try {
      final b = await Hive.openBox(_likedSongsBox);
      final raw = b.get('songs') as String?;
      final count = raw != null ? (jsonDecode(raw) as List).length : 0;
      items.add(CacheItem(name: 'Liked Songs', description: '$count songs', sizeBytes: raw?.length ?? 0, boxName: _likedSongsBox, icon: Icons.favorite_rounded));
    } catch (_) { items.add(CacheItem(name: 'Liked Songs', description: 'Error', sizeBytes: 0, boxName: _likedSongsBox, icon: Icons.favorite_rounded)); }
    try {
      final b = await Hive.openBox(_searchHistoryBox);
      final h = (b.get('history') as List?)?.cast<String>() ?? [];
      items.add(CacheItem(name: 'Search History', description: '${h.length} keywords', sizeBytes: h.join('').length, boxName: _searchHistoryBox, icon: Icons.history_rounded));
    } catch (_) { items.add(CacheItem(name: 'Search History', description: 'Error', sizeBytes: 0, boxName: _searchHistoryBox, icon: Icons.history_rounded)); }
    try {
      final b = await Hive.openBox(_queueBox);
      final raw = b.get('tracks') as String?;
      final count = raw != null ? (jsonDecode(raw) as List).length : 0;
      items.add(CacheItem(name: 'Play Queue', description: '$count tracks', sizeBytes: raw?.length ?? 0, boxName: _queueBox, icon: Icons.queue_music_rounded));
    } catch (_) { items.add(CacheItem(name: 'Play Queue', description: 'Error', sizeBytes: 0, boxName: _queueBox, icon: Icons.queue_music_rounded)); }
    try {
      final b = await Hive.openBox(_lastTrackBox);
      final raw = b.get('track') as String?;
      items.add(CacheItem(name: 'Last Playing Track', description: (raw != null && raw.isNotEmpty) ? 'Saved' : 'Empty', sizeBytes: raw?.length ?? 0, boxName: _lastTrackBox, icon: Icons.play_circle_rounded));
    } catch (_) { items.add(CacheItem(name: 'Last Playing Track', description: 'Error', sizeBytes: 0, boxName: _lastTrackBox, icon: Icons.play_circle_rounded)); }
    try {
      final b = await Hive.openBox(_recentlyPlayedBox);
      final raw = b.get('tracks') as String?;
      final count = raw != null ? (jsonDecode(raw) as List).length : 0;
      items.add(CacheItem(name: 'Recently Played', description: '$count tracks', sizeBytes: raw?.length ?? 0, boxName: _recentlyPlayedBox, icon: Icons.history_rounded));
    } catch (_) { items.add(CacheItem(name: 'Recently Played', description: 'Error', sizeBytes: 0, boxName: _recentlyPlayedBox, icon: Icons.history_rounded)); }
    try {
      final b = await Hive.openBox(_authBox);
      final cookie = b.get('cookie') as String?;
      items.add(CacheItem(name: 'Login Session', description: (cookie != null && cookie.isNotEmpty) ? 'Saved' : 'Empty', sizeBytes: cookie?.length ?? 0, boxName: _authBox, icon: Icons.key_rounded));
    } catch (_) { items.add(CacheItem(name: 'Login Session', description: 'Error', sizeBytes: 0, boxName: _authBox, icon: Icons.key_rounded)); }
    return items;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> clearBox(String boxName) async {
    try { final box = await Hive.openBox(boxName); await box.clear(); } catch (_) {}
  }

  static Future<void> clearAll({bool includeAuth = false}) async {
    for (final name in includeAuth ? allBoxNames : allBoxNames.where((n) => n != _authBox)) { await clearBox(name); }
  }

  static Future<void> clearDataCache() async {
    await clearBox(_likedSongsBox); await clearBox(_searchHistoryBox);
    await clearBox(_queueBox); await clearBox(_lastTrackBox); await clearBox(_recentlyPlayedBox);
  }

  static Future<void> saveLikedSongs(List<Map<String, dynamic>> songs) async {
    try { final box = await Hive.openBox(_likedSongsBox); await box.put('songs', jsonEncode(songs)); await box.put('saved_at', DateTime.now().millisecondsSinceEpoch); } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadLikedSongs() async {
    try { final box = await Hive.openBox(_likedSongsBox); final raw = box.get('songs') as String?; if (raw == null || raw.isEmpty) return []; return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { return []; }
  }

  static Future<void> addSearchHistory(String keyword) async {
    try { final box = await Hive.openBox(_searchHistoryBox); final List<String> h = (box.get('history') as List?)?.cast<String>() ?? []; h.remove(keyword); h.insert(0, keyword); if (h.length > 30) h.removeLast(); await box.put('history', h); } catch (_) {}
  }

  static Future<List<String>> loadSearchHistory() async {
    try { final box = await Hive.openBox(_searchHistoryBox); return (box.get('history') as List?)?.cast<String>() ?? []; } catch (_) { return []; }
  }

  static Future<void> clearSearchHistory() async {
    try { final box = await Hive.openBox(_searchHistoryBox); await box.delete('history'); } catch (_) {}
  }

  static Future<void> saveQueue(List<Map<String, dynamic>> tracks, {int currentIndex = 0}) async {
    try { final box = await Hive.openBox(_queueBox); await box.put('tracks', jsonEncode(tracks)); await box.put('index', currentIndex); } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadQueue() async {
    try { final box = await Hive.openBox(_queueBox); final raw = box.get('tracks') as String?; final index = box.get('index') as int? ?? 0; if (raw == null || raw.isEmpty) return {'tracks': <Map<String, dynamic>>[], 'index': 0}; return {'tracks': (jsonDecode(raw) as List).cast<Map<String, dynamic>>(), 'index': index}; } catch (_) { return {'tracks': <Map<String, dynamic>>[], 'index': 0}; }
  }

  static Future<void> saveLastTrack(Map<String, dynamic> track, {int positionMs = 0}) async {
    try { final box = await Hive.openBox(_lastTrackBox); await box.put('track', jsonEncode(track)); await box.put('position_ms', positionMs); } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadLastTrack() async {
    try { final box = await Hive.openBox(_lastTrackBox); final raw = box.get('track') as String?; if (raw == null || raw.isEmpty) return null; final t = jsonDecode(raw) as Map<String, dynamic>; t['position_ms'] = box.get('position_ms') as int? ?? 0; return t; } catch (_) { return null; }
  }

  static Future<void> clearLastTrack() async {
    try { final box = await Hive.openBox(_lastTrackBox); await box.clear(); } catch (_) {}
  }

  static const int _maxRecentlyPlayed = 100;

  static Future<void> addRecentlyPlayed(Map<String, dynamic> track) async {
    try { final box = await Hive.openBox(_recentlyPlayedBox); final raw = box.get('tracks') as String?; final list = raw != null ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[]; list.removeWhere((t) => t['id'] == track['id']); list.insert(0, track); if (list.length > _maxRecentlyPlayed) list.removeLast(); await box.put('tracks', jsonEncode(list)); } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadRecentlyPlayed() async {
    try { final box = await Hive.openBox(_recentlyPlayedBox); final raw = box.get('tracks') as String?; if (raw == null || raw.isEmpty) return []; return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { return []; }
  }

  static Future<void> clearRecentlyPlayed() async {
    try { final box = await Hive.openBox(_recentlyPlayedBox); await box.clear(); } catch (_) {}
  }
}

class CacheItem {
  final String name;
  final String description;
  final int sizeBytes;
  final String boxName;
  final IconData icon;
  const CacheItem({required this.name, required this.description, required this.sizeBytes, required this.boxName, required this.icon});
  String get sizeText => CacheService.formatSize(sizeBytes);
}
