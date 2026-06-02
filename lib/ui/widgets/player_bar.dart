import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../data/services/audio_player_service.dart';
import '../../providers/audio_provider.dart';
import '../../core/services/floating_lyrics_service.dart';
import '../../providers/lyrics_provider.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioServiceProvider);
    final positionAsync = ref.watch(positionProvider);
    final durationAsync = ref.watch(durationProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final track = audio.currentTrack;
    final playMode = ref.watch(playModeProvider);
    // Keep lyrics notifier alive for floating lyrics sync
    ref.watch(lyricsNotifierProvider);

    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? Duration.zero;
    final isPlaying = isPlayingAsync.value ?? false;

    return Container(
      height: AppConstants.playerBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        children: [
          // Main controls row
          SizedBox(
            height: AppConstants.playerBarHeight,
            child: Row(
              children: [
                const SizedBox(width: 16),
                // Cover
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)),
                  child: track?.coverUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(track!.coverUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 24)),
                        )
                      : const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 24),
                ),
                const SizedBox(width: 12),
                // Track info
                SizedBox(
                  width: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track?.title ?? 'No track playing',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                      Text(track?.artist ?? 'Select a song',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                    ],
                  ),
                ),
                const Spacer(),
                // Playback controls
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        playMode == PlayMode.shuffle ? Icons.shuffle_rounded
                            : playMode == PlayMode.singleLoop ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 18,
                      ),
                      color: playMode == PlayMode.sequence ? AppColors.textDisabled : AppColors.accent,
                      onPressed: () {
                        audio.togglePlayMode();
                        ref.read(playModeProvider.notifier).state = audio.playMode;
                      },
                    ),
                    IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 22), color: AppColors.textSecondary, onPressed: () => audio.previous()),
                    GestureDetector(
                      onTap: () => isPlaying ? audio.pause() : audio.play(),
                      child: Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.skip_next_rounded, size: 22), color: AppColors.textSecondary, onPressed: () => audio.next()),
                  ],
                ),
                const SizedBox(width: 16),
                // Progress
                SizedBox(
                  width: 280,
                  child: Row(
                    children: [
                      Text(FormatUtils.formatDuration(position),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          ),
                          child: Slider(
                            value: duration.inMilliseconds > 0
                                ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                                : 0,
                            min: 0,
                            max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                            onChanged: (v) => audio.seek(Duration(milliseconds: v.toInt())),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(FormatUtils.formatDuration(duration),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Lyrics button
                IconButton(
                  icon: const Icon(Icons.lyrics_outlined, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Lyrics',
                  onPressed: () => context.push('/lyrics'),
                ),
                // Floating lyrics toggle
                _FloatingLyricsButton(),
                // Queue button
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Queue',
                  onPressed: () => _showQueue(context, ref),
                ),
                // Volume
                _VolumeSlider(audio: audio),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showQueue(BuildContext context, WidgetRef ref) {
  final audio = ref.read(audioServiceProvider);
  final queue = audio.queue;
  final currentIndex = audio.currentIndex;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => SizedBox(
      height: 400,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('Queue', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${queue.length} songs', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 16),
              IconButton(icon: const Icon(Icons.close_rounded, size: 18), color: AppColors.textSecondary, onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: queue.isEmpty
              ? const Center(child: Text('Queue is empty', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (_, i) {
                    final track = queue[i];
                    final isCurrent = i == currentIndex;
                    return ListTile(
                      dense: true,
                      leading: isCurrent
                        ? const Icon(Icons.equalizer_rounded, size: 16, color: AppColors.accent)
                        : Text('${i + 1}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      title: Text(track.title, style: TextStyle(fontSize: 13, color: isCurrent ? AppColors.accent : AppColors.textPrimary, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis),
                      subtitle: Text(track.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14),
                        color: AppColors.textDisabled,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () {
                          audio.removeFromQueue(i);
                          ref.read(queueProvider.notifier).update();
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                      onTap: () {
                        audio.playTrack(track);
                        ref.read(queueProvider.notifier).update();
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    ),
  );
}

class _VolumeSlider extends StatefulWidget {
  final AudioPlayerService audio;
  const _VolumeSlider({required this.audio});
  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _vol;

  @override
  void initState() {
    super.initState();
    _vol = widget.audio.volume;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
          trackHeight: 2,
        ),
        child: Slider(
          value: _vol,
          onChanged: (v) {
            setState(() => _vol = v);
            widget.audio.setVolume(v);
          },
        ),
      ),
    );
  }
}

class _FloatingLyricsButton extends StatefulWidget {
  const _FloatingLyricsButton();
  @override
  State<_FloatingLyricsButton> createState() => _FloatingLyricsButtonState();
}

class _FloatingLyricsButtonState extends State<_FloatingLyricsButton> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    FloatingLyricsService.onClosed = () {
      if (mounted) setState(() => _active = false);
    };
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _active
            ? Icons.picture_in_picture_rounded
            : Icons.picture_in_picture_alt_rounded,
        size: 18,
      ),
      color: _active ? AppColors.accent : AppColors.textSecondary,
      tooltip: 'Floating Lyrics',
      onPressed: () {
        FloatingLyricsService.toggle();
        setState(() => _active = FloatingLyricsService.isVisible);
      },
    );
  }
}

