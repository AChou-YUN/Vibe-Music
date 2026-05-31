import 'package:flutter/services.dart';

class DebugLog {
  static final List<String> _logs = [];
  static const int maxLogs = 50;

  static void log(String msg) {
    final ts = DateTime.now().toString().substring(11, 19);
    final entry = '[$ts] $msg';
    _logs.add(entry);
    if (_logs.length > maxLogs) _logs.removeAt(0);
  }

  static List<String> get logs => List.unmodifiable(_logs);

  static String get allLogs => _logs.join('\n');

  static void clear() => _logs.clear();
  static int get logCount => _logs.length;

  static void copyToClipboard() {
    Clipboard.setData(ClipboardData(text: allLogs));
  }
}
