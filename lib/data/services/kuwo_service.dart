import 'dart:convert';
import 'dart:io';
import '../../core/utils/debug_log.dart';

class KuwoService {
  String? lastError;
  final HttpClient _client = HttpClient();

  KuwoService() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }

  Future<String> _httpGet(String url) async {
    DebugLog.log('HTTP GET: ' + url.substring(0, url.length.clamp(0, 120)));
    final uri = Uri.parse(url);
    final request = await _client.getUrl(uri);
    request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    DebugLog.log('HTTP ' + response.statusCode.toString() + ': ' + body.length.toString() + ' bytes');
    return body;
  }

  dynamic _parseJson(String raw) {
    // Kuwo returns single-quoted "JSON", fix it
    try {
      return jsonDecode(raw);
    } catch (_) {
      final fixed = raw.replaceAll("'", '"');
      return jsonDecode(fixed);
    }
  }

  Future<String?> searchForRid(String songName, String artist) async {
    lastError = null;
    DebugLog.log('Kuwo search: "' + songName + '" by "' + artist + '"');
    try {
      final keyword = Uri.encodeComponent(songName + ' ' + artist);
      final url = 'http://search.kuwo.cn/r.s?all=' + keyword + '&ft=music&itemset=web_2013&client=kt&pn=0&rn=5&rformat=json&encoding=utf8';
      final body = await _httpGet(url);
      final data = _parseJson(body);
      final abslist = data['abslist'];
      if (abslist == null || abslist is! List || abslist.isEmpty) {
        lastError = 'Kuwo: no results';
        DebugLog.log('Kuwo search: no abslist');
        return null;
      }

      DebugLog.log('Kuwo found ' + abslist.length.toString() + ' results');
      for (final item in abslist) {
        final name = (item['NAME'] ?? '').toString().replaceAll('&nbsp;', ' ');
        final artistName = (item['ARTIST'] ?? '').toString().replaceAll('\\u0026', '&');
        DebugLog.log('  -> ' + name + ' | ' + artistName + ' | ' + (item['MUSICRID'] ?? ''));
        if (name.toLowerCase().contains(songName.toLowerCase()) &&
            artistName.toLowerCase().contains(artist.toLowerCase())) {
          final rid = item['MUSICRID']?.toString();
          DebugLog.log('Kuwo matched: RID=' + (rid ?? 'null'));
          return rid;
        }
      }
      final fallback = abslist.first['MUSICRID']?.toString();
      DebugLog.log('Kuwo fallback: RID=' + (fallback ?? 'null'));
      return fallback;
    } catch (e) {
      lastError = 'Kuwo search: ' + e.toString();
      DebugLog.log('Kuwo search ERROR: ' + e.toString());
      return null;
    }
  }

  Future<String?> getPlayUrl(String rid) async {
    lastError = null;
    DebugLog.log('Kuwo getPlayUrl: RID=' + rid);
    try {
      final url = 'http://antiserver.kuwo.cn/anti.s?type=convert_url3&rid=' + rid + '&format=mp3&response=url';
      final body = await _httpGet(url);
      DebugLog.log('Kuwo play raw: ' + body.substring(0, body.length.clamp(0, 150)));

      try {
        final data = _parseJson(body);
        if (data is Map) {
          DebugLog.log('Kuwo play code=' + data['code'].toString() + ' url=' + (data['url']?.toString() ?? 'null'));
          if (data['code'] == 200) {
            final playUrl = data['url']?.toString();
            if (playUrl != null && playUrl.startsWith('http')) {
              DebugLog.log('Kuwo play OK');
              return playUrl;
            }
          }
        }
      } catch (_) {}

      final trimmed = body.trim();
      if (trimmed.startsWith('http')) {
        DebugLog.log('Kuwo play plain URL');
        return trimmed;
      }

      lastError = 'Kuwo play: bad response';
      DebugLog.log('Kuwo play: no URL in response');
      return null;
    } catch (e) {
      lastError = 'Kuwo play: ' + e.toString();
      DebugLog.log('Kuwo play ERROR: ' + e.toString());
      return null;
    }
  }

  Future<String?> getPlayUrlForSong(String songName, String artist) async {
    final rid = await searchForRid(songName, artist);
    if (rid == null) return null;
    return getPlayUrl(rid);
  }

  void dispose() {
    _client.close();
  }
}
