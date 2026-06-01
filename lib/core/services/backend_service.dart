import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import '../utils/debug_log.dart';

// ═══════════════════════════════════════════════════════════════
//  Windows API via dart:ffi
// ═══════════════════════════════════════════════════════════════

const _CREATE_NO_WINDOW     = 0x08000000;
const _STARTF_USESTDHANDLES = 0x00000100;
const _GENERIC_READ         = 0x80000000;
const _GENERIC_WRITE        = 0x40000000;
const _FILE_SHARE_READ      = 0x00000001;
const _FILE_SHARE_WRITE     = 0x00000002;
const _CREATE_ALWAYS        = 2;
const _OPEN_EXISTING        = 3;
const _FILE_ATTRIBUTE_NORMAL = 0x80;

// ── SECURITY_ATTRIBUTES (needed for inheritable handles) ────────

final class _SECURITY_ATTRIBUTES extends Struct {
  @Uint32()
  external int nLength;
  @Uint32()
  external int bInheritHandle; // TRUE = child inherits this handle
  external Pointer<Void> lpSecurityDescriptor;
}

// ── Structures ──────────────────────────────────────────────────

final class _STARTUPINFOW extends Struct {
  @Uint32()
  external int cb;
  external Pointer<Utf16> lpReserved;
  external Pointer<Utf16> lpDesktop;
  external Pointer<Utf16> lpTitle;
  @Uint32()
  external int dwX;
  @Uint32()
  external int dwY;
  @Uint32()
  external int dwXSize;
  @Uint32()
  external int dwYSize;
  @Uint32()
  external int dwXCountChars;
  @Uint32()
  external int dwYCountChars;
  @Uint32()
  external int dwFillAttribute;
  @Uint32()
  external int dwFlags;
  @Uint16()
  external int wShowWindow;
  @Uint16()
  external int cbReserved2;
  external Pointer<Uint8> lpReserved2;
  external Pointer<Void> hStdInput;
  external Pointer<Void> hStdOutput;
  external Pointer<Void> hStdError;
}

final class _PROCESS_INFORMATION extends Struct {
  external Pointer<Void> hProcess;
  external Pointer<Void> hThread;
  @Uint32()
  external int dwProcessId;
  @Uint32()
  external int dwThreadId;
}

// ── Function signatures ─────────────────────────────────────────

typedef _CreateProcessWNative = Int32 Function(
  Pointer<Utf16> lpApplicationName,
  Pointer<Utf16> lpCommandLine,
  Pointer<_SECURITY_ATTRIBUTES> lpProcessAttributes,
  Pointer<_SECURITY_ATTRIBUTES> lpThreadAttributes,
  Int32 bInheritHandles,
  Uint32 dwCreationFlags,
  Pointer<Void> lpEnvironment,
  Pointer<Utf16> lpCurrentDirectory,
  Pointer<_STARTUPINFOW> lpStartupInfo,
  Pointer<_PROCESS_INFORMATION> lpProcessInformation,
);
typedef _CreateProcessWDart = int Function(
  Pointer<Utf16> lpApplicationName,
  Pointer<Utf16> lpCommandLine,
  Pointer<_SECURITY_ATTRIBUTES> lpProcessAttributes,
  Pointer<_SECURITY_ATTRIBUTES> lpThreadAttributes,
  int bInheritHandles,
  int dwCreationFlags,
  Pointer<Void> lpEnvironment,
  Pointer<Utf16> lpCurrentDirectory,
  Pointer<_STARTUPINFOW> lpStartupInfo,
  Pointer<_PROCESS_INFORMATION> lpProcessInformation,
);

typedef _CreateFileWNative = Pointer<Void> Function(
  Pointer<Utf16> lpFileName,
  Uint32 dwDesiredAccess,
  Uint32 dwShareMode,
  Pointer<_SECURITY_ATTRIBUTES> lpSecurityAttributes,
  Uint32 dwCreationDisposition,
  Uint32 dwFlagsAndAttributes,
  Pointer<Void> hTemplateFile,
);
typedef _CreateFileWDart = Pointer<Void> Function(
  Pointer<Utf16> lpFileName,
  int dwDesiredAccess,
  int dwShareMode,
  Pointer<_SECURITY_ATTRIBUTES> lpSecurityAttributes,
  int dwCreationDisposition,
  int dwFlagsAndAttributes,
  Pointer<Void> hTemplateFile,
);

typedef _SetHandleInformationNative = Int32 Function(Pointer<Void>, Uint32, Uint32);
typedef _SetHandleInformationDart = int Function(Pointer<Void>, int, int);

typedef _TerminateProcessNative = Int32 Function(Pointer<Void>, Uint32);
typedef _TerminateProcessDart = int Function(Pointer<Void>, int);

typedef _CloseHandleNative = Int32 Function(Pointer<Void>);
typedef _CloseHandleDart = int Function(Pointer<Void>);

typedef _GetLastErrorNative = Uint32 Function();
typedef _GetLastErrorDart = int Function();

