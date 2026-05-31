import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/lyrics_provider.dart';

class LyricView extends ConsumerStatefulWidget {
  final bool compact;
  final int maxVisibleLines;

  const LyricView({super.key, this.compact = false, this.maxVisibleLines = 3});

  @override
  ConsumerState<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends ConsumerState<LyricView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  int _lastScrolledTo = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) {
    return _itemKeys.putIfAbsent(index, () => GlobalKey());
  }

  void _scrollToCurrentLine(int index) {
    if (index == _lastScrolledTo) return;
    _lastScrolledTo = index;
    if (!_scrollController.hasClients) return;

    // First jump to approximate position so ListView builds the target item
    final estimatedOffset = index * 46.0 - 250.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(estimatedOffset.clamp(0.0, maxExtent));

    // Then precise-center using ensureVisible after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyrics = ref.watch(lyricsNotifierProvider);
    final currentLine = lyrics.currentLineIndex;

    if (widget.compact) {
      return _buildCompact(lyrics, currentLine);
    }
    return _buildFull(lyrics, currentLine);
  }

  Widget _buildCompact(LyricsState lyrics, int currentLine) {
    if (lyrics.isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))),
      );
    }
    if (lyrics.lines.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(child: Text('No lyrics', style: TextStyle(color: AppColors.textDisabled, fontSize: 12))),
      );
    }

    final start = (currentLine - 1).clamp(0, lyrics.lines.length - 1);
    final end = (start + widget.maxVisibleLines).clamp(0, lyrics.lines.length);
    final visibleLines = lyrics.lines.sublist(start, end);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(visibleLines.length, (i) {
        final lineIdx = start + i;
        final isCurrent = lineIdx == currentLine;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            visibleLines[i].text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              color: isCurrent ? AppColors.accent : AppColors.textDisabled,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    );
  }

  Widget _buildFull(LyricsState lyrics, int currentLine) {
    if (lyrics.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent));
    }
    if (lyrics.lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text('No lyrics available', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    if (currentLine >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentLine(currentLine));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 250),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final isCurrent = index == currentLine;
        return GestureDetector(
          key: _keyFor(index),
          onTap: () => ref.read(lyricsNotifierProvider.notifier).seekToLine(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isCurrent ? 17 : 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: isCurrent ? AppColors.accent : AppColors.textDisabled,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
              child: Text(lyrics.lines[index].text, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
      },
    );
  }
}
