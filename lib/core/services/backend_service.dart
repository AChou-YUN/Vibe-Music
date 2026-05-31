import 'dart:io';
import '../utils/debug_log.dart';

class BackendService {
  static Process? _process;
  static bool _started = false;

  static bool get isRunning => _started;

  /// Start the NeteaseCloudMusicApi backend server.
  /// Returns a stream of status messages for UI display.
  static Future<bool> start({int port = 3000, void Function(String)? onLog}) async {
    void log(String msg) {
      DebugLog.log(msg);
      onLog?.call(msg);
    }

    // 1. Check if already running on port
    log('Checking port $port...');
    if (await _isPortOpen(port)) {
      log('Backend already running on port $port');
      _started = true;
      return true;
    }

    // 2. Find backend directory
    final backendDir = await _findBackendDir();
    if (backendDir == null) {
      log('ERROR: backend/server.js not found');
      return false;
    }
    log('Backend dir: $backendDir');

    // 3. Find node executable
    final nodeExe = await _findNode();
    if (nodeExe == null) {
      log('ERROR: node.exe not found');
      return false;
    }
    log('Node: $nodeExe');

    // 4. Start the server
    log('Starting server...');
    try {
      _process = await Process.start(
        nodeExe,
        ['server.js'],
        workingDirectory: backendDir,
        mode: ProcessStartMode.normal,
      );

      // Listen to stdout/stderr for logging
      _process!.stdout.transform(const SystemEncoding().decoder).listen((line) {
        log('[server] ${line.trim()}');
      });
      _process!.stderr.transform(const SystemEncoding().decoder).listen((line) {
        log('[server:err] ${line.trim()}');
      });

      // 5. Wait for port to become available
      log('Waiting for server to be ready...');
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _isPortOpen(port)) {
          _started = true;
          log('Backend started OK (pid=${_process!.pid})');
          return true;
        }
      }

      log('ERROR: server did not start in time');
      _process?.kill();
      _process = null;
      return false;
    } catch (e) {
      log('ERROR: start failed: $e');
      return false;
    }
  }

  static void stop() {
    if (_process != null) {
      try {
        _process!.kill();
        DebugLog.log('Backend: stopped');
      } catch (_) {}
      _process = null;
      _started = false;
    }
  }

  static Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _findBackendDir() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '${Directory.current.path}\\backend',
      '$exeDir\\backend',
      '$exeDir\\..\\backend',
    ];
    for (final dir in candidates) {
      if (await File('$dir\\server.js').exists()) return dir;
    }
    return null;
  }

  static Future<String?> _findNode() async {
    // Try 'where.exe node' first (Windows)
    try {
      final result = await Process.run('where.exe', ['node']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        for (final line in lines) {
          final path = line.trim();
          if (path.endsWith('node.exe') && File(path).existsSync()) return path;
        }
      }
    } catch (_) {}

    // Fallback: search PATH manually
    final pathVar = Platform.environment['PATH'] ?? '';
    for (final dir in pathVar.split(';')) {
      if (dir.isEmpty) continue;
      final nodePath = '$dir\\node.exe';
      if (File(nodePath).existsSync()) return nodePath;
    }

    // Last resort
    return 'node';
  }
}