typedef _WaitForSingleObjectNative = Uint32 Function(Pointer<Void>, Uint32);
typedef _WaitForSingleObjectDart = int Function(Pointer<Void>, int);

// ── Win32 API wrapper ───────────────────────────────────────────

class _Win32 {
  static final _dll = DynamicLibrary.open('kernel32.dll');

  static final _createProcessW = _dll.lookupFunction<
      _CreateProcessWNative, _CreateProcessWDart>('CreateProcessW');
  static final _createFileW = _dll.lookupFunction<
      _CreateFileWNative, _CreateFileWDart>('CreateFileW');
  static final _setHandleInformation = _dll.lookupFunction<
      _SetHandleInformationNative, _SetHandleInformationDart>('SetHandleInformation');
  static final _terminateProcess = _dll.lookupFunction<
      _TerminateProcessNative, _TerminateProcessDart>('TerminateProcess');
  static final _closeHandle = _dll.lookupFunction<
      _CloseHandleNative, _CloseHandleDart>('CloseHandle');
  static final _getLastError = _dll.lookupFunction<
      _GetLastErrorNative, _GetLastErrorDart>('GetLastError');
  static final _waitForSingleObject = _dll.lookupFunction<
      _WaitForSingleObjectNative, _WaitForSingleObjectDart>('WaitForSingleObject');

  static final _invalidHandle = Pointer<Void>.fromAddress(-1);

  /// Open a file or device with inheritable flag.
  static Pointer<Void>? openFile(String path,
      {bool write = false, bool create = false}) {
    final p = path.toNativeUtf16();
    // SECURITY_ATTRIBUTES with bInheritHandle=TRUE so child process inherits the handle
    final sa = calloc<_SECURITY_ATTRIBUTES>();
    sa.ref.nLength = sizeOf<_SECURITY_ATTRIBUTES>();
    sa.ref.bInheritHandle = 1; // TRUE
    try {
      final h = _createFileW(
        p,
        write ? _GENERIC_WRITE : _GENERIC_READ,
        _FILE_SHARE_READ | _FILE_SHARE_WRITE,
        sa,
        create ? _CREATE_ALWAYS : _OPEN_EXISTING,
        _FILE_ATTRIBUTE_NORMAL,
        nullptr,
      );
      return h == _invalidHandle ? null : h;
    } finally {
      calloc.free(p);
      calloc.free(sa);
    }
  }

  /// Start a process with CREATE_NO_WINDOW (invisible, no console).
  static (Pointer<Void>, int)? startHidden({
    required String commandLine,
    String? workDir,
    Pointer<Void>? hStdIn,
    Pointer<Void>? hStdOut,
    Pointer<Void>? hStdErr,
  }) {
    final cmdP = commandLine.toNativeUtf16();
    final dirP = workDir?.toNativeUtf16();
    final si = calloc<_STARTUPINFOW>();
    final pi = calloc<_PROCESS_INFORMATION>();

    si.ref.cb = sizeOf<_STARTUPINFOW>();
    si.ref.dwFlags = _STARTF_USESTDHANDLES;
    si.ref.hStdInput = hStdIn ?? _invalidHandle;
    si.ref.hStdOutput = hStdOut ?? _invalidHandle;
    si.ref.hStdError = hStdErr ?? _invalidHandle;

    try {
      // bInheritHandles=TRUE so child inherits our stdin/stdout/stderr handles
      final ok = _createProcessW(
        nullptr, cmdP, nullptr, nullptr,
        1, // bInheritHandles = TRUE
        _CREATE_NO_WINDOW, nullptr, dirP ?? nullptr, si, pi,
      );
      if (ok == 0) {
        DebugLog.log('CreateProcessW failed: error=${_getLastError()}');
        return null;
      }
      final hProc = pi.ref.hProcess;
      final pid = pi.ref.dwProcessId;
      _closeHandle(pi.ref.hThread);
      return (hProc, pid);
    } finally {
      calloc.free(cmdP);
      if (dirP != null) calloc.free(dirP);
      calloc.free(si);
      calloc.free(pi);
    }
  }

  static void kill(Pointer<Void> hProcess) {
    _terminateProcess(hProcess, 0);
    _closeHandle(hProcess);
  }

  static void close(Pointer<Void> h) => _closeHandle(h);
}

// ═══════════════════════════════════════════════════════════════
//  Backend Service
// ═══════════════════════════════════════════════════════════════

class BackendService {
  static Pointer<Void>? _hProcess;
  static int _pid = 0;
  static bool _started = false;

  static bool get isRunning => _started;

