import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

enum VolumeDisplayMode {
  /// Always shows the horizontal slider inline
  inline,

  /// Compact icon button with popover slider on tap
  popup,

  /// Starts as an icon and expands horizontally when hovered or toggled
  expandable,
}

class VolumeControllerWidget extends StatefulWidget {
  final VolumeDisplayMode mode;
  final double sliderWidth;
  final bool showPercentage;
  final Color? iconColor;

  const VolumeControllerWidget({
    super.key,
    this.mode = VolumeDisplayMode.inline,
    this.sliderWidth = 100.0,
    this.showPercentage = true,
    this.iconColor,
  });

  @override
  State<VolumeControllerWidget> createState() => _VolumeControllerWidgetState();
}

class _VolumeControllerWidgetState extends State<VolumeControllerWidget> {
  final AudioPlayerService _player = AudioPlayerService.instance;
  bool _isExpanded = false;

  IconData _getVolumeIcon(double vol) {
    if (vol <= 0.0) return Icons.volume_off_rounded;
    if (vol < 0.35) return Icons.volume_mute_rounded;
    if (vol < 0.70) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  void _handleScroll(PointerScrollEvent event) {
    // Scroll down reduces volume, scroll up increases volume
    final delta = event.scrollDelta.dy < 0 ? 0.05 : -0.05;
    _player.adjustVolumeBy(delta);
  }

  void _showVolumePopup(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(ctx).pop(),
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: (offset.dx - 40).clamp(16.0, MediaQuery.of(context).size.width - 220),
              top: (offset.dy - 64).clamp(40.0, MediaQuery.of(context).size.height - 100),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.spotifyCardElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2E2E2E), width: 1),
                    boxShadow: AppTheme.elevatedShadow,
                  ),
                  child: const VolumeControllerWidget(
                    mode: VolumeDisplayMode.inline,
                    sliderWidth: 110,
                    showPercentage: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _player.volume,
      builder: (context, vol, _) {
        final iconData = _getVolumeIcon(vol);
        final percentText = '${(vol * 100).round()}%';
        final isMuted = vol <= 0.0;

        final speakerButton = IconButton(
          iconSize: 20,
          splashRadius: 20,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: Icon(
            iconData,
            size: 20,
            color: isMuted
                ? const Color(0xFFEF4444)
                : (widget.iconColor ?? (vol > 0 ? AppTheme.spotifyWhite : AppTheme.spotifyLightGrey)),
          ),
          tooltip: isMuted
              ? 'Unmute (currently 0%)'
              : 'Mute ($percentText) • Scroll to adjust',
          onPressed: () {
            if (widget.mode == VolumeDisplayMode.popup) {
              _showVolumePopup(context);
            } else {
              _player.toggleMute();
            }
          },
        );

        if (widget.mode == VolumeDisplayMode.popup) {
          return Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                _handleScroll(signal);
              }
            },
            child: speakerButton,
          );
        }

        if (widget.mode == VolumeDisplayMode.expandable) {
          return MouseRegion(
            onEnter: (_) => setState(() => _isExpanded = true),
            onExit: (_) => setState(() => _isExpanded = false),
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  _handleScroll(signal);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  speakerButton,
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: _isExpanded ? widget.sliderWidth : 0.0,
                    child: _isExpanded
                        ? _buildSlider(vol, percentText)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }

        // Inline Mode
        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _handleScroll(signal);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              speakerButton,
              SizedBox(
                width: widget.sliderWidth,
                child: _buildSlider(vol, percentText),
              ),
              if (widget.showPercentage) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 34,
                  child: Text(
                    percentText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.spotifyLightGrey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlider(double vol, String percentText) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppTheme.spotifyGreen,
        inactiveTrackColor: const Color(0xFF4D4D4D),
        thumbColor: AppTheme.spotifyWhite,
      ),
      child: Slider(
        value: vol,
        min: 0.0,
        max: 1.0,
        onChanged: (val) => _player.setVolume(val),
      ),
    );
  }
}
