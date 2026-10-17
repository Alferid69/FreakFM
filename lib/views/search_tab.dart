import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/collections.dart';
import '../services/library_service.dart';
import '../services/online_music_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork_widget.dart';
import '../widgets/spotify_widgets.dart';
import '../widgets/track_list_tile.dart';

/// Spotify-style Search: a white search bar, "Browse all" genre tiles, and
/// grouped results (songs, artists, albums, folders) while typing.
class SearchTab extends StatefulWidget {
  final FocusNode? focusNode;
  const SearchTab({super.key, this.focusNode});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final library = LibraryService.instance;
  final player = AudioPlayerService.instance;
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  // Online mode: results from the streaming provider instead of the library.
  bool _online = false;
  List<Song> _onlineSongs = const [];
  bool _onlineLoading = false;
  String? _onlineError;
  int _onlineToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: _online ? 450 : 150), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
      if (_online) _loadOnline();
    });
  }

  void _setScope(bool online) {
    if (_online == online) return;
    setState(() => _online = online);
    if (online && _onlineSongs.isEmpty) _loadOnline();
  }

  Future<void> _loadOnline() async {
    final text = _controller.text.trim();
    final token = ++_onlineToken;
    setState(() {
      _onlineLoading = true;
      _onlineError = null;
    });
    try {
      final provider = OnlineMusic.provider;
      final songs = text.isEmpty ? await provider.trending() : await provider.search(text);
      if (!mounted || token != _onlineToken) return;
      setState(() {
        _onlineSongs = songs;
        _onlineLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _onlineToken) return;
      setState(() {
        _onlineSongs = const [];
        _onlineLoading = false;
        _onlineError = e is OnlineMusicException ? e.message : 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([library.songs, library.revision]),
          builder: (context, _) => CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Text('Search', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                ),
              ),
              SliverPersistentHeader(pinned: true, delegate: _SearchBarDelegate(_buildSearchField())),
              SliverToBoxAdapter(child: _buildScopeChips()),
              if (_online)
                ..._buildOnline()
              else if (_query.isEmpty)
                ..._buildBrowse()
              else
                ..._buildResults(),
              const SliverToBoxAdapter(child: SizedBox(height: kBottomChromePadding)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChips() {
    Widget chip(String label, bool online, Key key) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: key,
            label: Text(label),
            selected: _online == online,
            showCheckmark: false,
            onSelected: (_) => _setScope(online),
            selectedColor: AppTheme.spotifyGreen,
            backgroundColor: AppTheme.spotifyCardElevated,
            side: BorderSide.none,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: _online == online ? Colors.black : Colors.white,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        children: [
          chip('On this device', false, const ValueKey('scope_device')),
          chip('Online', true, const ValueKey('scope_online')),
        ],
      ),
    );
  }

  List<Widget> _buildOnline() {
    final provider = OnlineMusic.provider;
    final text = _controller.text.trim();
    final header = SliverToBoxAdapter(
      child: SectionHeader(text.isEmpty ? 'Trending on ${provider.name}' : 'Results for "$text"'),
    );

    Widget message(String title, String body, {Widget? action}) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Column(
              children: [
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppTheme.spotifyLightGrey)),
                if (action != null) ...[const SizedBox(height: 16), action],
              ],
            ),
          ),
        );

    if (_onlineLoading) {
      return [
        header,
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.spotifyGreen),
              ),
            ),
          ),
        ),
      ];
    }
    if (_onlineError != null) {
      return [
        message(
          "Couldn't load music",
          _onlineError!,
          action: FilledButton(
            key: const ValueKey('online_retry'),
            onPressed: _loadOnline,
            child: const Text('Try again'),
          ),
        ),
      ];
    }
    if (_onlineSongs.isEmpty) {
      return [message('No tracks found', 'Try a different artist, song or genre.')];
    }

    final source = 'Online • ${provider.name}';
    return [
      header,
      ValueListenableBuilder<Song?>(
        valueListenable: player.currentSong,
        builder: (context, current, _) => ValueListenableBuilder<bool>(
          valueListenable: player.isPlaying,
          builder: (context, playing, _) => SliverList.builder(
            itemCount: _onlineSongs.length,
            itemBuilder: (context, i) {
              final song = _onlineSongs[i];
              return TrackListTile(
                key: ValueKey('online_${song.id}'),
                song: song,
                isCurrent: current?.id == song.id,
                isPlaying: playing,
                subtitle: song.artist,
                onTap: () => player.playSong(song, contextQueue: _onlineSongs, source: source),
                onFavoriteToggle: () {},
              );
            },
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            'Music from ${provider.name} — streamed over the internet.',
            style: const TextStyle(fontSize: 12, color: AppTheme.spotifyLightGrey),
          ),
        ),
      ),
    ];
  }

  Widget _buildSearchField() {
    return Container(
      color: AppTheme.spotifyBlack,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        key: const ValueKey('search_field'),
        controller: _controller,
        focusNode: widget.focusNode,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: Colors.black,
        style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: _online ? 'Search songs and artists online' : 'What do you want to listen to?',
          hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 15, fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.black, size: 26),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('search_clear'),
                  icon: const Icon(Icons.close_rounded, color: Colors.black),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  List<Widget> _buildBrowse() {
    final songs = library.songs.value;
    final genres = Collections.genres(songs);
    final top = (List.of(genres)..sort((a, b) => b.playCount.compareTo(a.playCount))).take(4).toList();

    Widget grid(List<Collection> items) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, c) => SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: c.crossAxisExtent >= 600 ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.75,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _GenreTile(collection: items[i]),
            ),
          ),
        );

    return [
      if (top.isNotEmpty && top.first.playCount > 0) ...[
        const SliverToBoxAdapter(child: SectionHeader('Your top genres')),
        grid(top),
      ],
      const SliverToBoxAdapter(child: SectionHeader('Browse all')),
      grid(genres),
    ];
  }

  List<Widget> _buildResults() {
    final songs = library.songs.value;
    bool match(String s) => s.toLowerCase().contains(_query);

    final songHits = songs.where((s) => match(s.title) || match(s.artist) || match(s.album)).toList()
      ..sort((a, b) {
        // Titles starting with the query first, then by popularity.
        final ap = a.title.toLowerCase().startsWith(_query) ? 0 : 1;
        final bp = b.title.toLowerCase().startsWith(_query) ? 0 : 1;
        return ap != bp ? ap - bp : b.playCount.compareTo(a.playCount);
      });
    final artistHits = Collections.artists(songs).where((c) => match(c.ref.title)).toList();
    final albumHits = Collections.albums(songs).where((c) => match(c.ref.title) || match(c.artistLine)).toList();
    final folderHits = Collections.folders(songs).where((c) => match(c.ref.title)).toList();
    final genreHits = Collections.genres(songs).where((c) => match(c.ref.title)).toList();

    if (songHits.isEmpty && artistHits.isEmpty && albumHits.isEmpty && folderHits.isEmpty && genreHits.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
            child: Column(
              children: [
                Text(
                  'Couldn\'t find "${_controller.text.trim()}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try searching again using a different spelling or keyword.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.spotifyLightGrey),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final shownSongs = songHits.take(30).toList();
    final results = Collection(const CollectionRef(CollectionKind.allSongs, 'search', 'Search results'), songHits);

    return [
      if (songHits.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader('Songs')),
        ValueListenableBuilder<Song?>(
          valueListenable: player.currentSong,
          builder: (context, current, _) => ValueListenableBuilder<bool>(
            valueListenable: player.isPlaying,
            builder: (context, playing, _) => SliverList.builder(
              itemCount: shownSongs.length,
              itemBuilder: (context, i) {
                final song = shownSongs[i];
                return TrackListTile(
                  song: song,
                  isCurrent: current?.id == song.id,
                  isPlaying: playing,
                  subtitle: 'Song • ${song.artist}',
                  onTap: () => playCollection(results, startAt: song),
                  onFavoriteToggle: () => library.toggleFavorite(song),
                );
              },
            ),
          ),
        ),
      ],
      if (artistHits.isNotEmpty) SliverToBoxAdapter(child: Shelf(title: 'Artists', items: artistHits.take(20).toList())),
      if (albumHits.isNotEmpty) SliverToBoxAdapter(child: Shelf(title: 'Albums', items: albumHits.take(20).toList())),
      if (genreHits.isNotEmpty) SliverToBoxAdapter(child: Shelf(title: 'Genres', items: genreHits.take(20).toList())),
      if (folderHits.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader('Folders')),
        SliverList.builder(
          itemCount: min(folderHits.length, 10),
          itemBuilder: (context, i) => CollectionListTile(collection: folderHits[i]),
        ),
      ],
    ];
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SearchBarDelegate(this.child);

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _SearchBarDelegate oldDelegate) => oldDelegate.child != child;
}

/// Coloured "Browse all" tile with a tilted cover peeking out, like Spotify.
class _GenreTile extends StatelessWidget {
  final Collection collection;
  const _GenreTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    final song = collection.cover;
    return Material(
      color: AppTheme.colorFor(collection.ref.title),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('genre_${collection.ref.key}'),
        onTap: () => openCollection(context, collection.ref),
        child: LayoutBuilder(
          builder: (context, box) {
            final art = box.maxHeight * 0.62;
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    collection.ref.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
                  ),
                ),
                if (song != null)
                  Positioned(
                    right: -art * 0.18,
                    bottom: -art * 0.06,
                    child: Transform.rotate(
                      angle: 0.44,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
                        ),
                        child: SongArtworkWidget(song: song, size: art, borderRadius: 4, showPlayingBadge: false),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
