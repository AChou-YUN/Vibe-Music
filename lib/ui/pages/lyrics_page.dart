import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/audio_provider.dart';
import '../widgets/lyric_view.dart';

class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});
  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onControlsHover(bool hovering) {
    if (hovering) {
      _hideTimer?.cancel();
      if (!_showControls) setState(() => _showControls = true);
    } else {
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioServiceProvider);
    final track = audio.currentTrack;
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final isPlaying = isPlayingAsync.value ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          if (track?.coverUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Image.network(track!.coverUrl!, fit: BoxFit.cover),
              ),
            ),
          Positioned.fill(
            child: Container(color: AppColors.background.withValues(alpha: 0.85)),
          ),
          Column(
            children: [
              Container(
                height: 40,
                color: Colors.transparent,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                      color: AppColors.textSecondary,
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const Spacer(),
                    Text('Lyrics', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.surfaceLight,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10))],
                            ),
                            child: track?.coverUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(track!.coverUrl!, fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 48)),
                                  )
                                : const Icon(Icons.music_note_rounded, color: AppColors.textDisabled, size: 48),
                          ),
                          const SizedBox(height: 16),
                          Text(track?.title ?? 'No track', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
                          const SizedBox(height: 4),
                          Text(track?.artist ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
                        ],
                      ),
                    ),
                    const Expanded(flex: 3, child: LyricView(compact: false)),
                  ],
                ),
              ),
              // Bottom controls - hover to show, auto-hide after 5s
              MouseRegion(
                onEnter: (_) => _onControlsHover(true),
                onExit: (_) => _onControlsHover(false),
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 26), color: AppColors.textSecondary, onPressed: () => audio.previous()),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => isPlaying ? audio.pause() : audio.play(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                            child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(icon: const Icon(Icons.skip_next_rounded, size: 26), color: AppColors.textSecondary, onPressed: () => audio.next()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
