import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/audio_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioServiceProvider);
    final track = audio.currentTrack;
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final isPlaying = isPlayingAsync.value ?? false;
    final positionAsync = ref.watch(positionProvider);
    final durationAsync = ref.watch(durationProvider);
    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? Duration.zero;

    return Container(
      width: AppConstants.miniPlayerWidth,
      height: AppConstants.miniPlayerHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          // Cover
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(6)),
            child: track?.coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(track!.coverUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 28)),
                  )
                : const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 28),
          ),
          const SizedBox(width: 10),
          // Info + controls
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track?.title ?? 'No track', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(track?.artist ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 2,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(FormatUtils.formatDuration(position), style: const TextStyle(fontSize: 9, color: AppColors.textDisabled)),
                    Text(FormatUtils.formatDuration(duration), style: const TextStyle(fontSize: 9, color: AppColors.textDisabled)),
                  ],
                ),
              ],
            ),
          ),
          // Play controls
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => isPlaying ? audio.pause() : audio.play(),
                child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22, color: AppColors.accent),
              ),
              GestureDetector(
                onTap: () => audio.next(),
                child: const Icon(Icons.skip_next_rounded, size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

