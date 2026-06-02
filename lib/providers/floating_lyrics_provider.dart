import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/floating_lyrics_service.dart';

final floatingLyricsVisibleProvider = StateProvider<bool>((ref) {
  // Listen for external close (right-click on overlay)
  FloatingLyricsService.onClosed = () {
    // Can't directly update provider from callback, use Future.microtask
    Future.microtask(() {
      if (ref.exists) {
        ref.invalidateSelf();
      }
    });
  };
  return false;
});