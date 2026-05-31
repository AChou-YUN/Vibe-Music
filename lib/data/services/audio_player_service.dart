import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import '../models/track.dart';
import '../../core/utils/debug_log.dart';
import 'cache_service.dart';
import 'netease_service.dart';

enum PlayMode { sequence, singleLoop, shuffle }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final List<Track> _queue = [];
  int _currentIndex = -1;
  PlayMode _playMode = PlayMode.sequence;
  int _errorCount = 0;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  double _volume = 0.7;
  NeteaseApiService? _netease;
  void Function(Track track)? onTrackPlayed;

  AudioPlayer get player => _player;
  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Track? get currentTrack => _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  PlayMode get playMode => _playMode;
  double get volume => _volume;

  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;

  Duration get position => _lastPosition;
  Duration get duration => _lastDuration;
  bool get isPlaying => _player.state == PlayerState.playing;

  AudioPlayerService() {
    _player.onPositionChanged.listen((p) {
      _lastPosition = p;
      // Auto-save position every 10 seconds
      if (p.inSeconds % 10 == 0 && p.inSeconds > 0) {
        _saveCurrentTrack();
      }
    });
    _player.onDurationChanged.listen((d) => _lastDuration = d);
    _player.onPlayerComplete.listen((_) {
      DebugLog.log('Audio: track completed');
      next();
    });
    _restoreLastTrack();
  }

  /// Set the NeteaseApiService reference for authenticated URL refresh
  void setNeteaseService(NeteaseApiService netease) {
    _netease = netease;
  }

  /// Restore the last playing track on startup (without auto-playing)
  Future<void> _restoreLastTrack() async {
    final data = await CacheService.loadLastTrack();
    if (data == null) return;

    final track = Track(
      id: data['id'] as String?,
      title: data['title'] as String,
      artist: data['artist'] as String,
      album: data['album'] as String,
      duration: Duration(milliseconds: data['duration'] as int),
      filePath: data['path'] as String,
      coverUrl: data['cover'] as String?,
    );
    final positionMs = data['position_ms'] as int? ?? 0;

    _queue.clear();
    _queue.add(track);
    _currentIndex = 0;
    DebugLog.log('Restored: "${track.title}" pos=${positionMs}ms');

    // Load the track silently and seek to saved position
    await _loadCurrentSilent(positionMs);
  }

  /// Load current track into player without playing. Seeks to given position.
  Future<void> _loadCurrentSilent(int seekToMs) async {
    final track = currentTrack;
    if (track == null) return;

    try {
      var path = track.filePath;
      DebugLog.log('Silent load: "${track.title}"');

      // Try to refresh URL if it's a Netease track (URLs expire)
      if (path.startsWith('http')) {
        final freshUrl = await _tryRefreshUrl(track);
        if (freshUrl != null) {
          path = freshUrl;
          _queue[_currentIndex] = Track(
            id: track.id, title: track.title, artist: track.artist,
            album: track.album, duration: track.duration,
            filePath: freshUrl, coverUrl: track.coverUrl,
          );
        }
      }

      await _player.stop();
      if (path.startsWith('http://') || path.startsWith('https://')) {
        await _player.setSourceUrl(path);
      } else {
        await _player.setSourceDeviceFile(path);
      }

      if (seekToMs > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _player.seek(Duration(milliseconds: seekToMs));
          DebugLog.log('Seeked to ${seekToMs}ms');
        } catch (e) {
          DebugLog.log('Seek failed: $e');
        }
      }
      DebugLog.log('Silent load OK');
    } catch (e) {
      DebugLog.log('Silent load error: $e');
    }
  }

  /// Try to refresh a Netease play URL (WITH cookie for VIP access)
  Future<String?> _tryRefreshUrl(Track track) async {
    try {
      final id = track.id;
      if (id == null || !id.startsWith('netease_')) return null;
      final songId = int.tryParse(id.replaceFirst('netease_', ''));
      if (songId == null) return null;

      DebugLog.log('Refreshing URL for songId=$songId');

      // Use NeteaseApiService if available (passes cookie correctly)
      if (_netease != null) {
        final url = await _netease!.getPlayUrl(songId);
        if (url != null) {
          DebugLog.log('URL refreshed via service OK');
          return url;
        }
        DebugLog.log('URL refresh via service returned null');
        return null;
      }

      // Fallback: raw request without cookie (will get 30s preview for VIP songs)
      DebugLog.log('WARNING: no netease service, refresh without cookie');
      final uri = Uri.parse('http://127.0.0.1:3000/song/url?id=$songId&br=320000');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'VibeMusic/1.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body);
      if (data['code'] != 200) return null;
      final songData = data['data'] as List?;
      if (songData == null || songData.isEmpty) return null;
      final url = songData[0]['url'] as String?;
      if (url == null || url.isEmpty) return null;
      DebugLog.log('URL refreshed raw OK');
      return url;
    } catch (e) {
      DebugLog.log('URL refresh failed: $e');
      return null;
    }
  }

  /// Save current track + position to cache
  void _saveCurrentTrack() {
    final track = currentTrack;
    if (track == null) return;
    CacheService.saveLastTrack({
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'duration': track.duration.inMilliseconds,
      'path': track.filePath,
      'cover': track.coverUrl,
    }, positionMs: _lastPosition.inMilliseconds);
  }

  void _saveQueue() {
    CacheService.saveQueue(
      _queue.map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'duration': t.duration.inMilliseconds,
        'path': t.filePath,
        'cover': t.coverUrl,
      }).toList(),
      currentIndex: _currentIndex,
    );
  }

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue.clear();
    _queue.addAll(tracks);
    _currentIndex = startIndex;
    _errorCount = 0;
    _saveQueue();
    _saveCurrentTrack();
    if (_queue.isNotEmpty) await _playCurrent();
  }

  Future<void> addToQueue(Track track) async {
    _queue.add(track);
    _saveQueue();
    if (_queue.length == 1) {
      _currentIndex = 0;
      _errorCount = 0;
      await _playCurrent();
    }
  }

  Future<void> insertNext(Track track) async {
    final insertAt = _currentIndex + 1;
    if (insertAt < _queue.length) { _queue.insert(insertAt, track); } else { _queue.add(track); }
    _saveQueue();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    if (index < _currentIndex) { _currentIndex--; }
    else if (index == _currentIndex) {
      if (_queue.isEmpty) { _currentIndex = -1; _player.stop(); }
      else { _currentIndex = _currentIndex.clamp(0, _queue.length - 1); _errorCount = 0; _playCurrent(); }
    }
    _saveQueue();
  }

  void clearQueue() { _queue.clear(); _currentIndex = -1; _errorCount = 0; _player.stop(); _saveQueue(); }

  Future<void> play() async { try { await _player.resume(); } catch (e) { DebugLog.log('play() err: $e'); } }
  Future<void> pause() async { try { await _player.pause(); _saveCurrentTrack(); } catch (e) { DebugLog.log('pause() err: $e'); } }
  Future<void> stop() async { try { await _player.stop(); } catch (e) { DebugLog.log('stop() err: $e'); } }

  Future<void> playTrack(Track track) async {
    _errorCount = 0;
    final idx = _queue.indexWhere((t) => t.id == track.id);
    if (idx >= 0) { _currentIndex = idx; } else { _queue.insert(_currentIndex + 1, track); _currentIndex++; }
    _saveQueue();
    _saveCurrentTrack();
    await _playCurrent();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _errorCount = 0;
    switch (_playMode) {
      case PlayMode.sequence: _currentIndex = (_currentIndex + 1) % _queue.length; break;
      case PlayMode.singleLoop: break;
      case PlayMode.shuffle: _currentIndex = (_queue.length > 1) ? (List.generate(_queue.length, (i) => i)..shuffle()).firstWhere((i) => i != _currentIndex, orElse: () => _currentIndex) : 0; break;
    }
    _saveQueue();
    _saveCurrentTrack();
    await _playCurrent();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    _errorCount = 0;
    if (_lastPosition.inSeconds > 3) { await seek(Duration.zero); return; }
    switch (_playMode) {
      case PlayMode.sequence: _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length; break;
      case PlayMode.singleLoop: break;
      case PlayMode.shuffle: _currentIndex = (_queue.length > 1) ? (List.generate(_queue.length, (i) => i)..shuffle()).firstWhere((i) => i != _currentIndex, orElse: () => _currentIndex) : 0; break;
    }
    _saveQueue();
    _saveCurrentTrack();
    await _playCurrent();
  }

  Future<void> seek(Duration pos) async { try { await _player.seek(pos); } catch (e) { DebugLog.log('seek err: $e'); } }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    _player.setReleaseMode(mode == PlayMode.singleLoop ? ReleaseMode.loop : ReleaseMode.release);
  }

  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.sequence: setPlayMode(PlayMode.singleLoop); break;
      case PlayMode.singleLoop: setPlayMode(PlayMode.shuffle); break;
      case PlayMode.shuffle: setPlayMode(PlayMode.sequence); break;
    }
  }

  Future<void> _playCurrent() async {
    final track = currentTrack;
    if (track == null) return;
    if (_errorCount > 3) { DebugLog.log('Audio: too many errors'); _errorCount = 0; return; }

    try {
      var path = track.filePath;
      DebugLog.log('Play: "${track.title}"');
      await _player.stop();

      if (path.startsWith('http')) {
        final freshUrl = await _tryRefreshUrl(track);
        if (freshUrl != null) {
          path = freshUrl;
          _queue[_currentIndex] = Track(
            id: track.id, title: track.title, artist: track.artist,
            album: track.album, duration: track.duration,
            filePath: freshUrl, coverUrl: track.coverUrl,
          );
        }
      }

      if (path.startsWith('http://') || path.startsWith('https://')) {
        await _player.play(UrlSource(path));
      } else {
        await _player.play(DeviceFileSource(path));
      }
      _errorCount = 0;
      _saveCurrentTrack();
      if (onTrackPlayed != null) onTrackPlayed!(track);
      DebugLog.log('Play OK');
    } catch (e) {
      _errorCount++;
      DebugLog.log('Audio ERR($_errorCount): $e');
      try { await _player.stop(); } catch (_) {}
    }
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> dispose() async { try { await _player.dispose(); } catch (_) {} }
}

