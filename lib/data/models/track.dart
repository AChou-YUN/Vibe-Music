import 'package:uuid/uuid.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String filePath;
  final String? coverUrl;
  final String? kugouHash;
  final DateTime addedAt;
  final int playCount;
  final bool isFavorite;

  Track({
    String? id,
    required this.title,
    this.artist = 'Unknown',
    this.album = 'Unknown',
    this.duration = Duration.zero,
    required this.filePath,
    this.coverUrl,
    this.kugouHash,
    DateTime? addedAt,
    this.playCount = 0,
    this.isFavorite = false,
  })  : id = id ?? const Uuid().v4(),
        addedAt = addedAt ?? DateTime.now();

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? filePath,
    String? coverUrl,
    String? kugouHash,
    int? playCount,
    bool? isFavorite,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      coverUrl: coverUrl ?? this.coverUrl,
      kugouHash: kugouHash ?? this.kugouHash,
      addedAt: addedAt,
      playCount: playCount ?? this.playCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get displayDuration {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
