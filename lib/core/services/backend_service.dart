import 'dart:io';
import '../utils/debug_log.dart';

class BackendService {
  static Process? _process;
  static bool _started = false;

  static bool get isRunning => _started && _process != null;

  /// Start the NeteaseCloudMusicApi backend server.
  static Future<bool> start({int port = 3000}) async {
    if (_started && _process != null) {
      try {
        _process!.kill(ProcessSignal.sigwinch);
      } catch (_) {
        _process = null;
        _started = false;
      }
    }
    if (_started) return true;

    // Find backend directory
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '${Directory.current.path}${Platform.pathSeparator}backend',
      '$exeDir${Platform.pathSeparator}backend',
      '${exeDir}${Platform.pathSeparator}..${Platform.pathSeparator}backend',
    ];

    String? backendDir;
    for (final dir in candidates) {
      final serverJs = File('$dir${Platform.pathSeparator}server.js');
      if (await serverJs.exists()) {
        backendDir = dir;
        break;
      }
    }

    if (backendDir == null) {
      DebugLog.log('Backend: server.js not found');
      return false;
    }

    // Check if port is already in use (server might be running manually)
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1));
      await socket.close();
      DebugLog.log('Backend: already running on port $port');
      _started = true;
      return true;
    } catch (_) {
      // Port not in use, need to start
    }

    try {
      final nodeExe = _findNode();
      if (nodeExe == null) {
        DebugLog.log('Backend: node.exe not found');
        return false;
      }

      DebugLog.log('Backend: starting from $backendDir');
      _process = await Process.start(
        nodeExe,
        ['server.js'],
        workingDirectory: backendDir,
        mode: ProcessStartMode.detached,
      );

      // Wait for server to be ready (up to 15 seconds)
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1));
          await socket.close();
          _started = true;
          DebugLog.log('Backend: started OK (pid=${_process!.pid})');
          return true;
        } catch (_) {}
      }

      DebugLog.log('Backend: timeout waiting for server');
      _process?.kill();
      _process = null;
      return false;
    } catch (e) {
      DebugLog.log('Backend: start failed: $e');
      return false;
    }
  }

  /// Stop the backend server.
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

  static String? _findNode() {
    final pathVar = Platform.environment['PATH'] ?? '';
    for (final dir in pathVar.split(';')) {
      if (dir.isEmpty) continue;
      final nodePath = '$dir${Platform.pathSeparator}node.exe';
      if (File(nodePath).existsSync()) return nodePath;
    }
    final common = [
      '${Platform.environment['PROGRAMFILES']}\\nodejs\\node.exe',
      '${Platform.environment['PROGRAMFILES(X86)']}\\nodejs\\node.exe',
      '${Platform.environment['LOCALAPPDATA']}\\Programs\\node\\node.exe',
      '${Platform.environment['APPDATA']}\\nvm\\current\\node.exe',
    ];
    for (final p in common) {
      if (p.isNotEmpty && File(p).existsSync()) return p;
    }
    return 'node';
  }
}

