import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// Equalizer backed by the device's audio effect engine (Android). Bands and
/// their range come from the hardware, so the sliders change the real sound.
class EqualizerDialog extends StatefulWidget {
  const EqualizerDialog({super.key});

  @override
  State<EqualizerDialog> createState() => _EqualizerDialogState();
}

class _EqualizerDialogState extends State<EqualizerDialog> {
  final player = AudioPlayerService.instance;
  EqualizerState? _state;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await player.equalizerState();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  String _formatHz(double hz) =>
      hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k' : hz.toStringAsFixed(0);

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
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.accentAmber, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Equalizer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: player.equalizerEnabled,
                  builder: (context, enabled, _) => Switch(
                    key: const ValueKey('equalizer_switch'),
                    value: enabled,
                    activeThumbColor: AppTheme.accentAmber,
                    onChanged: _state == null ? null : (v) => player.setEqualizerEnabled(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!player.equalizerSupported || _state == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  !player.equalizerSupported
                      ? 'The equalizer is available on Android.'
                      : 'Start playing a song to adjust the equalizer.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              )
            else
              ValueListenableBuilder<bool>(
                valueListenable: player.equalizerEnabled,
                builder: (context, enabled, _) => Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: IgnorePointer(ignoring: !enabled, child: _buildControls(_state!)),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'DONE',
                  style: TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(EqualizerState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: player.equalizerPreset,
          builder: (context, current, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in AudioPlayerService.equalizerPresets.keys)
                ChoiceChip(
                  label: Text(preset),
                  selected: current == preset,
                  selectedColor: AppTheme.accentAmber,
                  backgroundColor: AppTheme.bgSurface,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: current == preset ? FontWeight.w700 : FontWeight.w500,
                    color: current == preset ? const Color(0xFF1B1713) : AppTheme.textPrimary,
                  ),
                  onSelected: (selected) async {
                    if (!selected) return;
                    await player.applyEqualizerPreset(preset);
                    await _refresh();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final band in state.bands)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${band.gainDb >= 0 ? "+" : ""}${band.gainDb.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: band.gainDb.clamp(state.minDb, state.maxDb),
                              min: state.minDb,
                              max: state.maxDb,
                              activeColor: AppTheme.accentAmber,
                              onChanged: (val) {
                                setState(() {
                                  _state = EqualizerState(
                                    minDb: state.minDb,
                                    maxDb: state.maxDb,
                                    bands: [
                                      for (final b in state.bands)
                                        b.index == band.index
                                            ? EqualizerBandInfo(b.index, b.centerFrequencyHz, val)
                                            : b,
                                    ],
                                  );
                                });
                              },
                              onChangeEnd: (val) => player.setEqualizerBandGain(band.index, val),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        _formatHz(band.centerFrequencyHz),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
