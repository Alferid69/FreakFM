import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/collections.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../views/collection_page.dart';
import 'song_artwork_widget.dart';
import 'waveform_visualizer.dart';

/// Space at the bottom of scrollable pages for the mini player + nav bar.
const double kBottomChromePadding = 150;

/// Opens [ref] in the current tab's navigator (keeps the bottom bar).
void openCollection(BuildContext context, CollectionRef ref) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CollectionPage(collectionRef: ref)),
  );
}

/// Plays [c] from the start (or shuffled) and records where it came from.
void playCollection(Collection c, {bool shuffle = false, Song? startAt}) {
  if (c.songs.isEmpty) return;
  final player = AudioPlayerService.instance;
  player.setShuffle(shuffle);
  final start = startAt ?? (shuffle ? (List.of(c.songs)..shuffle()).first : c.songs.first);
  player.playSong(start, contextQueue: c.songs, source: c.ref.playingFrom);
}

/// Cover for any collection: real artwork, a gradient for built-in
/// playlists, or a coloured tile/initial when no artwork exists.
class CollectionCover extends StatelessWidget {
  final Collection collection;
  final double size;
  final double radius;

  const CollectionCover({super.key, required this.collection, required this.size, this.radius = 4});

  static const _gradients = <CollectionKind, (List<Color>, IconData)>{
    CollectionKind.liked: ([Color(0xFF450AF5), Color(0xFFC4EFD9)], Icons.favorite_rounded),
    CollectionKind.allSongs: ([Color(0xFF1E3264), Color(0xFF1ED760)], Icons.library_music_rounded),
    CollectionKind.mostPlayed: ([Color(0xFFAF2896), Color(0xFF509BF5)], Icons.trending_up_rounded),
    CollectionKind.recentlyAdded: ([Color(0xFF8D67AB), Color(0xFF1E3264)], Icons.schedule_rounded),
    CollectionKind.recentlyPlayed: ([Color(0xFFE13300), Color(0xFF8400E7)], Icons.history_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final kind = collection.ref.kind;
    final gradient = _gradients[kind];
    if (gradient != null) {
      return _tile(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient.$1),
        ),
        child: Icon(gradient.$2, color: Colors.white, size: size * 0.38),
      );
    }

    if (kind == CollectionKind.genre) {
      final color = AppTheme.colorFor(collection.ref.title);
      return _tile(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              collection.ref.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: size * 0.14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
            ),
          ),
        ),
      );
    }

    final circle = kind == CollectionKind.artist;
    final song = collection.cover;
    final fallbackColor = AppTheme.colorFor(collection.ref.title);
    final fallback = _tile(
      decoration: BoxDecoration(
        color: circle ? fallbackColor : AppTheme.spotifyCardElevated,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      child: circle
          ? Text(
              collection.ref.title.trim().isEmpty ? '?' : collection.ref.title.trim()[0].toUpperCase(),
              style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: Colors.white),
            )
          : Icon(
              kind == CollectionKind.folder ? Icons.folder_rounded : Icons.music_note_rounded,
              color: AppTheme.spotifySubdued,
              size: size * 0.4,
            ),
    );
    if (song == null) return fallback;

    final art = SongArtworkWidget(
      song: song,
      size: size,
      borderRadius: circle ? size / 2 : radius,
      showPlayingBadge: false,
      fallback: fallback,
    );
    return circle ? ClipOval(child: art) : art;
  }

  Widget _tile({required BoxDecoration decoration, required Widget child}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: decoration,
        child: child,
      );
}

/// Spotify's big green circular play/pause button.
class GreenPlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;

  const GreenPlayButton({super.key, required this.isPlaying, required this.onPressed, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.spotifyGreen,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.black,
            size: size * 0.58,
            semanticLabel: isPlaying ? 'Pause' : 'Play',
          ),
        ),
      ),
    );
  }
}

/// Bold section title with an optional "Show all" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onShowAll;

  const SectionHeader(this.title, {super.key, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
          ),
          if (onShowAll != null)
            TextButton(
              onPressed: onShowAll,
              child: const Text('Show all', style: TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey)),
            ),
        ],
      ),
    );
  }
}

