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
  String _status = 'Initializing...';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Start backend
    setState(() => _status = 'Starting backend server...');
    final ok = await BackendService.start(
      onLog: (msg) {
        if (mounted) setState(() => _status = msg);
      },
    );

    if (!ok) {
      if (mounted) setState(() { _failed = true; _status = 'Backend failed to start'; });
      return;
    }

    // Small delay for UI polish
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() { _ready = true; _status = 'Ready'; });
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
      home: _ready ? const AppContent() : _SplashScreen(status: _status, failed: _failed, onRetry: _failed ? () { setState(() { _failed = false; _status = 'Retrying...'; }); _init(); } : null),
    );
  }
}

/// Splash / loading screen shown during initialization
class _SplashScreen extends StatelessWidget {
  final String status;
  final bool failed;
  final VoidCallback? onRetry;

  const _SplashScreen({required this.status, this.failed = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon
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
            if (!failed) ...[
              // Loading indicator
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              const SizedBox(height: 16),
            ] else ...[
              const Icon(Icons.error_outline_rounded, size: 24, color: AppColors.error),
              const SizedBox(height: 12),
            ],
            // Status text
            Text(
              status,
              style: TextStyle(fontSize: 12, color: failed ? AppColors.error : AppColors.textSecondary),
              textAlign: TextAlign.center,
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

/// Main app content (original AppShell + router)
class AppContent extends StatelessWidget {
  const AppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const App();
  }
}



