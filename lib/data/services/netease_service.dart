import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/track.dart';
import '../../core/utils/debug_log.dart';

class NeteaseSearchResult {
  final int id;
  final String songName;
  final String artistName;
  final String albumName;
  final int duration;
  final String? coverUrl;
  final int fee;

  NeteaseSearchResult({
    required this.id,
    required this.songName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    this.coverUrl,
    this.fee = 0,
  });
}

class NeteaseLyricLine {
  final Duration time;
  final String text;
  NeteaseLyricLine({required this.time, required this.text});
}

class NeteaseApiService {
  static const String _baseUrl = 'http://127.0.0.1:3000';
  final HttpClient _client = HttpClient();
  String? lastError;
  String? _cookie;
  int? _userId;
  String? _nickname;

  NeteaseApiService() {
    _client.connectionTimeout = const Duration(seconds: 10);
    _client.badCertificateCallback = (_, __, ___) => true;
    _loadSavedCookie();
  }

  String get nickname => _nickname ?? '';
  int? get userId => _userId;
  bool get isLoggedIn => _cookie != null && _cookie!.isNotEmpty;
  String? get cookie => _cookie;

  /// Load saved cookie from Hive on startup
  Future<void> _loadSavedCookie() async {
    try {
      final box = await Hive.openBox('netease_auth');
      final savedCookie = box.get('cookie') as String?;
      if (savedCookie != null && savedCookie.isNotEmpty) {
        _cookie = _cleanCookie(savedCookie);
        DebugLog.log('Cookie loaded (${_cookie!.length} chars)');
        if (_cookie!.contains('MUSIC_U')) {
          DebugLog.log('Cookie has MUSIC_U ✓');
        } else {
          DebugLog.log('Cookie MISSING MUSIC_U ✗');
        }
        // Re-save cleaned version
        Hive.openBox('netease_auth').then((box) => box.put('cookie', _cookie));
        await getUserInfo();
      }
    } catch (e) {
      DebugLog.log('Failed to load cookie: $e');
    }
  }

