import 'package:flutter/material.dart';
import '../services/collections.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/spotify_widgets.dart';

enum LibraryFilter { artists, albums, folders, genres }

enum LibrarySort { recents, recentlyAdded, alphabetical, mostPlayed }

/// "Your Library": pinned playlists, then albums and artists (or a filtered
/// view of artists / albums / folders / genres), as a list or a grid.
class LibraryTab extends StatefulWidget {
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddFolder;
  final Future<void> Function() onRescan;

  const LibraryTab({
    super.key,
    required this.onOpenSearch,
    required this.onOpenSettings,
    required this.onAddFolder,
    required this.onRescan,
  });

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final library = LibraryService.instance;
  LibraryFilter? _filter;
  LibrarySort _sort = LibrarySort.recents;
  bool _grid = false;

  static const _filterLabels = {
    LibraryFilter.artists: 'Artists',
    LibraryFilter.albums: 'Albums',
    LibraryFilter.folders: 'Folders',
    LibraryFilter.genres: 'Genres',
  };

  static const _sortLabels = {
    LibrarySort.recents: 'Recents',
    LibrarySort.recentlyAdded: 'Recently added',
    LibrarySort.alphabetical: 'Alphabetical',
    LibrarySort.mostPlayed: 'Most played',
  };

  List<Collection> _items() {
    final songs = library.songs.value;
    final List<Collection> items = switch (_filter) {
      LibraryFilter.artists => Collections.artists(songs),
      LibraryFilter.albums => Collections.albums(songs),
      LibraryFilter.folders => Collections.folders(songs),
      LibraryFilter.genres => Collections.genres(songs),
      null => [...Collections.albums(songs), ...Collections.artists(songs)],
    };
    switch (_sort) {
      case LibrarySort.recents:
        items.sort((a, b) {
          final byPlay = b.lastPlayedAt.compareTo(a.lastPlayedAt);
          return byPlay != 0 ? byPlay : a.ref.title.toLowerCase().compareTo(b.ref.title.toLowerCase());
        });
      case LibrarySort.recentlyAdded:
        items.sort((a, b) => b.newestAdded.compareTo(a.newestAdded));
      case LibrarySort.alphabetical:
        items.sort((a, b) => a.ref.title.toLowerCase().compareTo(b.ref.title.toLowerCase()));
      case LibrarySort.mostPlayed:
        items.sort((a, b) => b.playCount.compareTo(a.playCount));
    }
    return items;
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Sort by', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final s in LibrarySort.values)
              ListTile(
                title: Text(
                  _sortLabels[s]!,
                  style: TextStyle(color: s == _sort ? AppTheme.spotifyGreen : AppTheme.textPrimary),
                ),
                trailing: s == _sort ? const Icon(Icons.check_rounded, color: AppTheme.spotifyGreen) : null,
                onTap: () {
                  setState(() => _sort = s);
                  Navigator.pop(sheet);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([library.songs, library.revision]),
          builder: (context, _) {
            final songs = library.songs.value;
            final items = _items();
            final pinned = _filter == null
                ? [
                    Collections.resolve(CollectionRef.liked, songs),
                    Collections.resolve(CollectionRef.allSongs, songs),
                  ]
                : const <Collection>[];

            return Column(
              children: [
                _buildHeader(),
                _buildFilters(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.spotifyGreen,
                    backgroundColor: AppTheme.spotifyCardElevated,
                    onRefresh: widget.onRescan,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildSortRow()),
                        if (_grid)
                          _buildGrid([...pinned, ...items])
                        else ...[
                          SliverList.builder(
                            itemCount: pinned.length,
                            itemBuilder: (context, i) => CollectionListTile(
                              collection: pinned[i],
                              pinned: true,
                              subtitle: i == 1 ? 'Playlist • ${plural(songs.length, 'song')} on this device' : null,
                            ),
                          ),
                          SliverList.builder(
                            itemCount: items.length,
                            itemBuilder: (context, i) => CollectionListTile(collection: items[i]),
                          ),
                        ],
                        if (songs.isEmpty) SliverToBoxAdapter(child: _buildEmptyHint()),
                        const SliverToBoxAdapter(child: SizedBox(height: kBottomChromePadding)),
                      ],
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
      child: Row(
        children: [
          HeaderAvatar(onTap: widget.onOpenSettings),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Your Library', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          ),
          IconButton(
            key: const ValueKey('library_search'),
            icon: const Icon(Icons.search_rounded, size: 26),
            tooltip: 'Search',
            onPressed: widget.onOpenSearch,
          ),
          IconButton(
            key: const ValueKey('library_add_folder'),
            icon: const Icon(Icons.add_rounded, size: 28),
            tooltip: 'Add folder',
            onPressed: widget.onAddFolder,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          if (_filter != null) ...[
            Material(
              color: AppTheme.spotifyCardHighlight,
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey('library_filter_clear'),
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _filter = null),
                child: const SizedBox(width: 34, height: 34, child: Icon(Icons.close_rounded, size: 18)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          for (final f in LibraryFilter.values)
            if (_filter == null || _filter == f)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterPill(
                  key: ValueKey('library_filter_${f.name}'),
                  label: _filterLabels[f]!,
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = _filter == f ? null : f),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSortRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          TextButton.icon(
            key: const ValueKey('library_sort'),
            onPressed: _showSortSheet,
            icon: const Icon(Icons.swap_vert_rounded, size: 18),
            label: Text(_sortLabels[_sort]!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          IconButton(
            key: const ValueKey('library_view_toggle'),
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
            tooltip: _grid ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Collection> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.crossAxisExtent >= 600 ? 5 : 3;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.6,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => LayoutBuilder(
              builder: (context, box) => ShelfCard(collection: items[i], width: box.maxWidth),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          const Text('No music found yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Allow access to your music, then pull down to scan again. Songs in an unusual place? Add that folder.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.spotifyLightGrey, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            onPressed: widget.onRescan,
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}
