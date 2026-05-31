import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

    // 1. Already running?
    log('Checking port $port...');
    if (await _isPortOpen(port)) {
      log('Server already running on port $port ✓');
      _started = true;
      return true;
    }

    // 2. Find node.exe
    final nodeExe = await _findNode();
    if (nodeExe == null) {
      log('ERROR: node.exe not found in PATH');
      return false;
    }
    log('Node found: $nodeExe');

    // 3. Find backend directory
    final backendDir = await _findBackendDir();
    if (backendDir == null) {
      log('ERROR: backend/server.js not found');
      return false;
    }
    log('Backend dir: $backendDir');

    // Verify node_modules exists
    final nodeModules = Directory('$backendDir\\node_modules');
    if (!await nodeModules.exists()) {
      log('ERROR: node_modules missing — run npm install');
      return false;
    }

    // 4. Start server
    log('Starting server...');
    try {
      _process = await Process.start(
        nodeExe,
        ['server.js'],
        workingDirectory: backendDir,
        mode: ProcessStartMode.normal,
      );

      _process!.exitCode.then((code) {
        if (!_started) {
          log('Server exited with code $code');
        }
      });

      // 5. Wait for port
      log('Waiting for port $port...');
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _isPortOpen(port)) {
          _started = true;
          log('Server ready on port $port ✓');
          return true;
        }
        if (i > 0 && i % 4 == 0) {
          log('Waiting... (${i ~/ 2}s)');
        }
      }

      log('ERROR: server did not start in 15s');
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
    // Collect all possible base directories
    final bases = <String>[];

    // Current working directory
    bases.add(Directory.current.path);

    // Executable directory (for release builds)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    bases.add(exeDir);

    // One level up from exe (build/windows/x64/runner/Release -> project root)
    bases.add('$exeDir\\..');
    bases.add('$exeDir\\..\\..');
    bases.add('$exeDir\\..\\..\\..');
    bases.add('$exeDir\\..\\..\\..\\..');
    bases.add('$exeDir\\..\\..\\..\\..\\..');

    // Try each base + /backend
    for (final base in bases) {
      try {
        final dir = Directory(base).absolute.path;
        final serverJs = File('$dir\\backend\\server.js');
        if (await serverJs.exists()) {
          return '$dir\\backend';
        }
      } catch (_) {}
    }

    // Last resort: search from documents
    try {
      final docs = await getApplicationDocumentsDirectory();
      final searchDir = Directory('${docs.path}\\Codex');
      if (await searchDir.exists()) {
        await for (final entity in searchDir.list(recursive: true, followLinks: false)) {
          if (entity is File && entity.path.endsWith('backend\\server.js')) {
            return entity.parent.path;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> _findNode() async {
    // Method 1: where.exe
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

    // Method 2: PATH scan
    final pathVar = Platform.environment['PATH'] ?? '';
    for (final dir in pathVar.split(';')) {
      if (dir.isEmpty) continue;
      final nodePath = '$dir\\node.exe';
      if (File(nodePath).existsSync()) return nodePath;
    }

    // Method 3: common locations
    final common = [
      '${Platform.environment['PROGRAMFILES']}\\nodejs\\node.exe',
      '${Platform.environment['LOCALAPPDATA']}\\Programs\\node\\node.exe',
      'D:\\tec_use\\node_js\\node.exe',
    ];
    for (final p in common) {
      if (p.isNotEmpty && File(p).existsSync()) return p;
    }

    return null;
  }
}
