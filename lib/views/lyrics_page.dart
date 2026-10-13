import 'package:flutter/material.dart';
import '../models/lyrics_model.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/player_controls.dart';
import 'now_playing_page.dart';

/// Opens full-screen lyrics on [color], like Spotify's lyrics view.
void openLyricsPage(BuildContext context, Color color) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => LyricsPage(color: color),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation),
        child: child,
      ),
    ),
  );
}

class LyricsPage extends StatelessWidget {
  final Color color;
  const LyricsPage({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return ValueListenableBuilder<Song?>(
      valueListenable: player.currentSong,
      builder: (context, song, _) {
        if (song == null) return Scaffold(backgroundColor: color);
        return Scaffold(
          backgroundColor: color,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('lyrics_close'),
                        iconSize: 32,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xCCFFFFFF)),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<LyricsData?>(
                        valueListenable: LyricsService.instance.currentLyrics,
                        builder: (context, lyrics, _) {
                          final ready = lyrics != null && lyrics.songId == song.id && !lyrics.isEmpty && !lyrics.isError;
                          return IconButton(
                            icon: const Icon(Icons.ios_share_rounded),
                            tooltip: 'Share lyrics',
                            onPressed: ready ? () => shareLyricsFor(context, song, lyrics) : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(child: LyricsView(song: song, immersive: true)),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color.withValues(alpha: 0), color],
                      stops: const [0, 0.3],
                    ),
                  ),
                  child: Column(
                    children: [
                      SeekBar(song: song),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 36,
                            icon: const Icon(Icons.skip_previous_rounded),
                            onPressed: player.previous,
                          ),
                          const SizedBox(width: 16),
                          ValueListenableBuilder<bool>(
                            valueListenable: player.isPlaying,
                            builder: (context, playing, _) => Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: player.togglePlayPause,
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Icon(
                                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(iconSize: 36, icon: const Icon(Icons.skip_next_rounded), onPressed: player.next),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
