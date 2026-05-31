import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../data/services/netease_service.dart';
import '../../providers/audio_provider.dart';
import '../../providers/netease_provider.dart';
import '../../providers/playlist_provider.dart';

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  int _selectedTab = 0;
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistProvider);
    // Ensure selected tab is valid
    if (_selectedTab >= playlists.length) _selectedTab = 0;
    final current = playlists.isNotEmpty ? playlists[_selectedTab] : null;
    final currentTracks = current?.tracks ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('Library', style: Theme.of(context).textTheme.headlineLarge),
              const Spacer(),
              IconButton(
                onPressed: _syncing ? null : _sync,
                icon: _syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                    : const Icon(Icons.sync_rounded, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Sync from NetEase',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Playlist tabs
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _tabChip(index, playlists[index]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action bar
          if (currentTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text('${currentTracks.length} tracks', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _playAll(currentTracks),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                  ),
                  if (current?.name == 'Recently Played') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _clearRecentlyPlayed,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: AppColors.textDisabled,
                      tooltip: 'Clear recently played',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
          // Track list
          Expanded(
            child: currentTracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          current?.name == 'Recently Played' ? Icons.history_rounded : Icons.favorite_border_rounded,
                          size: 48, color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          current?.name == 'Recently Played' ? 'No recently played' : 'No songs in this playlist',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (current?.name == 'Favorites') ...[
                          const SizedBox(height: 4),
                          const Text('Login and like songs to see them here',
                              style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: currentTracks.length,
                    itemBuilder: (context, index) => _TrackTile(
                      track: currentTracks[index],
                      index: index,
                      onTap: () => _playTrack(currentTracks[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index, dynamic playlist) {
    final selected = _selectedTab == index;
    final icon = playlist.isSystem
        ? (playlist.name == 'Favorites' ? Icons.favorite_rounded : Icons.history_rounded)
        : Icons.queue_music_rounded;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(playlist.name, style: TextStyle(fontSize: 12, color: selected ? AppColors.accent : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            if (playlist.trackCount > 0) ...[
              const SizedBox(width: 5),
              Text('${playlist.trackCount}', style: TextStyle(fontSize: 10, color: selected ? AppColors.accent.withValues(alpha: 0.7) : AppColors.textDisabled)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await ref.read(playlistProvider.notifier).syncAllFromCloud();
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _playTrack(Track track) async {
    final audio = ref.read(audioServiceProvider);
    final netease = ref.read(neteaseServiceProvider);
    final songId = int.tryParse((track.id ?? '').replaceFirst('netease_', ''));
    if (songId == null) return;
    final url = await netease.getPlayUrl(songId);
    if (url == null) return;
    final playable = Track(
      id: track.id, title: track.title, artist: track.artist,
      album: track.album, duration: track.duration,
      filePath: url, coverUrl: track.coverUrl,
    );
    await audio.addToQueue(playable);
    await audio.playTrack(playable);
    ref.read(queueProvider.notifier).update();
  }

  Future<void> _playAll(List<Track> tracks) async {
    final audio = ref.read(audioServiceProvider);
    final netease = ref.read(neteaseServiceProvider);
    final playable = <Track>[];
    for (final t in tracks) {
      final songId = int.tryParse((t.id ?? '').replaceFirst('netease_', ''));
      if (songId == null) continue;
      final url = await netease.getPlayUrl(songId);
      if (url != null) {
        playable.add(Track(
          id: t.id, title: t.title, artist: t.artist,
          album: t.album, duration: t.duration,
          filePath: url, coverUrl: t.coverUrl,
        ));
      }
      if (playable.length >= 50) break;
    }
    if (playable.isNotEmpty) {
      await audio.setQueue(playable);
      ref.read(queueProvider.notifier).update();
    }
  }

  Future<void> _clearRecentlyPlayed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Recently Played?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This will clear your listening history.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(playlistProvider.notifier).clearRecentlyPlayed();
    }
  }
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final VoidCallback onTap;

  const _TrackTile({required this.track, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dur = track.duration;
    final m = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = dur.inSeconds.remainder(60).toString().padLeft(2, '0');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: AppColors.surfaceLight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('${index + 1}', style: const TextStyle(color: AppColors.textDisabled, fontSize: 12), textAlign: TextAlign.center),
            ),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)),
              child: track.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(track.coverUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 20)),
                    )
                  : const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text(track.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(track.album, style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                  overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.right),
            ),
            SizedBox(
              width: 50,
              child: Text('$m:$s', style: const TextStyle(color: AppColors.textDisabled, fontSize: 11), textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }
}
