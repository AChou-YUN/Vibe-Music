import 'package:uuid/uuid.dart';
import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final List<Track> tracks;
  final DateTime createdAt;
  final bool isSystem;

  Playlist({
    String? id,
    required this.name,
    this.description,
    this.coverUrl,
    List<Track>? tracks,
    DateTime? createdAt,
    this.isSystem = false,
  })  : id = id ?? const Uuid().v4(),
        tracks = tracks ?? [],
        createdAt = createdAt ?? DateTime.now();

  Playlist copyWith({
    String? name,
    String? description,
    String? coverUrl,
    List<Track>? tracks,
    bool? isSystem,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  int get trackCount => tracks.length;
}
