import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ui/shell/app_shell.dart';
import '../ui/pages/lyrics_page.dart';
import '../ui/pages/equalizer_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const AppShell(),
        routes: [
          GoRoute(
            path: 'lyrics',
            pageBuilder: (context, state) => const MaterialPage(child: LyricsPage()),
          ),
          GoRoute(
            path: 'equalizer',
            pageBuilder: (context, state) => const MaterialPage(child: EqualizerPage()),
          ),
        ],
      ),
    ],
  );
});
