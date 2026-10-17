import 'package:flutter/material.dart';
import '../services/collections.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/battery_tip.dart';
import '../widgets/art_color.dart';
import '../widgets/spotify_widgets.dart';

enum _HomeFilter { all, albums, artists }

/// Spotify-style Home: filter pills, a two-column shortcut grid, then
/// shelves (recently played, top artists, mixes, recently added…).
class HomeTab extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const HomeTab({super.key, required this.onOpenSettings});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final library = LibraryService.instance;
  _HomeFilter _filter = _HomeFilter.all;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([library.songs, library.revision]),
        builder: (context, _) {
          final songs = library.songs.value;
          final albums = Collections.albums(songs);
          final artists = Collections.artists(songs);
          final recentAlbums = (albums.where((a) => a.lastPlayedAt > 0).toList()
            ..sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt)));
          final topArtists = (artists.where((a) => a.playCount > 0).toList()
            ..sort((a, b) => b.playCount.compareTo(a.playCount)));
          final newAlbums = (List.of(albums)..sort((a, b) => b.newestAdded.compareTo(a.newestAdded)));

          // Tint the top of the page with the most recent cover, like Spotify.
          final tintSong = recentAlbums.isNotEmpty ? recentAlbums.first.cover : (songs.isEmpty ? null : songs.first);

          return ArtColorBuilder(
            song: tintSong,
            builder: (context, tint) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [tint.withValues(alpha: 0.55), AppTheme.spotifyBlack],
                  stops: const [0.0, 0.32],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    const SliverToBoxAdapter(child: BatteryTip()),
                    if (songs.isEmpty)
                      SliverToBoxAdapter(child: _buildEmpty())
                    else ...switch (_filter) {
                      _HomeFilter.all => _buildAll(recentAlbums, topArtists, newAlbums),
                      _HomeFilter.albums => [_grid(newAlbums)],
                      _HomeFilter.artists => [_grid(topArtists.isEmpty ? artists : [...topArtists, ...artists.where((a) => a.playCount == 0)])],
                    },
                    const SliverToBoxAdapter(child: SizedBox(height: kBottomChromePadding)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 6),
      child: Row(
        children: [
          HeaderAvatar(onTap: widget.onOpenSettings),
          const SizedBox(width: 10),
          // Pills scroll sideways instead of overflowing with large text.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _HomeFilter.values) ...[
                    FilterPill(
                      key: ValueKey('home_filter_${f.name}'),
                      label: switch (f) {
                        _HomeFilter.all => 'All',
                        _HomeFilter.albums => 'Albums',
                        _HomeFilter.artists => 'Artists',
                      },
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('open_settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAll(
    List<Collection> recentAlbums,
    List<Collection> topArtists,
    List<Collection> newAlbums,
  ) {
    final all = library.songs.value;
    final liked = Collections.resolve(CollectionRef.liked, all);
    final recentlyAdded = Collections.resolve(CollectionRef.recentlyAdded, all);
    final mostPlayed = Collections.resolve(CollectionRef.mostPlayed, all);
    final history = Collections.resolve(CollectionRef.recentlyPlayed, all);

    // Shortcut grid: playlists first, then recently played albums/artists.
    final shortcuts = <Collection>[
      liked,
      if (history.songs.isNotEmpty) history,
      ...recentAlbums.take(4),
      if (mostPlayed.songs.isNotEmpty) mostPlayed,
      recentlyAdded,
      ...newAlbums,
    ];
    final seen = <CollectionRef>{};
    final grid = shortcuts.where((c) => seen.add(c.ref)).take(8).toList();

    final genres = Collections.genres(all)..sort((a, b) => b.songs.length.compareTo(a.songs.length));

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(_greeting, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        sliver: SliverLayoutBuilder(
          builder: (context, c) => SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.crossAxisExtent >= 700 ? 4 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 56,
            ),
            itemCount: grid.length,
            itemBuilder: (context, i) => ShortcutTile(key: ValueKey('shortcut_${grid[i].ref.key}'), collection: grid[i]),
          ),
        ),
      ),
      if (recentAlbums.isNotEmpty) SliverToBoxAdapter(child: Shelf(title: 'Recently played', items: recentAlbums.take(12).toList())),
      if (topArtists.isNotEmpty) SliverToBoxAdapter(child: Shelf(title: 'Your top artists', items: topArtists.take(12).toList())),
      if (genres.isNotEmpty)
        SliverToBoxAdapter(
          child: _MixShelf(title: 'Your mixes', genres: genres.take(8).toList()),
        ),
      SliverToBoxAdapter(child: Shelf(title: 'Recently added', items: newAlbums.take(12).toList())),
      if (topArtists.isEmpty)
        SliverToBoxAdapter(child: Shelf(title: 'Artists', items: Collections.artists(all).take(12).toList())),
    ];
  }

  Widget _grid(List<Collection> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, c) => SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: c.crossAxisExtent >= 600 ? 4 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.74,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => LayoutBuilder(
            builder: (context, box) => ShelfCard(collection: items[i], width: box.maxWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(32, 80, 32, 0),
      child: Column(
        children: [
          Icon(Icons.library_music_rounded, size: 56, color: AppTheme.spotifySubdued),
          SizedBox(height: 16),
          Text('Your music will show up here', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'Open Your Library and pull down to scan, or add a folder.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.spotifyLightGrey),
          ),
        ],
      ),
    );
  }
}

/// "Your mixes": one card per genre with a coloured band, like Spotify's
/// Daily Mix covers. Opens the genre.
class _MixShelf extends StatelessWidget {
  final String title;
  final List<Collection> genres;

  const _MixShelf({required this.title, required this.genres});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: genres.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final g = genres[i];
              final color = AppTheme.colorFor(g.ref.title);
              return SizedBox(
                width: 150,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => openCollection(context, g.ref),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              g.cover == null
                                  ? ColoredBox(color: color)
                                  : CollectionCover(
                                      collection: Collection(Collections.albumOf(g.cover!), g.songs),
                                      size: 150,
                                      radius: 0,
                                    ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: 30,
                                  color: color,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${g.ref.title} Mix',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(color: AppTheme.spotifyGreen, shape: BoxShape.circle),
                                  child: const Icon(Icons.graphic_eq_rounded, size: 14, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        g.songs.map((s) => s.artist).toSet().take(3).join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.spotifyLightGrey, height: 1.3),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
