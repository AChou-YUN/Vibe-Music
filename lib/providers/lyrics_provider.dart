import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/netease_service.dart';
import '../providers/netease_provider.dart';
import 'audio_provider.dart';

class LyricsState {
  final List<NeteaseLyricLine> lines;
  final int currentLineIndex;
  final bool isLoading;
  final String? error;

  const LyricsState({
    this.lines = const [],
    this.currentLineIndex = -1,
    this.isLoading = false,
    this.error,
  });

  LyricsState copyWith({
    List<NeteaseLyricLine>? lines,
    int? currentLineIndex,
    bool? isLoading,
    String? error,
  }) {
    return LyricsState(
      lines: lines ?? this.lines,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final lyricsNotifierProvider = NotifierProvider<LyricsNotifier, LyricsState>(LyricsNotifier.new);

class LyricsNotifier extends Notifier<LyricsState> {
  StreamSubscription? _positionSub;
  String _lastTrackId = '';

  @override
  LyricsState build() {
    ref.onDispose(() => _positionSub?.cancel());

    final audio = ref.read(audioServiceProvider);
    _positionSub = audio.positionStream.listen(_updateCurrentLine);

    // Listen for track changes
    ref.listen(currentTrackProvider, (prev, next) {
      final track = next.value;
      if (track != null && track.id != _lastTrackId) {
        _lastTrackId = track.id ?? '';
        _fetchLyrics(track.id ?? '');
      }
    });

    // Also check if a track is already loaded (e.g. restored from cache on startup)
    final currentTrack = audio.currentTrack;
    if (currentTrack != null) {
      _lastTrackId = currentTrack.id ?? '';
      // Defer to allow the notifier to fully initialize
      Future.microtask(() => _fetchLyrics(currentTrack.id ?? ''));
    }

    return const LyricsState();
  }

  Future<void> _fetchLyrics(String trackId) async {
    if (trackId.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null, lines: [], currentLineIndex: -1);
    try {
      final netease = ref.read(neteaseServiceProvider);
      final songId = int.tryParse(trackId.replaceFirst('netease_', ''));
      if (songId == null) {
        state = state.copyWith(isLoading: false, error: 'No lyrics available');
        return;
      }
      final lines = await netease.getLyrics(songId);
      state = state.copyWith(lines: lines, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load lyrics');
    }
  }

  void _updateCurrentLine(Duration position) {
    final lines = state.lines;
    if (lines.isEmpty) return;
    int idx = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        idx = i;
        break;
      }
    }
    if (idx != state.currentLineIndex) {
      state = state.copyWith(currentLineIndex: idx);
    }
  }

  void seekToLine(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final audio = ref.read(audioServiceProvider);
    audio.seek(state.lines[index].time);
  }
}