/// Square (or round, for artists) card used in horizontal shelves.
class ShelfCard extends StatelessWidget {
  final Collection collection;
  final double width;
  final String? subtitle;

  const ShelfCard({super.key, required this.collection, this.width = 150, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isArtist = collection.ref.kind == CollectionKind.artist;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => openCollection(context, collection.ref),
        child: Column(
          crossAxisAlignment: isArtist ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            CollectionCover(collection: collection, size: width, radius: 6),
            const SizedBox(height: 8),
            Text(
              collection.ref.title,
              maxLines: isArtist ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isArtist ? TextAlign.center : TextAlign.start,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.25),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle ?? _defaultSubtitle(collection),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isArtist ? TextAlign.center : TextAlign.start,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.spotifyLightGrey),
            ),
          ],
        ),
      ),
    );
  }

  static String _defaultSubtitle(Collection c) => switch (c.ref.kind) {
        CollectionKind.album => c.artistLine,
        CollectionKind.artist => 'Artist',
        _ => plural(c.songs.length, 'song'),
      };
}

/// Horizontal shelf of [ShelfCard]s under a [SectionHeader].
class Shelf extends StatelessWidget {
  final String title;
  final List<Collection> items;
  final VoidCallback? onShowAll;

  const Shelf({super.key, required this.title, required this.items, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isArtists = items.first.ref.kind == CollectionKind.artist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, onShowAll: onShowAll),
        SizedBox(
          height: isArtists ? 196 : 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) => ShelfCard(collection: items[i], width: isArtists ? 140 : 150),
          ),
        ),
      ],
    );
  }
}

/// Compact two-column shortcut tile from the top of Spotify's home screen.
class ShortcutTile extends StatelessWidget {
  final Collection collection;

  const ShortcutTile({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return Material(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCollection(context, collection.ref),
        child: Row(
          children: [
            CollectionCover(collection: collection, size: 56, radius: 0),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                collection.ref.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([player.playingFrom, player.isPlaying]),
              builder: (context, _) {
                final active = player.playingFrom.value == collection.ref.playingFrom && player.isPlaying.value;
                return active
                    ? const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: WaveformVisualizer(isPlaying: true, barCount: 3, height: 12, barWidth: 2.5),
                      )
                    : const SizedBox(width: 8);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Row in "Your Library": cover, title and "Type • detail" subtitle.
class CollectionListTile extends StatelessWidget {
  final Collection collection;
  final bool pinned;
  final String? subtitle;

  const CollectionListTile({super.key, required this.collection, this.pinned = false, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    final ref = collection.ref;
    final detail = subtitle ??
        switch (ref.kind) {
          CollectionKind.album => 'Album • ${collection.artistLine}',
          CollectionKind.artist => 'Artist',
          CollectionKind.folder => 'Folder • ${plural(collection.songs.length, 'song')}',
          CollectionKind.genre => 'Genre • ${plural(collection.songs.length, 'song')}',
          _ => 'Playlist • ${plural(collection.songs.length, 'song')}',
        };

    return InkWell(
      key: ValueKey('collection_${ref.kind.name}_${ref.key}'),
      onTap: () => openCollection(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            CollectionCover(collection: collection, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: player.playingFrom,
                    builder: (context, from, _) => Text(
                      ref.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: from == ref.playingFrom && player.currentSong.value != null
                            ? AppTheme.spotifyGreen
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (pinned) ...[
                        const Icon(Icons.push_pin_rounded, size: 13, color: AppTheme.spotifyGreen),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, color: AppTheme.spotifyLightGrey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small round avatar used in tab headers (the app icon).
class HeaderAvatar extends StatelessWidget {
  final VoidCallback? onTap;
  const HeaderAvatar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.spotifyGreen,
        backgroundImage: AssetImage('assets/icon/app_icon.png'),
      ),
    );
  }
}

/// Spotify-style filter chip (grey, or green when selected).
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterPill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.spotifyGreen : AppTheme.spotifyCardHighlight,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.black : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
