import 'dart:io';
import '../utils/debug_log.dart';

class BackendService {
  static Process? _process;
  static bool _started = false;

  static bool get isRunning => _started;

  static Future<bool> start({int port = 3000, void Function(String)? onLog}) async {
    void log(String msg) {
      DebugLog.log(msg);
      onLog?.call(msg);
    }

    // 1. Check if already running on port
    log('Checking port $port...');
    if (await _isPortOpen(port)) {
      log('Port $port is open — server already running');
      _started = true;
      return true;
    }

    // 2. Find backend directory
    final backendDir = await _findBackendDir();
    if (backendDir == null) {
      log('ERROR: backend/server.js not found');
      return false;
    }
    log('Found backend at: $backendDir');

    // 3. Find node
    final nodeExe = await _findNode() ?? 'node';
    log('Using node: $nodeExe');

    // 4. Start server
    log('Starting node server.js...');
    try {
      _process = await Process.start(
        nodeExe,
        ['server.js'],
        workingDirectory: backendDir,
        mode: ProcessStartMode.detachedWithStdio,
      );

      _process!.stdout.transform(const SystemEncoding().decoder).listen((line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) log(trimmed);
      });
      _process!.stderr.transform(const SystemEncoding().decoder).listen((line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) log('ERR: $trimmed');
      });

      // 5. Wait for port
      log('Waiting for port $port...');
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _isPortOpen(port)) {
          _started = true;
          log('Server is ready on port $port');
          return true;
        }
        if (i % 4 == 3) log('Still waiting... (${(i + 1) ~/ 2}s)');
      }

      log('ERROR: server did not respond in 10s');
      _process?.kill();
      _process = null;
      return false;
    } catch (e) {
      log('ERROR: $e');
      return false;
    }
  }

  static void stop() {
    if (_process != null) {
      try { _process!.kill(); } catch (_) {}
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
      '${exeDir}\\..\\backend',
    ];
    for (final dir in candidates) {
      if (await File('$dir\\server.js').exists()) return dir;
    }
    return null;
  }

  static Future<String?> _findNode() async {
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
    final pathVar = Platform.environment['PATH'] ?? '';
    for (final dir in pathVar.split(';')) {
      if (dir.isEmpty) continue;
      final nodePath = '$dir\\node.exe';
      if (File(nodePath).existsSync()) return nodePath;
    }
    return 'node';
  }
}

