import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data/services/audio_player_service.dart';
import '../data/models/track.dart';
import 'netease_provider.dart';
import 'playlist_provider.dart';

final audioServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  final netease = ref.read(neteaseServiceProvider);
  service.setNeteaseService(netease);
  // Track recently played
  service.onTrackPlayed = (track) {
    ref.read(playlistProvider.notifier).addRecentlyPlayed(track);
  };
  ref.onDispose(() => service.dispose());
  return service;
});

final currentTrackProvider = StreamProvider<Track?>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return audio.playerStateStream.map((_) => audio.currentTrack);
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return audio.playerStateStream.map((state) => state == PlayerState.playing);
});

final positionProvider = StreamProvider<Duration>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return audio.positionStream;
});

final durationProvider = StreamProvider<Duration>((ref) {
  final audio = ref.watch(audioServiceProvider);
  return audio.durationStream;
});

final queueProvider = NotifierProvider<QueueNotifier, List<Track>>(QueueNotifier.new);

class QueueNotifier extends Notifier<List<Track>> {
  @override
  List<Track> build() => [];

  void update() {
    final audio = ref.read(audioServiceProvider);
    state = List.from(audio.queue);
  }
}

final playModeProvider = StateProvider<PlayMode>((ref) => PlayMode.sequence);
