import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../models/track.dart';

class MusicScannerService {
  Future<List<Track>> pickAndScanFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedExtensions,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return [];
    return result.files
        .where((f) => f.path != null)
        .map((f) => _fileToTrack(f.path!))
        .toList();
  }

  Future<List<Track>> pickAndScanDirectory() async {
    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null) return [];
    return scanDirectory(dirPath);
  }

  Future<List<Track>> scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final tracks = <Track>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (AppConstants.supportedExtensions.contains(ext)) {
          tracks.add(_fileToTrack(entity.path));
        }
      }
    }
    return tracks;
  }

  Track _fileToTrack(String filePath) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    String title = nameWithoutExt;
    String artist = 'Unknown';
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    return Track(
      title: title,
      artist: artist,
      filePath: filePath,
    );
  }

  Future<List<Track>> scanDefaultDirectory() async {
    final musicDir = await getApplicationDocumentsDirectory();
    final vibeMusicDir = Directory('${musicDir.path}\\VibeMusic');
    if (await vibeMusicDir.exists()) {
      return scanDirectory(vibeMusicDir.path);
    }
    return [];
  }
}

