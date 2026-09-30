import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

class EqualizerDialog extends StatefulWidget {
  const EqualizerDialog({super.key});

  @override
  State<EqualizerDialog> createState() => _EqualizerDialogState();
}

class _EqualizerDialogState extends State<EqualizerDialog> {
  final player = AudioPlayerService.instance;
  final List<String> _presets = [
    'Hi-Fi Warm',
    'Bass Boost',
    'Vocal Clarity',
    'Acoustic Studio',
    'Electronic Club',
    'Flat Linear',
  ];

  final Map<String, List<double>> _presetBands = {
    'Hi-Fi Warm': [3.0, 2.0, 0.0, 1.5, 3.5],
    'Bass Boost': [6.0, 4.5, 1.0, 0.0, 0.0],
    'Vocal Clarity': [-1.0, 1.0, 4.5, 3.0, 1.0],
    'Acoustic Studio': [2.0, 1.0, 2.0, 3.0, 4.0],
    'Electronic Club': [5.0, 3.0, 0.0, 2.5, 4.5],
    'Flat Linear': [0.0, 0.0, 0.0, 0.0, 0.0],
  };

  late List<double> _currentBands;

  @override
  void initState() {
    super.initState();
    final current = player.equalizerPreset.value;
    _currentBands = List<double>.from(_presetBands[current] ?? [0.0, 0.0, 0.0, 0.0, 0.0]);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppTheme.accentAmber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'DSP Equalizer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Presets Wrap
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final isSelected = player.equalizerPreset.value == preset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  selectedColor: AppTheme.accentAmber,
                  backgroundColor: AppTheme.bgSurface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF1B1713) : AppTheme.textPrimary,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        player.setEqualizerPreset(preset);
                        _currentBands = List<double>.from(_presetBands[preset]!);
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 5-Band Sliders
            SizedBox(
              height: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBandSlider(0, '60Hz', _currentBands[0]),
                  _buildBandSlider(1, '230Hz', _currentBands[1]),
                  _buildBandSlider(2, '910Hz', _currentBands[2]),
                  _buildBandSlider(3, '3.6kHz', _currentBands[3]),
                  _buildBandSlider(4, '14kHz', _currentBands[4]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'APPLY FILTER',
                  style: TextStyle(
                    color: AppTheme.accentAmber,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandSlider(int index, String freq, double value) {
    return Column(
      children: [
        Text(
          '${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)}dB',
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: AppTheme.textMuted,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: value,
                min: -6.0,
                max: 6.0,
                onChanged: (val) {
                  setState(() {
                    _currentBands[index] = val;
                  });
                },
              ),
            ),
          ),
        ),
        Text(
          freq,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
