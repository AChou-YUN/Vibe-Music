import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_provider.dart';
import '../../providers/netease_provider.dart';
import '../../data/services/netease_service.dart';
import '../../data/services/cache_service.dart';
import '../shell/app_shell.dart';

final likedSongsProvider = AsyncNotifierProvider<LikedSongsNotifier, List<NeteaseSearchResult>>(LikedSongsNotifier.new);

class LikedSongsNotifier extends AsyncNotifier<List<NeteaseSearchResult>> {
  @override
  List<NeteaseSearchResult> build() {
    _loadFromCache();
    return [];
  }

  Future<void> _loadFromCache() async {
    final cached = await CacheService.loadLikedSongs();
    if (cached.isNotEmpty) {
      state = AsyncData(cached.map((m) => NeteaseSearchResult(
        id: m['id'] as int,
        songName: m['name'] as String,
        artistName: m['artist'] as String,
        albumName: m['album'] as String,
        duration: m['duration'] as int,
        coverUrl: m['cover'] as String?,
      )).toList());
    }
    await refreshFromNetwork();
  }

  Future<void> refreshFromNetwork() async {
    final netease = ref.read(neteaseServiceProvider);
    if (!netease.isLoggedIn) return;
    final ids = await netease.getLikelist();
    if (ids.isEmpty) return;
    final songs = await netease.getSongsDetail(ids.take(200).toList());
    if (songs.isNotEmpty) {
      state = AsyncData(songs);
      CacheService.saveLikedSongs(songs.map((s) => {
        'id': s.id,
        'name': s.songName,
        'artist': s.artistName,
        'album': s.albumName,
        'duration': s.duration,
        'cover': s.coverUrl,
      }).toList());
    }
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    ref.listen(currentTabProvider, (prev, next) {
      if (next == 0) ref.read(likedSongsProvider.notifier).refreshFromNetwork();
    });
    final likedAsync = ref.watch(likedSongsProvider);
    final netease = ref.read(neteaseServiceProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good evening', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            netease.isLoggedIn ? 'Welcome, ${netease.nickname}' : 'Login to sync your favorites',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: likedAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border_rounded, size: 64, color: AppColors.textDisabled),
                        const SizedBox(height: 16),
                        Text(netease.isLoggedIn ? 'No liked songs yet' : 'Login to see your favorites', style: Theme.of(context).textTheme.bodyLarge),
                        if (!netease.isLoggedIn) ...[
                          const SizedBox(height: 8),
                          Text('Go to Settings to login', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final netease = ref.read(neteaseServiceProvider);
                          final tracks = <dynamic>[];
                          for (final s in songs) {
                            final url = await netease.getPlayUrl(s.id);
                            if (url != null) tracks.add(netease.resultToTrack(s, playUrl: url));
                          }
                          if (tracks.isNotEmpty) {
                            final audio = ref.read(audioServiceProvider);
                            await audio.setQueue(tracks.cast());
                            ref.read(queueProvider.notifier).update();
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(likedSongsProvider.notifier).refreshFromNetwork(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.divider)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Text('${songs.length} liked songs', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) => _LikedSongTile(song: songs[index]),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
              error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Failed to load', style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => ref.read(likedSongsProvider.notifier).refreshFromNetwork(), style: FilledButton.styleFrom(backgroundColor: AppColors.accent), child: const Text('Retry')),
              ])),
            ),
          ),
        ],
      ),
    );
  }
}

class _LikedSongTile extends ConsumerStatefulWidget {
  final NeteaseSearchResult song;
  const _LikedSongTile({required this.song});
  @override
  ConsumerState<_LikedSongTile> createState() => _LikedSongTileState();
}

class _LikedSongTileState extends ConsumerState<_LikedSongTile> {
  bool _loading = false;

  Future<void> _play() async {
    setState(() => _loading = true);
    final netease = ref.read(neteaseServiceProvider);
    final url = await netease.getPlayUrl(widget.song.id);
    if (url == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final track = netease.resultToTrack(widget.song, playUrl: url);
    final audio = ref.read(audioServiceProvider);
    await audio.addToQueue(track);
    await audio.playTrack(track);
    ref.read(queueProvider.notifier).update();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.song;
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final currentTrack = ref.watch(audioServiceProvider).currentTrack;
    final isCurrent = currentTrack?.id == 'netease_${s.id}';
    final dur = s.duration > 0 ? Duration(milliseconds: s.duration) : Duration.zero;
    final m = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = dur.inSeconds.remainder(60).toString().padLeft(2, '0');

    return InkWell(
      onTap: _loading ? null : _play,
      borderRadius: BorderRadius.circular(6),
      hoverColor: AppColors.surfaceLight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          SizedBox(
            width: 40, height: 40,
            child: s.coverUrl != null
              ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(s.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 20)))
              : _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                : const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.songName, style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400, color: isCurrent ? AppColors.accent : AppColors.textPrimary), overflow: TextOverflow.ellipsis),
            Text('${s.artistName}${s.albumName.isNotEmpty ? '  .  ${s.albumName}' : ''}', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ])),
          Text('$m:$sec', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
