import 'dart:math';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'song_artwork_widget.dart';
import 'waveform_visualizer.dart';

/// Thin white seek bar with elapsed / total time. Follows playback, but only
/// seeks once a drag ends so scrubbing never stutters the audio.
class SeekBar extends StatefulWidget {
  final Song song;
  const SeekBar({super.key, required this.song});

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  final player = AudioPlayerService.instance;
  double? _dragMs;

  static const _timeStyle = TextStyle(
    fontSize: 11.5,
    color: Color(0xB3FFFFFF),
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([player.duration, player.position]),
      builder: (context, _) {
        final pos = player.position.value;
        final total = player.duration.value.inMilliseconds > 0
            ? player.duration.value.inMilliseconds
            : max(widget.song.durationMs, 1);
        final totalMs = max(total, pos.inMilliseconds);
        final shown = (_dragMs ?? pos.inMilliseconds.toDouble()).clamp(0.0, totalMs.toDouble());

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: _dragMs != null ? 4 : 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: _dragMs != null ? 7 : 5),
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                key: const ValueKey('seek_slider'),
                value: shown,
                max: totalMs.toDouble(),
                onChangeStart: (v) => setState(() => _dragMs = v),
                onChanged: (v) => setState(() => _dragMs = v),
                onChangeEnd: (v) async {
                  await player.seek(Duration(milliseconds: v.toInt()));
                  if (mounted) setState(() => _dragMs = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(Duration(milliseconds: shown.toInt())), style: _timeStyle),
                  Text(formatDuration(Duration(milliseconds: totalMs)), style: _timeStyle),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shuffle · previous · play/pause · next · repeat, Spotify style: active
/// shuffle/repeat are green with a small dot underneath.
class TransportControls extends StatelessWidget {
  final double playSize;
  const TransportControls({super.key, this.playSize = 64});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;

    Widget toggle({required bool active, required IconData icon, required String tooltip, required VoidCallback onTap, Key? key}) {
      return IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: active ? AppTheme.spotifyGreen : Colors.white),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppTheme.spotifyGreen : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: player.isShuffle,
          builder: (context, on, _) => toggle(
            key: const ValueKey('np_shuffle'),
            active: on,
            icon: Icons.shuffle_rounded,
            tooltip: on ? 'Disable shuffle' : 'Enable shuffle',
            onTap: player.toggleShuffle,
          ),
        ),
        IconButton(
          key: const ValueKey('np_prev'),
          iconSize: 40,
          tooltip: 'Previous',
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: player.previous,
        ),
        ValueListenableBuilder<bool>(
          valueListenable: player.isPlaying,
          builder: (context, playing, _) => Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey('np_play'),
              customBorder: const CircleBorder(),
              onTap: player.togglePlayPause,
              child: SizedBox(
                width: playSize,
                height: playSize,
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: playSize * 0.55,
                  semanticLabel: playing ? 'Pause' : 'Play',
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('np_next'),
          iconSize: 40,
          tooltip: 'Next',
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: player.next,
        ),
        ValueListenableBuilder<AudioRepeatMode>(
          valueListenable: player.repeatMode,
          builder: (context, mode, _) => toggle(
            key: const ValueKey('np_repeat'),
            active: mode != AudioRepeatMode.off,
            icon: mode == AudioRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            tooltip: switch (mode) {
              AudioRepeatMode.off => 'Enable repeat',
              AudioRepeatMode.all => 'Enable repeat one',
              AudioRepeatMode.one => 'Disable repeat',
            },
            onTap: player.cycleRepeatMode,
          ),
        ),
      ],
    );
  }
}

Widget _sheetHandle() => Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: AppTheme.spotifySubdued, borderRadius: BorderRadius.circular(2)),
      ),
    );

/// Sleep timer options (minutes or end of track).
void showSleepTimerSheet(BuildContext context) {
  final player = AudioPlayerService.instance;
  const options = <(String, int?, bool)>[
    ('5 minutes', 5, false),
    ('15 minutes', 15, false),
    ('30 minutes', 30, false),
    ('45 minutes', 45, false),
    ('1 hour', 60, false),
    ('End of track', null, true),
  ];
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) {
      final active = player.sleepTimerRemainingMinutes.value != null || player.sleepAtEndOfTrack.value;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sleep timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final (label, minutes, endOfTrack) in options)
              ListTile(
                title: Text(label, textAlign: TextAlign.center),
                onTap: () {
                  player.setSleepTimer(minutes, endOfTrack: endOfTrack);
                  Navigator.pop(sheet);
                },
              ),
            if (active)
              ListTile(
                title: const Text('Turn off timer', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.spotifyGreen)),
                onTap: () {
                  player.cancelSleepTimer();
                  Navigator.pop(sheet);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Playback speed picker.
void showSpeedSheet(BuildContext context) {
  final player = AudioPlayerService.instance;
  const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetHandle(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Playback speed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          for (final s in speeds)
            ListTile(
              title: Text(
                '${s}x',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: player.playbackSpeed.value == s ? AppTheme.spotifyGreen : AppTheme.textPrimary,
                  fontWeight: player.playbackSpeed.value == s ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              onTap: () {
                player.setPlaybackSpeed(s);
                Navigator.pop(sheet);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Full-screen queue, like Spotify's: "Now playing", then "Next from …".
void openQueuePage(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => const QueuePage()),
  );
}

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('queue_close'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(
          [player.queue, player.queueIndex, player.currentSong, player.isPlaying, player.playingFrom, player.isShuffle],
        ),
        builder: (context, _) {
          final current = player.currentSong.value;
          final upcoming = player.upcoming;

          Widget row(Song s, {int? queueIndex, bool now = false}) => ListTile(
                contentPadding: const EdgeInsets.only(left: 16, right: 4),
                leading: SongArtworkWidget(song: s, size: 48, borderRadius: 2, showPlayingBadge: false),
                title: Row(
                  children: [
                    if (now && player.isPlaying.value) ...[
                      const WaveformVisualizer(isPlaying: true, barCount: 3, height: 11, barWidth: 2.2),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: now ? AppTheme.spotifyGreen : AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(s.artist, maxLines: 1, style: const TextStyle(color: AppTheme.spotifyLightGrey)),
                trailing: queueIndex == null
                    ? null
                    : IconButton(
                        tooltip: 'Remove from queue',
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.spotifyLightGrey),
                        onPressed: () => player.removeFromQueue(queueIndex),
                      ),
                onTap: now ? null : () => player.playSong(s),
              );

          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Now playing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (current != null) row(current, now: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Next from: ${player.playingFrom.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (upcoming.isNotEmpty)
                      TextButton(onPressed: player.clearQueue, child: const Text('Clear')),
                  ],
                ),
              ),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nothing else queued.', style: TextStyle(color: AppTheme.spotifyLightGrey)),
                ),
              for (final (i, s) in upcoming) row(s, queueIndex: i),
            ],
          );
        },
      ),
    );
  }
}