  static String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
    return url;
  }

  Future<bool> checkServer() async {
    try {
      // Quick port check first
      final socket = await Socket.connect('127.0.0.1', 3000, timeout: const Duration(seconds: 2));
      await socket.close();
      return true;
    } catch (e) {
      DebugLog.log('Server check failed: $e');
      return false;
    }
  }

  // ── Login ──

  Future<String?> getQrKey() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final body = await _httpGet('$_baseUrl/login/qr/key?timestamp=$ts');
      final data = jsonDecode(body);
      if (data['code'] == 200) return data['data']['unikey'] as String?;
      lastError = 'QR key error: code=${data['code']}';
      return null;
    } catch (e) {
      lastError = 'QR key error: $e';
      return null;
    }
  }

  Future<String?> createQrCode(String key) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final body = await _httpGet('$_baseUrl/login/qr/create?key=${Uri.encodeComponent(key)}&qrimg=true&timestamp=$ts');
      final data = jsonDecode(body);
      if (data['code'] == 200) return data['data']['qrimg'] as String?;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> checkQrStatus(String key) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final body = await _httpGet('$_baseUrl/login/qr/check?key=${Uri.encodeComponent(key)}&timestamp=$ts');
      final data = jsonDecode(body);
      DebugLog.log('QR check: code=${data['code']}');
      return {
        'code': data['code'] ?? 0,
        'cookie': (data['cookie'] ?? '') as String,
        'message': data['message'] ?? '',
      };
    } catch (e) {
      DebugLog.log('QR check ERROR: $e');
      return {'code': -1, 'message': '$e'};
    }
  }

  Future<bool> loginWithPhone(String phone, String password) async {
    try {
      final body = await _httpGet('$_baseUrl/login/cellphone?phone=$phone&password=${Uri.encodeComponent(password)}');
      final data = jsonDecode(body);
      if (data['code'] == 200) {
        _cookie = data['cookie'] as String?;
        _userId = data['account']?['id'] as int?;
        _nickname = data['profile']?['nickname'] as String?;
        DebugLog.log('Netease login OK: $_nickname (id=$_userId)');
        if (_cookie != null) {
          DebugLog.log('Login cookie has MUSIC_U: ${_cookie!.contains('MUSIC_U')}');
          Hive.openBox('netease_auth').then((box) => box.put('cookie', _cookie));
        }
        return true;
      }
      lastError = 'Login failed: ${data['message'] ?? data['code']}';
      return false;
    } catch (e) {
      lastError = 'Login error: $e';
      return false;
    }
  }

  void setCookie(String rawCookie) {
    _cookie = _cleanCookie(rawCookie);
    DebugLog.log('Cookie set: ${_cookie!.length} chars, has MUSIC_U: ${_cookie!.contains('MUSIC_U')}');
    Hive.openBox('netease_auth').then((box) => box.put('cookie', _cookie));
  }

  /// Clean raw Set-Cookie string: keep only real cookie name=value pairs, strip Set-Cookie attributes
  static String _cleanCookie(String raw) {
    final attrs = {'max-age', 'expires', 'path', 'domain', 'secure', 'httponly', 'samesite', 'priority', 'comment', 'version'};
    final seen = <String>{};
    final clean = <String>[];
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) continue;
      final key = trimmed.substring(0, eqIdx).trim();
      final keyLower = key.toLowerCase();
      // Skip Set-Cookie attributes
      if (attrs.contains(keyLower)) continue;
      // Skip if value looks like a date (Expires attribute leaking through)
      final value = trimmed.substring(eqIdx + 1).trim();
      if (value.contains('GMT') || value.contains('Jan') || value.contains('Feb')) continue;
      // Deduplicate by key name (keep first occurrence)
      if (seen.contains(keyLower)) continue;
      seen.add(keyLower);
      clean.add('$key=$value');
    }
    return clean.join('; ');
  }

  Future<bool> getUserInfo() async {
    try {
      final body = await _httpGet('$_baseUrl/user/account?cookie=${Uri.encodeComponent(_cookie ?? '')}');
      final data = jsonDecode(body);
      if (data['code'] == 200 && data['account'] != null) {
        _userId = data['account']['id'] as int?;
        _nickname = data['profile']?['nickname'] as String?;
        final vipType = data['account']?['vipType'] as int? ?? 0;
        DebugLog.log('getUserInfo: $_nickname (id=$_userId, vipType=$vipType)');
        return true;
      }
      DebugLog.log('getUserInfo failed: code=${data['code']}');
      return false;
    } catch (e) {
      DebugLog.log('getUserInfo error: $e');
      return false;
    }
  }

  // ── Search ──

  Future<List<NeteaseSearchResult>> searchSongs(String keyword, {int limit = 20, int offset = 0}) async {
    lastError = null;
    DebugLog.log('Netease search: "$keyword"');
    try {
      final params = {'keywords': keyword, 'limit': '$limit', 'offset': '$offset'};
      if (_cookie != null && _cookie!.isNotEmpty) params['cookie'] = _cookie!;
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _httpGet('$_baseUrl/cloudsearch?$query&type=1');
      final data = jsonDecode(body);
      if (data['code'] != 200) {
        lastError = 'Search error: ${data['code']}';
        return [];
      }
      final songs = data['result']?['songs'] as List? ?? [];
      DebugLog.log('Netease found ${songs.length} songs');
      return songs.map<NeteaseSearchResult>((song) {
        final artists = song['ar'] as List? ?? [];
        final artistName = artists.map((a) => a['name'] ?? '').join('/');
        final album = song['al'] as Map? ?? {};
        final picUrl = album['picUrl'] as String?;
        final coverUrl = (picUrl != null && picUrl.isNotEmpty) ? '$picUrl?param=300y300' : null;
        return NeteaseSearchResult(
          id: song['id'] as int? ?? 0,
          songName: (song['name'] ?? '').toString(),
          artistName: artistName,
          albumName: (album['name'] ?? '').toString(),
          duration: song['dt'] as int? ?? 0,
          coverUrl: coverUrl != null ? _fixUrl(coverUrl) : null,
          fee: song['fee'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      lastError = 'Search error: $e';
      DebugLog.log('Netease search ERROR: $e');
      return [];
    }
  }

  // ── Play URL ──

  Future<String?> getPlayUrl(int songId, {int br = 320000}) async {
    lastError = null;
    DebugLog.log('getPlayUrl: id=$songId, br=$br');
    try {
      final params = {'id': '$songId', 'br': '$br'};
      if (_cookie != null && _cookie!.isNotEmpty) {
        params['cookie'] = _cookie!;
        DebugLog.log('  cookie len=${_cookie!.length}, MUSIC_U=${_cookie!.contains('MUSIC_U')}');
      } else {
        DebugLog.log('  NO cookie!');
      }
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _httpGet('$_baseUrl/song/url?$query');
      final data = jsonDecode(body);
      if (data['code'] != 200) {
        lastError = 'Play URL error: ${data['code']}';
        DebugLog.log('  API error: code=${data['code']}');
        return null;
      }
      final songData = data['data'] as List?;
      if (songData == null || songData.isEmpty) {
        lastError = 'No play data';
        return null;
      }
      final url = songData[0]['url'] as String?;
      final code = songData[0]['code'] as int?;
      final fee = songData[0]['fee'] as int? ?? 0;
      final freeTrialInfo = songData[0]['freeTrialInfo'];
      final type = songData[0]['type'] as String?;
      DebugLog.log('  result: code=$code, fee=$fee, type=$type, url=${url != null ? "YES(${url.length}chars)" : "NULL"}');
      if (freeTrialInfo != null) {
        DebugLog.log('  freeTrialInfo: $freeTrialInfo');
      }
      if (url == null || url.isEmpty) {
        lastError = 'Song requires VIP (code=$code)';
        return null;
      }
      // Check if URL is a 30-second preview
      if (freeTrialInfo != null) {
        DebugLog.log('  WARNING: 30s preview detected!');
      }
      DebugLog.log('  play OK: ${url.substring(0, url.length.clamp(0, 80))}');
      return url;
    } catch (e) {
      lastError = 'Play URL error: $e';
      DebugLog.log('getPlayUrl ERROR: $e');
      return null;
    }
  }

  // ── Lyrics ──

  Future<List<NeteaseLyricLine>> getLyrics(int songId) async {
    lastError = null;
    try {
      final params = {'id': '$songId'};
      if (_cookie != null && _cookie!.isNotEmpty) params['cookie'] = _cookie!;
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _httpGet('$_baseUrl/lyric?$query');
      final data = jsonDecode(body);
      if (data['code'] != 200) return [];
      final lrc = data['lrc']?['lyric'] as String?;
      if (lrc == null || lrc.isEmpty) return [];
      return _parseLrc(lrc);
    } catch (e) {
      lastError = 'Lyrics error: $e';
      return [];
    }
  }
  // ── Cloud Favorites ──

  Future<List<int>> getLikelist() async {
    if (!isLoggedIn || _userId == null) return [];
    try {
      final body = await _httpGet('$_baseUrl/likelist?uid=$_userId&cookie=${Uri.encodeComponent(_cookie!)}');
      final data = jsonDecode(body);
      if (data['code'] == 200) {
        final ids = data['ids'] as List? ?? [];
        return ids.map((id) => id as int).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> likeSong(int songId, {bool like = true}) async {
    if (!isLoggedIn) return false;
    try {
      final body = await _httpGet('$_baseUrl/like?id=$songId&like=$like&cookie=${Uri.encodeComponent(_cookie!)}');
      final data = jsonDecode(body);
      return data['code'] == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<NeteaseSearchResult>> getSongsDetail(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final idsStr = ids.join(',');
      final params = {'ids': idsStr};
      if (_cookie != null && _cookie!.isNotEmpty) params['cookie'] = _cookie!;
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _httpGet('$_baseUrl/song/detail?$query');
      final data = jsonDecode(body);
      if (data['code'] != 200) return [];
      final songs = data['songs'] as List? ?? [];
      return songs.map<NeteaseSearchResult>((song) {
        final artists = song['ar'] as List? ?? [];
        final artistName = artists.map((a) => a['name'] ?? '').join('/');
        final album = song['al'] as Map? ?? {};
        final picUrl = album['picUrl'] as String?;
        final coverUrl = (picUrl != null && picUrl.isNotEmpty) ? '$picUrl?param=300y300' : null;
        return NeteaseSearchResult(
          id: song['id'] as int? ?? 0,
          songName: (song['name'] ?? '').toString(),
          artistName: artistName,
          albumName: (album['name'] ?? '').toString(),
          duration: song['dt'] as int? ?? 0,
          coverUrl: coverUrl != null ? _fixUrl(coverUrl) : null,
          fee: song['fee'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Track resultToTrack(NeteaseSearchResult result, {String? playUrl}) {
    return Track(
      id: 'netease_${result.id}',
      title: result.songName,
      artist: result.artistName,
      album: result.albumName,
      duration: Duration(milliseconds: result.duration),
      filePath: playUrl ?? '',
      coverUrl: result.coverUrl,
    );
  }


  // ── User Playlists ──

  /// Get user's playlists from NetEase cloud
  Future<List<Map<String, dynamic>>> getUserPlaylists() async {
    if (!isLoggedIn || _userId == null) return [];
    try {
      final params = {'uid': '$_userId', 'limit': '50', 'offset': '0'};
      if (_cookie != null && _cookie!.isNotEmpty) params['cookie'] = _cookie!;
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _httpGet('$_baseUrl/user/playlist?$query');
      final data = jsonDecode(body);
      if (data['code'] != 200) return [];
      final list = data['playlist'] as List? ?? [];
      return list.map<Map<String, dynamic>>((p) => {
        'id': p['id'] as int? ?? 0,
        'name': (p['name'] ?? '').toString(),
        'coverUrl': _fixUrl(p['coverImgUrl'] as String?),
        'trackCount': p['trackCount'] as int? ?? 0,
        'creator': p['creator']?['userId'] as int?,
      }).toList();
    } catch (e) {
      DebugLog.log('getUserPlaylists error: $e');
      return [];
    }
  }

  /// Get all tracks in a playlist
  Future<List<NeteaseSearchResult>> getPlaylistTracks(int playlistId, {int limit = 1000}) async {
    try {
      final params = {'id': '$playlistId', 'limit': '$limit', 'offset': '0'};
      if (_cookie != null && _cookie!.isNotEmpty) params['cookie'] = _cookie!;
      final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final body = await _httpGet('$_baseUrl/playlist/track/all?$query');
      final data = jsonDecode(body);
      if (data['code'] != 200) return [];
      final songs = data['songs'] as List? ?? [];
      return songs.map<NeteaseSearchResult>((song) {
        final artists = song['ar'] as List? ?? [];
        final artistName = artists.map((a) => a['name'] ?? '').join('/');
        final album = song['al'] as Map? ?? {};
        final picUrl = album['picUrl'] as String?;
        final coverUrl = (picUrl != null && picUrl.isNotEmpty) ? '$picUrl?param=300y300' : null;
        return NeteaseSearchResult(
          id: song['id'] as int? ?? 0,
          songName: (song['name'] ?? '').toString(),
          artistName: artistName,
          albumName: (album['name'] ?? '').toString(),
          duration: song['dt'] as int? ?? 0,
          coverUrl: coverUrl != null ? _fixUrl(coverUrl) : null,
          fee: song['fee'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      DebugLog.log('getPlaylistTracks error: $e');
      return [];
    }
  }
  List<NeteaseLyricLine> _parseLrc(String lrc) {
    final lines = <NeteaseLyricLine>[];
    final timestampRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');
    for (final line in lrc.split('\n')) {
      final matches = timestampRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.replaceAll(timestampRegex, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final m = int.parse(match.group(1)!);
        final s = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0'));
        lines.add(NeteaseLyricLine(time: Duration(minutes: m, seconds: s, milliseconds: ms), text: text));
      }
    }
    return lines;
  }

  Future<String> _httpGet(String url) async {
    DebugLog.log('HTTP GET: ${url.substring(0, url.length.clamp(0, 120))}');
    final uri = Uri.parse(url);
    final request = await _client.getUrl(uri);
    request.headers.set('User-Agent', 'VibeMusic/1.0');
    request.headers.set('Accept', '*/*');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    DebugLog.log('HTTP ${response.statusCode}: ${body.length} bytes');
    return body;
  }

  void dispose() { _client.close(); }
}








