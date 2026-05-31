import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

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
