import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/services/cache_service.dart';
import '../data/services/netease_service.dart';
import '../core/utils/debug_log.dart';
import 'netease_provider.dart';

final playlistProvider = NotifierProvider<PlaylistNotifier, List<Playlist>>(PlaylistNotifier.new);

class PlaylistNotifier extends Notifier<List<Playlist>> {
  @override
  List<Playlist> build() {
    _init();
    return [
      Playlist(name: 'Favorites', isSystem: true),
      Playlist(name: 'Recently Played', isSystem: true),
    ];
  }

  Future<void> _init() async {
    await _loadRecentlyPlayed();
    await loadFavoritesFromCache();
    await syncAllFromCloud();
  }

  // ── Sync all playlists from NetEase ──

  Future<void> syncAllFromCloud() async {
    final netease = ref.read(neteaseServiceProvider);
    if (!netease.isLoggedIn) return;

    try {
      // 1. Get user's playlist list
      final playlistInfos = await netease.getUserPlaylists();
      if (playlistInfos.isEmpty) return;
      DebugLog.log('Found ${playlistInfos.length} NetEase playlists');

      // 2. Find favorites (liked list) — it's the one created by the user with special flag
      final likelistIds = await netease.getLikelist();

      // 3. Build playlist list: Favorites first, then others
      final result = <Playlist>[];

      // Favorites (from likelist)
      if (likelistIds.isNotEmpty) {
        final detailSongs = <NeteaseSearchResult>[];
        for (var i = 0; i < likelistIds.length; i += 100) {
          final batch = likelistIds.skip(i).take(100).toList();
          final songs = await netease.getSongsDetail(batch);
          detailSongs.addAll(songs);
        }
        final favTracks = detailSongs.map(_resultToTrack).toList();
        result.add(Playlist(name: 'Favorites', isSystem: true, tracks: favTracks));

        // Cache favorites
        CacheService.saveLikedSongs(detailSongs.map((s) => {
          'id': s.id, 'name': s.songName, 'artist': s.artistName,
          'album': s.albumName, 'duration': s.duration, 'cover': s.coverUrl,
        }).toList());
      } else {
        // Keep existing favorites from state
        result.add(state[0]);
      }

      // 4. Fetch other playlists (skip favorites, fetch tracks for each)
      final userId = netease.userId;
      for (final info in playlistInfos) {
        final pid = info['id'] as int;
        final pname = info['name'] as String;
        final pcover = info['coverUrl'] as String?;
        final trackCount = info['trackCount'] as int;
        final creator = info['creator'] as int?;

        // Skip if it's the user's own liked list (already handled above)
        // The liked list is the first one created by the user
        // We identify it by: creator == userId and name == "喜欢的音乐" or it's the first one
        if (creator == userId && (pname == '喜欢的音乐' || pname == 'Favorites')) continue;

        // Skip empty playlists
        if (trackCount == 0) continue;

        // Fetch tracks
        final songs = await netease.getPlaylistTracks(pid, limit: 500);
        final tracks = songs.map(_resultToTrack).toList();

        result.add(Playlist(
          name: pname,
          coverUrl: pcover,
          tracks: tracks,
        ));
        DebugLog.log('Synced playlist: "$pname" (${tracks.length} tracks)');
      }

      // 5. Add existing Recently Played at the end
      result.add(state.length > 1 ? state[1] : Playlist(name: 'Recently Played', isSystem: true));

      state = result;
      DebugLog.log('All playlists synced: ${result.length} playlists');
    } catch (e) {
      DebugLog.log('Sync playlists error: $e');
    }
  }

  Track _resultToTrack(NeteaseSearchResult r) {
    return Track(
      id: 'netease_${r.id}',
      title: r.songName,
      artist: r.artistName,
      album: r.albumName,
      duration: Duration(milliseconds: r.duration),
      filePath: '',
      coverUrl: r.coverUrl,
    );
  }

  // ── Favorites from cache (fast startup) ──

  Future<void> loadFavoritesFromCache() async {
    final cached = await CacheService.loadLikedSongs();
    if (cached.isEmpty) return;
    final tracks = cached.map((m) => Track(
      id: 'netease_${m['id']}',
      title: m['name'] as String,
      artist: m['artist'] as String,
      album: m['album'] as String,
      duration: Duration(milliseconds: m['duration'] as int),
      filePath: '',
      coverUrl: m['cover'] as String?,
    )).toList();
    state = [
      Playlist(id: state[0].id, name: 'Favorites', isSystem: true, tracks: tracks),
      ...state.sublist(1),
    ];
  }

  // ── Recently Played ──

  Future<void> _loadRecentlyPlayed() async {
    final cached = await CacheService.loadRecentlyPlayed();
    if (cached.isEmpty) return;
    final tracks = cached.map((m) => Track(
      id: m['id'] as String?,
      title: m['title'] as String,
      artist: m['artist'] as String,
      album: m['album'] as String,
      duration: Duration(milliseconds: m['duration'] as int),
      filePath: m['path'] as String? ?? '',
      coverUrl: m['cover'] as String?,
    )).toList();
    final rpPlaylist = Playlist(id: state[1].id, name: 'Recently Played', isSystem: true, tracks: tracks);
    state = [state[0], rpPlaylist];
  }

  Future<void> addRecentlyPlayed(Track track) async {
    final recent = state.length > 1 ? state[1] : Playlist(name: 'Recently Played', isSystem: true);
    final updated = List<Track>.from(recent.tracks);
    updated.removeWhere((t) => t.id == track.id);
    updated.insert(0, track);
    if (updated.length > 100) updated.removeLast();

    final rpPlaylist = Playlist(id: recent.id, name: 'Recently Played', isSystem: true, tracks: updated);
    if (state.length > 1) {
      state = [state[0], rpPlaylist, ...state.sublist(2)];
    } else {
      state = [state[0], rpPlaylist];
    }

    await CacheService.addRecentlyPlayed({
      'id': track.id, 'title': track.title, 'artist': track.artist,
      'album': track.album, 'duration': track.duration.inMilliseconds,
      'path': track.filePath, 'cover': track.coverUrl,
    });
  }

  Future<void> clearRecentlyPlayed() async {
    final rpPlaylist = Playlist(name: 'Recently Played', isSystem: true);
    if (state.length > 1) {
      state = [state[0], rpPlaylist, ...state.sublist(2)];
    } else {
      state = [state[0], rpPlaylist];
    }
    await CacheService.clearRecentlyPlayed();
  }

  // ── Like/Unlike ──

  Future<bool> toggleLike(String trackId) async {
    final netease = ref.read(neteaseServiceProvider);
    if (!netease.isLoggedIn) return false;
    final songId = int.tryParse(trackId.replaceFirst('netease_', ''));
    if (songId == null) return false;

    final favorites = state[0];
    final isLiked = favorites.tracks.any((t) => t.id == trackId);
    final success = await netease.likeSong(songId, like: !isLiked);
    if (success) {
      if (isLiked) {
        state = [
          Playlist(id: favorites.id, name: 'Favorites', isSystem: true, tracks: favorites.tracks.where((t) => t.id != trackId).toList()),
          ...state.sublist(1),
        ];
      } else {
        await syncAllFromCloud();
      }
    }
    return success;
  }

  List<Track> getPlaylistTracks(String playlistId) {
    final playlist = state.firstWhere((p) => p.id == playlistId, orElse: () => Playlist(name: ''));
    return playlist.tracks;
  }
}
