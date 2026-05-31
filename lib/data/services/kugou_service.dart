import 'dart:convert';
import 'dart:io';
import '../models/track.dart';

class KugouSearchResult {
  final String songName;
  final String singerName;
  final String albumName;
  final String hash;
  final String albumId;
  final int duration;

  KugouSearchResult({
    required this.songName,
    required this.singerName,
    required this.albumName,
    required this.hash,
    required this.albumId,
    required this.duration,
  });
}

class KugouLyricLine {
  final Duration time;
  final String text;
  KugouLyricLine({required this.time, required this.text});
}

class KugouService {
  final HttpClient _client = HttpClient();
  String? lastError;

  KugouService() {
    _client.connectionTimeout = const Duration(seconds: 8);
    _client.badCertificateCallback = (_, __, ___) => true;
  }

  Future<String> _httpGet(String url) async {
    final uri = Uri.parse(url);
    final request = await _client.getUrl(uri);
    request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    request.headers.set('Accept', '*/*');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return body;
  }

  // Diagnostic test
  Future<String> testConnection() async {
    final results = <String>[];
    try {
      final body = await _httpGet('http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=test&page=1&pagesize=1');
      results.add('Kugou search: OK (${body.length} bytes)');
    } catch (e) {
      results.add('Kugou search: FAIL - $e');
    }
    try {
      final body = await _httpGet('http://search.kuwo.cn/r.s?all=test&ft=music&pn=0&rn=1&rformat=json&encoding=utf8');
      results.add('Kuwo search: OK (${body.length} bytes)');
    } catch (e) {
      results.add('Kuwo search: FAIL - $e');
    }
    try {
      final body = await _httpGet('http://antiserver.kuwo.cn/anti.s?type=convert_url3&rid=MUSIC_247151&format=mp3&response=url');
      results.add('Kuwo play URL: OK - ${body.substring(0, body.length.clamp(0, 100))}');
    } catch (e) {
      results.add('Kuwo play URL: FAIL - $e');
    }
    return results.join('\n');
  }

  // Search songs
  Future<List<KugouSearchResult>> searchSongs(String keyword, {int page = 1, int pageSize = 20}) async {
    lastError = null;
    try {
      final url = 'http://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=${Uri.encodeComponent(keyword)}&page=$page&pagesize=$pageSize';
      final body = await _httpGet(url);
      final data = jsonDecode(body);
      return _parseSearchResponse(data);
    } catch (e) {
      lastError = 'Search error: $e';
      return [];
    }
  }

  List<KugouSearchResult> _parseSearchResponse(dynamic data) {
    if (data == null) return [];
    try {
      final info = data['data']?['info'];
      if (info == null || info is! List) return [];
      return info.map<KugouSearchResult>((item) {
        return KugouSearchResult(
          songName: (item['songname'] ?? item['filename'] ?? '').toString(),
          singerName: (item['singername'] ?? 'Unknown').toString(),
          albumName: (item['album_name'] ?? '').toString(),
          hash: (item['hash'] ?? item['320hash'] ?? '').toString(),
          albumId: (item['album_id'] ?? '').toString(),
          duration: item['duration'] is int ? item['duration'] as int : 0,
        );
      }).where((r) => r.hash.isNotEmpty).toList();
    } catch (e) {
      lastError = 'Parse error: $e';
      return [];
    }
  }

  // Get lyrics
  Future<List<KugouLyricLine>> getLyrics(String songName, String artist) async {
    try {
      final keyword = Uri.encodeComponent(' - ');
      final body = await _httpGet('http://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=$keyword');
      final data = jsonDecode(body);
      final candidates = data['candidates'];
      if (candidates == null || candidates is! List || candidates.isEmpty) return [];

      final candidate = candidates.first;
      final id = candidate['id']?.toString() ?? '';
      final accessKey = candidate['accesskey']?.toString() ?? '';
      if (id.isEmpty || accessKey.isEmpty) return [];

      final lyricsBody = await _httpGet(
        'http://lyrics.kugou.com/download?ver=1&client=pc&id=$id&accesskey=$accessKey&fmt=lrc&charset=utf8',
      );
      final lyricsData = jsonDecode(lyricsBody);
      if (lyricsData['content'] == null) return [];

      final content = utf8.decode(base64Decode(lyricsData['content'].toString()));
      return _parseLrc(content);
    } catch (e) {
      return [];
    }
  }

  List<KugouLyricLine> _parseLrc(String lrc) {
    final lines = <KugouLyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    for (final line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis = int.parse(match.group(3)!.padRight(3, '0'));
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(KugouLyricLine(time: Duration(minutes: minutes, seconds: seconds, milliseconds: millis), text: text));
        }
      }
    }
    return lines;
  }


  Future<List<KugouSearchResult>> getPlaylistSongs(String specialId, {int page = 1, int pageSize = 100}) async {
    try {
      final url = 'http://mobilecdn.kugou.com/api/v3/song/list?specialid=&page=&pagesize=';
      final body = await _httpGet(url);
      final data = jsonDecode(body);
      return _parseSearchResponse(data);
    } catch (_) {
      return [];
    }
  }
  Track resultToTrack(KugouSearchResult result, {String? playUrl}) {
    return Track(
      title: result.songName,
      artist: result.singerName,
      album: result.albumName,
      duration: Duration(seconds: result.duration),
      filePath: playUrl ?? '',
      kugouHash: result.hash,
    );
  }

  void dispose() {
    _client.close();
  }
}



