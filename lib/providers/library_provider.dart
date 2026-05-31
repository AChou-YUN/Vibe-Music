import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/models/track.dart';
import '../data/services/music_scanner_service.dart';

final musicScannerServiceProvider = Provider<MusicScannerService>((ref) {
  return MusicScannerService();
});

final libraryProvider = NotifierProvider<LibraryNotifier, List<Track>>(LibraryNotifier.new);

class LibraryNotifier extends Notifier<List<Track>> {
  @override
  List<Track> build() => [];

  Future<void> importFiles() async {
    final scanner = ref.read(musicScannerServiceProvider);
    final tracks = await scanner.pickAndScanFiles();
    if (tracks.isNotEmpty) {
      _addTracks(tracks);
    }
  }

  Future<void> importDirectory() async {
    final scanner = ref.read(musicScannerServiceProvider);
    final tracks = await scanner.pickAndScanDirectory();
    if (tracks.isNotEmpty) {
      _addTracks(tracks);
    }
  }

  void _addTracks(List<Track> newTracks) {
    final existingPaths = state.map((t) => t.filePath).toSet();
    final unique = newTracks.where((t) => !existingPaths.contains(t.filePath)).toList();
    state = [...state, ...unique];
  }

  void removeTrack(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void toggleFavorite(String id) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(isFavorite: !t.isFavorite) else t,
    ];
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredLibraryProvider = Provider<List<Track>>((ref) {
  final library = ref.watch(libraryProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  if (query.isEmpty) return library;
  return library.where((t) =>
    t.title.toLowerCase().contains(query) ||
    t.artist.toLowerCase().contains(query) ||
    t.album.toLowerCase().contains(query)
  ).toList();
});

