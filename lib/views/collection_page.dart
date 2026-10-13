import 'dart:math';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/collections.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/art_color.dart';
import '../widgets/spotify_widgets.dart';
import '../widgets/track_list_tile.dart';

/// Spotify-style album / artist / playlist page: colour gradient from the
/// cover, large artwork, title block, shuffle + green play, then the songs.
class CollectionPage extends StatefulWidget {
  final CollectionRef collectionRef;

  const CollectionPage({super.key, required this.collectionRef});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final ScrollController _scroll = ScrollController();
  final player = AudioPlayerService.instance;
  final library = LibraryService.instance;

  CollectionRef get ref => widget.collectionRef;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _likedColor = Color(0xFF5038A0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([library.songs, library.revision]),
      builder: (context, _) {
        final collection = Collections.resolve(ref, library.songs.value);
        final coverSong = collection.cover;

        return ArtColorBuilder(
          song: ref.kind == CollectionKind.liked ? null : coverSong,
          builder: (context, artColor) {
            final color = switch (ref.kind) {
              CollectionKind.liked => _likedColor,
              CollectionKind.genre => AppTheme.colorFor(ref.title),
              _ => coverSong == null ? AppTheme.spotifyCardElevated : artColor,
            };
            return Scaffold(
              body: Stack(
                children: [
                  CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(context, collection, color)),
                      SliverToBoxAdapter(child: _buildInfo(context, collection)),
                      if (collection.songs.isEmpty)
                        SliverToBoxAdapter(child: _buildEmpty())
                      else
                        _buildTracks(collection),
                      if (ref.kind == CollectionKind.artist) SliverToBoxAdapter(child: _buildDiscography(collection)),
                      const SliverToBoxAdapter(child: SizedBox(height: kBottomChromePadding)),
                    ],
                  ),
                  _buildTopBar(context, color),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Collection collection, Color color) {
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final coverSize = min(width * 0.62, 260.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.55), AppTheme.spotifyBlack],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      padding: EdgeInsets.only(top: top + 56, bottom: 20),
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: ref.kind == CollectionKind.artist ? BoxShape.circle : BoxShape.rectangle,
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))],
        ),
        child: CollectionCover(collection: collection, size: coverSize, radius: 4),
      ),
    );
  }

  /// Back button, plus a solid bar with the title once the header scrolls away.
  Widget _buildTopBar(BuildContext context, Color color) {
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, _) {
        final offset = _scroll.hasClients ? _scroll.offset : 0.0;
        final t = ((offset - 220) / 80).clamp(0.0, 1.0);
        final barColor = Color.lerp(color, Colors.black, 0.35)!;
        return Container(
          height: top + 56,
          padding: EdgeInsets.only(top: top),
          color: barColor.withValues(alpha: t),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('collection_back'),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Opacity(
                  opacity: t,
                  child: Text(
                    ref.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfo(BuildContext context, Collection collection) {
    final songs = collection.songs;
    final totalMin = collection.totalMs ~/ 60000;
    final length = totalMin >= 60 ? '${totalMin ~/ 60} h ${totalMin % 60} min' : '$totalMin min';
    final year = songs.isEmpty ? null : songs.first.year;

    final String detail = switch (ref.kind) {
      CollectionKind.album => ['Album', if (year != null) '$year', plural(songs.length, 'song'), length].join(' • '),
      CollectionKind.artist =>
        '${plural(songs.length, 'song')} • ${plural(songs.map((s) => s.album).toSet().length, 'album')}',
      CollectionKind.folder => '${plural(songs.length, 'song')} • $length',
      _ => '${plural(songs.length, 'song')}, $length',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1),
          ),
          const SizedBox(height: 10),
          if (ref.kind == CollectionKind.album && songs.isNotEmpty) ...[
            InkWell(
              onTap: () => openCollection(context, Collections.artistOf(songs.first)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  collection.artistLine,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (ref.kind == CollectionKind.folder)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                ref.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.spotifySubdued),
              ),
            ),
          Text(detail, style: const TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                key: const ValueKey('collection_more'),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.spotifyLightGrey),
                tooltip: 'More options',
                onPressed: songs.isEmpty ? null : () => _showMoreSheet(context, collection),
              ),
              const Spacer(),
              ValueListenableBuilder<bool>(
                valueListenable: player.isShuffle,
                builder: (context, shuffle, _) => IconButton(
                  key: const ValueKey('collection_shuffle'),
                  iconSize: 28,
                  icon: Icon(Icons.shuffle_rounded, color: shuffle ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey),
                  tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
                  onPressed: () => player.toggleShuffle(),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: Listenable.merge([player.isPlaying, player.playingFrom]),
                builder: (context, _) {
                  final isThis = player.playingFrom.value == ref.playingFrom && player.currentSong.value != null;
                  return GreenPlayButton(
                    key: const ValueKey('collection_play'),
                    isPlaying: isThis && player.isPlaying.value,
                    onPressed: () {
                      if (songs.isEmpty) return;
                      if (isThis) {
                        player.togglePlayPause();
                      } else {
                        playCollection(collection, shuffle: player.isShuffle.value);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTracks(Collection collection) {
    final isAlbum = ref.kind == CollectionKind.album;
    return ValueListenableBuilder<Song?>(
      valueListenable: player.currentSong,
      builder: (context, current, _) => ValueListenableBuilder<bool>(
        valueListenable: player.isPlaying,
        builder: (context, playing, _) => SliverList.builder(
          itemCount: collection.songs.length,
          itemBuilder: (context, i) {
            final song = collection.songs[i];
            return TrackListTile(
              song: song,
              isCurrent: current?.id == song.id,
              isPlaying: playing,
              showArtwork: !isAlbum,
              subtitle: ref.kind == CollectionKind.artist ? song.album : song.artist,
              onTap: () => playCollection(collection, startAt: song),
              onFavoriteToggle: () => library.toggleFavorite(song),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiscography(Collection collection) {
    final albums = Collections.albums(collection.songs);
    if (albums.length < 2) return const SizedBox.shrink();
    return Shelf(title: 'Discography', items: albums);
  }

  Widget _buildEmpty() {
    final (title, body) = switch (ref.kind) {
      CollectionKind.liked => ('Songs you like will appear here', 'Save songs by tapping the + next to them.'),
      CollectionKind.mostPlayed => ('Nothing played yet', 'Your most played songs will show up here.'),
      CollectionKind.recentlyPlayed => ('Nothing played yet', 'Songs you play will show up here.'),
      _ => ('Nothing here', 'This collection has no songs right now.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppTheme.spotifyLightGrey)),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context, Collection collection) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    void toast(String m) => messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.spotifySubdued, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              leading: CollectionCover(collection: collection, size: 48),
              title: Text(ref.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(ref.typeLabel, style: const TextStyle(color: AppTheme.spotifyLightGrey)),
            ),
            const Divider(height: 1, color: Color(0xFF3A3A3A)),
            ListTile(
              leading: const Icon(Icons.shuffle_rounded),
              title: const Text('Shuffle play'),
              onTap: () {
                Navigator.pop(sheet);
                playCollection(collection, shuffle: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                Navigator.pop(sheet);
                for (final s in collection.songs) {
                  player.addToQueue(s);
                }
                toast('Added ${plural(collection.songs.length, 'song')} to the queue');
              },
            ),
            if (ref.kind == CollectionKind.folder)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide this folder'),
                onTap: () async {
                  Navigator.pop(sheet);
                  await library.hideFolder(ref.key);
                  if (context.mounted) Navigator.of(context).maybePop();
                  toast('Folder hidden from your library');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
