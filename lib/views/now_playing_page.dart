import 'dart:math';
import 'package:flutter/material.dart';
import '../models/lyrics_model.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/collections.dart';
import '../services/library_service.dart';
import '../services/lyrics_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/art_color.dart';
import '../widgets/equalizer_dialog.dart';
import '../widgets/lyrics_share_dialog.dart';
import '../widgets/player_controls.dart';
import '../widgets/song_artwork_widget.dart';
import '../widgets/song_options_sheet.dart';
import '../widgets/volume_controller.dart';
import 'lyrics_page.dart';
import 'root_shell.dart';

/// Opens the full-screen player, sliding up from the bottom like Spotify.
void openNowPlaying(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => const NowPlayingPage(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation),
        child: child,
      ),
    ),
  );
}

/// Lighter, more saturated version of the backdrop for the lyrics card.
Color lyricsCardColor(Color backdrop) {
  final hsl = HSLColor.fromColor(backdrop);
  return hsl.withLightness((hsl.lightness + 0.12).clamp(0.3, 0.5)).withSaturation((hsl.saturation + 0.1).clamp(0.0, 0.8)).toColor();
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return ValueListenableBuilder<Song?>(
      valueListenable: player.currentSong,
      builder: (context, song, _) {
        if (song == null) {
          return Scaffold(
            body: Center(
              child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nothing playing')),
            ),
          );
        }
        return ArtColorBuilder(
          song: song,
          builder: (context, color) => _NowPlayingBody(song: song, color: color),
        );
      },
    );
  }
}

class _NowPlayingBody extends StatelessWidget {
  final Song song;
  final Color color;

