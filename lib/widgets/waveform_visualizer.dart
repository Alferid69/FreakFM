import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double barWidth;
  final Color? color;

  const WaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 4,
    this.height = 16,
    this.barWidth = 3,
    this.color,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _randomSeeds = [];

  @override
  void initState() {
    super.initState();
    final random = Random();
    for (int i = 0; i < widget.barCount; i++) {
      _randomSeeds.add(random.nextDouble() * 2 * pi);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {});
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppTheme.accentAmber;

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          double factor = 0.3;
          if (widget.isPlaying) {
            final t = _controller.value * 2 * pi + _randomSeeds[index];
            factor = (sin(t) + 1) / 2;
            factor = 0.2 + factor * 0.8;
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: widget.barWidth,
            height: widget.height * factor,
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

/// Large Frequency Spectrum for Full Player
class FrequencySpectrumWidget extends StatelessWidget {
  final bool isPlaying;
  final double height;

  const FrequencySpectrumWidget({
    super.key,
    required this.isPlaying,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return WaveformVisualizer(
      isPlaying: isPlaying,
      barCount: 28,
      height: height,
      barWidth: 3.5,
      color: AppTheme.accentAmberLight,
    );
  }
}
