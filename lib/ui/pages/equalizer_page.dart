import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class EqualizerPage extends ConsumerStatefulWidget {
  const EqualizerPage({super.key});

  @override
  ConsumerState<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends ConsumerState<EqualizerPage> {
  bool _enabled = true;
  String _selectedPreset = 'Flat';
  List<double> _gains = List.filled(10, 0.0);

  static const _frequencies = ['31', '62', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];
  static const _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Pop': [3.0, 2.0, 0.0, -1.0, 1.0, 3.0, 4.0, 3.0, 1.0, 0.0],
    'Rock': [4.0, 3.0, 1.0, 0.0, -1.0, 1.0, 3.0, 4.0, 4.0, 3.0],
    'Classical': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -2.0, -3.0, -3.0, -4.0],
    'Jazz': [3.0, 2.0, 0.0, 1.0, -1.0, -1.0, 0.0, 1.0, 2.0, 3.0],
    'Bass Boost': [6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Treble Boost': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 4.0, 5.0, 6.0],
  };

  void _applyPreset(String name) {
    final preset = _presets[name];
    if (preset != null) {
      setState(() {
        _selectedPreset = name;
        _gains = List.from(preset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  color: AppColors.textSecondary,
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                Text('Equalizer', style: Theme.of(context).textTheme.headlineLarge),
                const Spacer(),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Preset selector
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _presets.keys.map((name) {
                  final isSelected = name == _selectedPreset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textSecondary)),
                      selected: isSelected,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surfaceLight,
                      side: BorderSide.none,
                      onSelected: (_) => _applyPreset(name),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            // EQ Sliders
            Expanded(
              child: Opacity(
                opacity: _enabled ? 1.0 : 0.4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (i) => _EqBand(
                    frequency: _frequencies[i],
                    gain: _gains[i],
                    enabled: _enabled,
                    onChanged: (v) {
                      setState(() {
                        _gains[i] = v;
                        _selectedPreset = 'Custom';
                      });
                    },
                  )),
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _enabled ? () => _applyPreset('Flat') : null,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EqBand extends StatelessWidget {
  final String frequency;
  final double gain;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _EqBand({
    required this.frequency,
    required this.gain,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${gain > 0 ? '+' : ''}${gain.toStringAsFixed(0)} dB',
            style: const TextStyle(fontSize: 10, color: AppColors.textDisabled)),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceLight,
                thumbColor: AppColors.accent,
              ),
              child: Slider(
                value: gain,
                min: -12,
                max: 12,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(frequency, style: TextStyle(fontSize: 10, color: AppColors.textDisabled)),
        const SizedBox(height: 2),
        Text('Hz', style: TextStyle(fontSize: 8, color: AppColors.textDisabled.withValues(alpha: 0.5))),
      ],
    );
  }
}