  const _NowPlayingBody({required this.song, required this.color});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    final media = MediaQuery.of(context);
    final width = media.size.width;
    // Size the cover so everything down to the controls fits on one screen.
    final reserved = media.padding.vertical + 56 + 76 + 64 + 84 + 52 + 72;
    final cover = max(160.0, min(min(width - 48, 440.0), media.size.height - reserved));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, Color.lerp(color, Colors.black, 0.55)!, AppTheme.spotifyBlack],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Center(
                      child: GestureDetector(
                        // Swipe the cover to change track.
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -250) player.next();
                          if (v > 250) player.previous();
                        },
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 12))],
                          ),
                          child: SongArtworkWidget(song: song, size: cover, borderRadius: 8, showPlayingBadge: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildTitleRow(context),
                    const SizedBox(height: 10),
                    SeekBar(song: song),
                    const SizedBox(height: 4),
                    const TransportControls(),
                    const SizedBox(height: 6),
                    _buildBottomRow(context),
                    const SizedBox(height: 20),
                    _LyricsCard(song: song, color: lyricsCardColor(color)),
                    const SizedBox(height: 16),
                    _QueueCard(color: Color.lerp(color, Colors.black, 0.45)!),
                    const SizedBox(height: 16),
                    _AboutCard(song: song, color: Color.lerp(color, Colors.black, 0.45)!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final player = AudioPlayerService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('np_close'),
            iconSize: 32,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: player.playingFrom,
              builder: (context, from, _) {
                final parts = from.split(' • ');
                final type = parts.length > 1 ? parts.first.toUpperCase() : 'PLAYLIST';
                final name = parts.length > 1 ? parts.sublist(1).join(' • ') : from;
                return Column(
                  children: [
                    Text(
                      'PLAYING FROM $type',
                      style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: Color(0xCCFFFFFF)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('np_more'),
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More options',
            onPressed: () => _showPlayerMenu(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _openFromPlayer(context, Collections.artistOf(song)),
                child: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, color: Color(0xB3FFFFFF)),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: LibraryService.instance.revision,
          builder: (context, _, _) => IconButton(
            key: const ValueKey('np_like'),
            iconSize: 28,
            icon: Icon(
              song.isFavorite ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: song.isFavorite ? AppTheme.spotifyGreen : Colors.white,
            ),
            tooltip: song.isFavorite ? 'Remove from Liked Songs' : 'Save to Liked Songs',
            onPressed: () => LibraryService.instance.toggleFavorite(song),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext context) {
    final player = AudioPlayerService.instance;
    return Row(
      children: [
        if (player.equalizerSupported)
          IconButton(
            key: const ValueKey('np_equalizer'),
            icon: const Icon(Icons.tune_rounded, size: 22),
            tooltip: 'Equalizer',
            onPressed: () => showDialog(context: context, builder: (_) => const EqualizerDialog()),
          )
        else if (isDesktopPlatform)
          const VolumeControllerWidget(mode: VolumeDisplayMode.popup)
        else
          const SizedBox(width: 48),
        const Spacer(),
        ValueListenableBuilder<double>(
          valueListenable: player.playbackSpeed,
          builder: (context, speed, _) => speed == 1.0
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: () => showSpeedSheet(context),
                  child: Text('${speed}x', style: const TextStyle(color: AppTheme.spotifyGreen)),
                ),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([player.sleepTimerRemainingMinutes, player.sleepAtEndOfTrack]),
          builder: (context, _) {
            final on = player.sleepTimerRemainingMinutes.value != null || player.sleepAtEndOfTrack.value;
            return IconButton(
              key: const ValueKey('np_sleep'),
              icon: Icon(on ? Icons.bedtime_rounded : Icons.bedtime_outlined, size: 22,
                  color: on ? AppTheme.spotifyGreen : Colors.white),
              tooltip: on ? 'Sleep timer on' : 'Sleep timer',
              onPressed: () => showSleepTimerSheet(context),
            );
          },
        ),
        IconButton(
          key: const ValueKey('np_queue'),
          icon: const Icon(Icons.queue_music_rounded, size: 24),
          tooltip: 'Queue',
          onPressed: () => openQueuePage(context),
        ),
      ],
    );
  }

  void _showPlayerMenu(BuildContext context) {
    final player = AudioPlayerService.instance;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              leading: SongArtworkWidget(song: song, size: 48, borderRadius: 2, showPlayingBadge: false),
              title: Text(song.title, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(song.artist, maxLines: 1, style: const TextStyle(color: AppTheme.spotifyLightGrey)),
            ),
            const Divider(height: 1, color: Color(0xFF3A3A3A)),
            ListTile(
              leading: const Icon(Icons.album_rounded),
              title: const Text('Go to album'),
              onTap: () {
                Navigator.pop(sheet);
                _openFromPlayer(context, Collections.albumOf(song));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Go to artist'),
              onTap: () {
                Navigator.pop(sheet);
                _openFromPlayer(context, Collections.artistOf(song));
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: Text('Playback speed (${player.playbackSpeed.value}x)'),
              onTap: () {
                Navigator.pop(sheet);
                showSpeedSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Sleep timer'),
              onTap: () {
                Navigator.pop(sheet);
                showSleepTimerSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz_rounded),
              title: const Text('More song options'),
              onTap: () {
                Navigator.pop(sheet);
                showSongOptions(context, song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Closes the player and shows the album/artist page.
  void _openFromPlayer(BuildContext context, CollectionRef ref) {
    Navigator.of(context).pop();
    RootShell.globalKey.currentState?.openCollection(ref);
  }
}

/// Spotify's coloured lyrics card: current line bright, upcoming lines dim.
class _LyricsCard extends StatelessWidget {
  final Song song;
  final Color color;

  const _LyricsCard({required this.song, required this.color});

  @override
  Widget build(BuildContext context) {
    final lyricsService = LyricsService.instance;
    final player = AudioPlayerService.instance;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('np_lyrics_card'),
        onTap: () => openLyricsPage(context, color),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: AnimatedBuilder(
            animation: Listenable.merge([lyricsService.currentLyrics, lyricsService.isLoading, player.position]),
            builder: (context, _) {
              final LyricsData? lyrics = lyricsService.currentLyrics.value;
              final ready = lyrics != null && lyrics.songId == song.id && !lyrics.isEmpty && !lyrics.isError;

              Widget body;
              if (!ready) {
                final text = lyricsService.isLoading.value
                    ? 'Looking for lyrics…'
                    : (lyrics?.songId == song.id && lyrics?.errorMessage != null)
                        ? lyrics!.errorMessage!
                        : 'Lyrics will show here when available.';
                body = Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white));
              } else {
                final lines = <(String, bool)>[];
                if (lyrics.isSynced) {
                  final pos = player.position.value;
                  var i = 0;
                  for (var j = 0; j < lyrics.syncedLines.length; j++) {
                    if (pos >= lyrics.syncedLines[j].timestamp) i = j;
                  }
                  for (var j = i; j < min(i + 4, lyrics.syncedLines.length); j++) {
                    final t = lyrics.syncedLines[j].text;
                    lines.add((t.isEmpty ? '♪' : t, j == i));
                  }
                } else {
                  for (final l in (lyrics.plainLyrics ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(4)) {
                    lines.add((l.trim(), true));
                  }
                }
                body = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (text, active) in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: active ? Colors.white : Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Lyrics preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      if (ready)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.ios_share_rounded, size: 20),
                          tooltip: 'Share lyrics',
                          onPressed: () => shareLyricsFor(context, song, lyrics),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  body,
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: () => openLyricsPage(context, color),
                      child: const Text('Show lyrics'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Opens the lyrics share flow for [lyrics].
void shareLyricsFor(BuildContext context, Song song, LyricsData lyrics) {
  final lines = lyrics.isSynced && lyrics.syncedLines.isNotEmpty
      ? lyrics.syncedLines.map((l) => l.text).toList()
      : (lyrics.plainLyrics ?? '').split('\n');
  if (lines.isEmpty) return;
  LyricsShareDialog.show(context, song: song, allLines: lines, initialActiveIndex: 0);
}

class _QueueCard extends StatelessWidget {
  final Color color;
  const _QueueCard({required this.color});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([player.queue, player.queueIndex, player.isShuffle]),
      builder: (context, _) {
        final next = player.upcoming.take(3).toList();
        return Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openQueuePage(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Next in queue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(onPressed: () => openQueuePage(context), child: const Text('Open queue')),
                    ],
                  ),
                  if (next.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Nothing else queued.', style: TextStyle(color: Color(0xB3FFFFFF))),
                    ),
                  for (final (_, s) in next)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SongArtworkWidget(song: s, size: 40, borderRadius: 2, showPlayingBadge: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
                                Text(
                                  s.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AboutCard extends StatelessWidget {
  final Song song;
  final Color color;
  const _AboutCard({required this.song, required this.color});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Album', song.album),
      if (song.year != null) ('Year', '${song.year}'),
      ('Genre', song.genre),
      ('Format', song.qualityBadge),
      ('Plays', '${song.playCount}'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About this song', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 72, child: Text(k, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13))),
                  Expanded(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${plural(song.playCount, 'play')} • ${song.formattedFileSize}',
            style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
          ),
        ],
      ),
    );
  }
}
