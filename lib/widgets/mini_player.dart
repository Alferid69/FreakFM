import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../views/now_playing_page.dart';
import 'art_color.dart';
import 'song_artwork_widget.dart';

/// Spotify's floating mini player: a rounded card tinted with the cover's
/// colour, with a like button, play/pause and a thin progress line.
/// Tap or swipe up to expand; swipe left/right to skip.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return ValueListenableBuilder<Song?>(
      valueListenable: player.currentSong,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();
        return ArtColorBuilder(
          song: song,
          builder: (context, color) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -250) player.next();
                if (v > 250) player.previous();
              },
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -250) openNowPlaying(context);
              },
              child: Material(
                key: const ValueKey('mini_player'),
                color: Color.lerp(color, Colors.black, 0.25),
                borderRadius: BorderRadius.circular(6),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openNowPlaying(context),
                  child: SizedBox(
                    height: 58,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 4, 10),
                          child: Row(
                            children: [
                              SongArtworkWidget(song: song, size: 40, borderRadius: 4, showPlayingBadge: false),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: Color(0xCCFFFFFF)),
                                    ),
                                  ],
                                ),
                              ),
                              ValueListenableBuilder<int>(
                                valueListenable: LibraryService.instance.revision,
                                builder: (context, _, _) => IconButton(
                                  key: const ValueKey('mini_like'),
                                  icon: Icon(
                                    song.isFavorite ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                    color: song.isFavorite ? AppTheme.spotifyGreen : Colors.white,
                                  ),
                                  tooltip: song.isFavorite ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                                  onPressed: () => LibraryService.instance.toggleFavorite(song),
                                ),
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: player.isPlaying,
                                builder: (context, playing, _) => IconButton(
                                  key: const ValueKey('mini_play'),
                                  iconSize: 32,
                                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                                  tooltip: playing ? 'Pause' : 'Play',
                                  onPressed: player.togglePlayPause,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(left: 8, right: 8, bottom: 0, child: _MiniProgress(song: song)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Only this line listens to the playback position.
class _MiniProgress extends StatelessWidget {
  final Song song;
  const _MiniProgress({required this.song});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([player.position, player.duration]),
      builder: (context, _) {
        final total = player.duration.value.inMilliseconds > 0
            ? player.duration.value.inMilliseconds
            : (song.durationMs > 0 ? song.durationMs : 1);
        final value = (player.position.value.inMilliseconds / total).clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 2,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      },
    );
  }
}
