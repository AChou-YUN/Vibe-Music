import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

class VibeMusicApp extends ConsumerWidget {
  const VibeMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Vibe Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
