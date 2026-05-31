import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/library_provider.dart';
import '../../providers/audio_provider.dart';
import '../../data/models/track.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(filteredLibraryProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Library', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search in library...',
              hintStyle: const TextStyle(color: AppColors.textDisabled),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ImportButton(
                icon: Icons.audio_file_rounded,
                label: 'Import Files',
                onTap: () => ref.read(libraryProvider.notifier).importFiles(),
              ),
              const SizedBox(width: 8),
              _ImportButton(
                icon: Icons.folder_rounded,
                label: 'Import Folder',
                onTap: () => ref.read(libraryProvider.notifier).importDirectory(),
              ),
              const Spacer(),
              Text('${library.length} tracks', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: library.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_music_rounded, size: 48, color: AppColors.textDisabled),
                        const SizedBox(height: 12),
                        Text('No music yet', style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 4),
                        Text('Import files or folders to build your library',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: library.length,
                    itemBuilder: (context, index) => _LibraryTrackTile(track: library[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImportButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _LibraryTrackTile extends ConsumerWidget {
  final Track track;
  const _LibraryTrackTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioServiceProvider);
    final isCurrent = audio.currentTrack?.id == track.id;
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final isPlaying = isPlayingAsync.value ?? false;

    return InkWell(
      onTap: () {
        final lib = ref.read(libraryProvider);
        audio.setQueue(lib, startIndex: lib.indexWhere((t) => t.id == track.id));
        ref.read(queueProvider.notifier).update();
      },
      borderRadius: BorderRadius.circular(6),
      hoverColor: AppColors.surfaceLight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: isCurrent && isPlaying
                  ? const Icon(Icons.equalizer_rounded, size: 14, color: AppColors.accent)
                  : const SizedBox(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('${track.artist}  ·  ${track.album}', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(track.displayDuration, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 16,
                color: track.isFavorite ? AppColors.accent : AppColors.textDisabled,
              ),
              onPressed: () => ref.read(libraryProvider.notifier).toggleFavorite(track.id),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textDisabled),
              onPressed: () => ref.read(libraryProvider.notifier).removeTrack(track.id),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
