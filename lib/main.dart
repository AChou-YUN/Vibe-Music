import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/services/backend_service.dart';
import 'core/services/floating_lyrics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use temp directory for Hive storage (sandbox-safe)
  final tmpPath = Platform.environment['TEMP'] ?? 'C:\\Windows\\Temp';
  final hiveDir = Directory('$tmpPath\\VibeMusic');
  if (!hiveDir.existsSync()) hiveDir.createSync(recursive: true);
  Hive.init(hiveDir.path);

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1200, 780),
    minimumSize: Size(900, 600),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Vibe Music',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: VibeMusicApp()));
}

class VibeMusicApp extends StatefulWidget {
  const VibeMusicApp({super.key});
  @override
  State<VibeMusicApp> createState() => _VibeMusicAppState();
}

class _VibeMusicAppState extends State<VibeMusicApp> with WidgetsBindingObserver implements WindowListener {
  bool _ready = false;
  bool _failed = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _init();
  }

  void _log(String msg) {
    if (mounted) setState(() => _logs.add(msg));
  }

  Future<void> _init() async {
    _log('Initializing...');
    await Future.delayed(const Duration(milliseconds: 200));

    final ok = await BackendService.start(onLog: _log);

    if (!ok) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _ready = true);
  }

  @override
  void onWindowClose() {
    FloatingLyricsService.dispose();
    BackendService.stop();
    windowManager.destroy();
  }

  @override
  void onWindowDestroyed() {
    exit(0);
  }

  // Unused WindowListener callbacks
  @override void onWindowEvent(String eventName) {}
  @override void onWindowFocus() {}
  @override void onWindowBlur() {}
  @override void onWindowMaximize() {}
  @override void onWindowUnmaximize() {}
  @override void onWindowMinimize() {}
  @override void onWindowRestore() {}
  @override void onWindowResize() {}
  @override void onWindowResized() {}
  @override void onWindowMove() {}
  @override void onWindowMoved() {}
  @override void onWindowEnterFullScreen() {}
  @override void onWindowLeaveFullScreen() {}
  @override void onWindowDocked() {}
  @override void onWindowUndocked() {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only stop backend when app is fully closing (detached), not on inactive/paused
    // inactive fires on any alt-tab which would kill the server unnecessarily
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BackendService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibe Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: _ready
          ? const App()
          : _SplashScreen(
              logs: _logs,
              failed: _failed,
              onRetry: _failed
                  ? () {
                      setState(() { _failed = false; _logs.clear(); });
                      _init();
                    }
                  : null,
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  final List<String> logs;
  final bool failed;
  final VoidCallback? onRetry;

  const _SplashScreen({required this.logs, this.failed = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.music_note_rounded, size: 40, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            const Text('Vibe Music', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 32),
            if (!failed)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
            else
              const Icon(Icons.error_outline_rounded, size: 28, color: AppColors.error),
            const SizedBox(height: 20),
            // Log panel
            Container(
              width: 440,
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final log in logs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Icon(
                              log.contains('ERROR') || log.contains('failed') ? Icons.close_rounded
                                  : log.contains('ready') || log.contains('responding') ? Icons.check_circle_rounded
                                  : Icons.arrow_right_rounded,
                              size: 13,
                              color: log.contains('ERROR') || log.contains('failed') ? AppColors.error
                                  : log.contains('ready') || log.contains('responding') ? Colors.greenAccent
                                  : AppColors.textDisabled,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(log, style: TextStyle(
                              fontSize: 11, fontFamily: 'Consolas',
                              color: log.contains('ERROR') || log.contains('failed') ? AppColors.error : AppColors.textSecondary,
                            ), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Exit button (always visible)
                OutlinedButton.icon(
                  onPressed: () {
                    BackendService.stop();
                    exit(0);
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Exit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                  ),
                ),
                if (failed) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
