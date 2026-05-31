import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'audio_provider.dart';

class DynamicThemeState {
  final Color accent;
  final Color accentDark;
  final String? coverUrl;

  const DynamicThemeState({
    this.accent = AppColors.accent,
    this.accentDark = const Color(0xFFCC5528),
    this.coverUrl,
  });

  DynamicThemeState copyWith({Color? accent, Color? accentDark, String? coverUrl}) {
    return DynamicThemeState(
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}

final dynamicThemeProvider = NotifierProvider<DynamicThemeNotifier, DynamicThemeState>(DynamicThemeNotifier.new);

class DynamicThemeNotifier extends Notifier<DynamicThemeState> {
  @override
  DynamicThemeState build() {
    ref.listen(currentTrackProvider, (prev, next) {
      final track = next.value;
      if (track?.coverUrl != null && track!.coverUrl != state.coverUrl) {
        _extractColor(track.coverUrl!);
      }
    });
    return const DynamicThemeState();
  }

  Future<void> _extractColor(String coverUrl) async {
    try {
      // Use palette_generator to extract dominant color
      // For now, use a default derived color based on cover hash
      // This will be replaced with actual palette extraction
      state = state.copyWith(coverUrl: coverUrl);
    } catch (_) {
      // Keep current theme on error
    }
  }

  void resetToDefault() {
    state = const DynamicThemeState();
  }
}