  static Future<bool> start({int port = 3000, void Function(String)? onLog}) async {
    void log(String msg) {
      DebugLog.log(msg);
      onLog?.call(msg);
    }

    // 1. Kill orphaned node on this port
    await _killPortOwner(port);

    // 2. Already running?
    log('Checking port $port...');
    if (await _isPortOpen(port) && await _httpCheck(port)) {
      log('Server already running');
      _started = true;
      return true;
    }

    // 3. Find node
    final nodeExe = await _findNode();
    if (nodeExe == null) { log('ERROR: node.exe not found'); return false; }
    log('Node: $nodeExe');

    // 4. Find backend
    final backendDir = await _findBackendDir();
    if (backendDir == null) { log('ERROR: backend/server.js not found'); return false; }
    log('Backend: $backendDir');

    if (!await Directory('$backendDir\\node_modules').exists()) {
      log('ERROR: node_modules missing'); return false;
    }

    // 5. Open NUL for stdin, log file for stdout/stderr
    //    Handles MUST be inheritable for child to use them
    final logPath = '$backendDir\\server_output.log';
    final hNul = _Win32.openFile('NUL');
    final hLog = _Win32.openFile(logPath, write: true, create: true);
    if (hLog == null) { log('ERROR: cannot create log file'); return false; }

    // 6. Start node with CREATE_NO_WINDOW + inheritable handles
    log('Starting server (FFI, no window)...');
    final result = _Win32.startHidden(
      commandLine: '"$nodeExe" server.js',
      workDir: backendDir,
      hStdIn: hNul,
      hStdOut: hLog,
      hStdErr: hLog,
    );
    // Close our copies — child has inherited its own
    if (hNul != null) _Win32.close(hNul);
    _Win32.close(hLog);

    if (result == null) {
      log('ERROR: CreateProcessW failed');
      return false;
    }

    _hProcess = result.$1;
    _pid = result.$2;
    log('Node PID: $_pid');

    // 7. Wait for HTTP response
    log('Waiting for server...');
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await _isPortOpen(port) && await _httpCheck(port)) {
        _started = true;
        log('Server ready');
        return true;
      }
      if (i > 0 && i % 4 == 0) log('Waiting... (${i ~/ 2}s)');
    }

    // Read server log for debugging
    try {
      final c = await File(logPath).readAsString();
      if (c.trim().isNotEmpty) {
        final lines = c.split('\n');
        final tail = lines.skip(lines.length > 10 ? lines.length - 10 : 0).join('\n');
        log('Server log:\n$tail');
      } else {
        log('Server log empty — node may not have started');
      }
    } catch (_) {}
    log('ERROR: server not responding in 20s');
    stop();
    return false;
  }

  /// Stop the node process. Safe to call multiple times.
  static void stop() {
    if (_hProcess != null) {
      try {
        _Win32.kill(_hProcess!);
        DebugLog.log('Node killed via handle (PID=$_pid)');
      } catch (e) {
        DebugLog.log('Kill via handle failed: $e');
      }
      _hProcess = null;
    }
    if (_pid > 0) {
      try {
        Process.runSync('taskkill', ['/PID', '$_pid', '/T', '/F']);
        DebugLog.log('Node killed via taskkill PID=$_pid');
      } catch (_) {}
      _pid = 0;
    }
    _killPortOwnerSync(3000);
    _started = false;
  }

  static Future<bool> _isPortOpen(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1));
      await socket.close();
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> _httpCheck(int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      client.findProxy = (_) => 'DIRECT';
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/search?keywords=test&limit=1'));
      final res = await req.close();
      final body = await res.transform(const SystemEncoding().decoder).join();
      client.close();
      return res.statusCode == 200 && body.contains('"code"');
    } catch (_) { return false; }
  }

  static Future<void> _killPortOwner(int port) async {
    try {
      final result = await Process.run('netstat', ['-ano']);
      final lines = (result.stdout as String).split('\n');
      for (final line in lines) {
        if (line.contains(':$port') && line.contains('LISTENING')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          final pid = parts.last;
          if (pid.isNotEmpty && int.tryParse(pid) != null) {
            DebugLog.log('Killing orphan PID=$pid');
            await Process.run('taskkill', ['/PID', pid, '/T', '/F']);
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  static void _killPortOwnerSync(int port) {
    try {
      final result = Process.runSync('netstat', ['-ano']);
      final lines = (result.stdout as String).split('\n');
      for (final line in lines) {
        if (line.contains(':$port') && line.contains('LISTENING')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          final pid = parts.last;
          if (pid.isNotEmpty && int.tryParse(pid) != null) {
            DebugLog.log('Force-killing PID=$pid on port $port');
            Process.runSync('taskkill', ['/PID', pid, '/T', '/F']);
          }
        }
      }
    } catch (_) {}
  }

  static Future<String?> _findBackendDir() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '${Directory.current.path}\\backend',
      '$exeDir\\backend',
      '$exeDir\\..\\backend',
      '$exeDir\\..\\..\\backend',
      '$exeDir\\..\\..\\..\\backend',
      '$exeDir\\..\\..\\..\\..\\backend',
      '$exeDir\\..\\..\\..\\..\\..\\backend',
    ];
    for (final dir in candidates) {
      try {
        if (await File('${Directory(dir).absolute.path}\\server.js').exists()) {
          return Directory(dir).absolute.path;
        }
      } catch (_) {}
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
