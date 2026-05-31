import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

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

class _VibeMusicAppState extends State<VibeMusicApp> {
  bool _ready = false;
  bool _failed = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _log(String msg) {
    if (mounted) setState(() => _logs.add(msg));
  }

  Future<void> _init() async {
    _log('Initializing Hive...');
    await Future.delayed(const Duration(milliseconds: 300));

    _log('Checking backend server...');
    final ok = await BackendService.start(
      onLog: (msg) => _log(msg),
    );

    if (!ok) {
      _log('Backend failed to start!');
      if (mounted) setState(() => _failed = true);
      return;
    }

    _log('Backend ready!');
    // Give user a moment to see the success message
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
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
                      setState(() {
                        _failed = false;
                        _logs.clear();
                      });
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
            // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.music_note_rounded, size: 40, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            const Text('Vibe Music', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 32),

            // Status
            if (!failed) ...[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
            ] else ...[
              const Icon(Icons.error_outline_rounded, size: 28, color: AppColors.error),
            ],
            const SizedBox(height: 20),

            // Log output
            Container(
              width: 400,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final log in logs.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            log.contains('ERROR') || log.contains('failed')
                                ? Icons.close_rounded
                                : log.contains('OK') || log.contains('ready') || log.contains('running')
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_right_rounded,
                            size: 14,
                            color: log.contains('ERROR') || log.contains('failed')
                                ? AppColors.error
                                : log.contains('OK') || log.contains('ready') || log.contains('running')
                                    ? Colors.greenAccent
                                    : AppColors.textDisabled,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              log,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Consolas',
                                color: log.contains('ERROR') || log.contains('failed')
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (failed) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
