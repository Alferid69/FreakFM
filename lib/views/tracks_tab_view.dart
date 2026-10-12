import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/track_list_tile.dart';

class TracksTabView extends StatefulWidget {
  final List<Song> songs;
  final String searchQuery;
  final VoidCallback onShuffleAll;
  final Future<void> Function()? onScanStorage;
  final VoidCallback? onAddFolder;

  const TracksTabView({
    super.key,
    required this.songs,
    required this.onShuffleAll,
    this.searchQuery = '',
    this.onScanStorage,
    this.onAddFolder,
  });

  @override
  State<TracksTabView> createState() => _TracksTabViewState();
}

class _TracksTabViewState extends State<TracksTabView> {
  final ScrollController _scroll = ScrollController();

  List<Song> get songs => widget.songs;
  bool get _isSearching => widget.searchQuery.isNotEmpty;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _play(List<Song> list, String source, {bool shuffle = false}) {
    if (list.isEmpty) return;
    final player = AudioPlayerService.instance;
    player.setShuffle(shuffle);
    final start = shuffle ? (List.of(list)..shuffle()).first : list.first;
    player.playSong(start, contextQueue: list, source: source);
  }

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _isSearching ? _buildNoResults() : _buildEmptyLibrary();
    }

    final player = AudioPlayerService.instance;
    final list = CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        if (!_isSearching) SliverToBoxAdapter(child: _buildQuickTiles()),
        SliverToBoxAdapter(child: _buildHeader()),
        ValueListenableBuilder<Song?>(
          valueListenable: player.currentSong,
          builder: (context, currentSong, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: player.isPlaying,
              builder: (context, isPlaying, _) {
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = songs[index];
                        return TrackListTile(
                          song: song,
                          index: index + 1,
                          isCurrent: currentSong?.id == song.id,
                          isPlaying: isPlaying,
                          onTap: () => player.playSong(
                            song,
                            contextQueue: songs,
                            source: _isSearching ? 'Search results' : 'All songs',
                          ),
                          onFavoriteToggle: () => LibraryService.instance.toggleFavorite(song),
                        );
                      },
                      childCount: songs.length,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );

    // Draggable thumb for jumping through large libraries; pull down to rescan.
    final scrollable = Scrollbar(
      controller: _scroll,
      interactive: true,
      thickness: 6,
      radius: const Radius.circular(3),
      child: list,
    );
    if (widget.onScanStorage == null || _isSearching) return scrollable;
    return RefreshIndicator(
      color: AppTheme.spotifyGreen,
      backgroundColor: AppTheme.spotifyCardElevated,
      onRefresh: widget.onScanStorage!,
      child: scrollable,
    );
  }

  Widget _buildQuickTiles() {
    final liked = songs.where((s) => s.isFavorite).toList();
    final mostPlayed = (songs.where((s) => s.playCount > 0).toList()
          ..sort((a, b) => b.playCount.compareTo(a.playCount)))
        .take(50)
        .toList();
    final recent = (List.of(songs)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded))).take(50).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 550;
          return GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: isWide ? 3.0 : 2.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _QuickTile(
                key: const ValueKey('quick_liked'),
                title: 'Liked Songs',
                subtitle: liked.isEmpty ? 'Tap ♥ on a song' : plural(liked.length, 'song'),
                icon: Icons.favorite_rounded,
                gradient: const [Color(0xFF450AF5), Color(0xFF8E8EE5)],
                onTap: liked.isEmpty ? null : () => _play(liked, 'Liked Songs'),
              ),
              _QuickTile(
                key: const ValueKey('quick_most_played'),
                title: 'Most Played',
                subtitle: mostPlayed.isEmpty ? 'Nothing yet' : plural(mostPlayed.length, 'song'),
                icon: Icons.trending_up_rounded,
                gradient: const [Color(0xFFAF2896), Color(0xFF509BF5)],
                onTap: mostPlayed.isEmpty ? null : () => _play(mostPlayed, 'Most Played'),
              ),
              _QuickTile(
                key: const ValueKey('quick_recent'),
                title: 'Recently Added',
                subtitle: plural(recent.length, 'song'),
                icon: Icons.schedule_rounded,
                gradient: const [Color(0xFF8D67AB), Color(0xFF1E3264)],
                onTap: () => _play(recent, 'Recently Added'),
              ),
              _QuickTile(
                key: const ValueKey('quick_shuffle'),
                title: 'Shuffle All',
                subtitle: plural(songs.length, 'song'),
                icon: Icons.shuffle_rounded,
                gradient: const [Color(0xFF1E3264), Color(0xFF1DB954)],
                onTap: widget.onShuffleAll,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final totalMs = songs.fold<int>(0, (sum, s) => sum + s.durationMs);
    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;
    final length = hours > 0 ? '$hours h $minutes min' : '$minutes min';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSearching ? 'Results' : 'All Songs',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${plural(songs.length, 'song')} • $length',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.spotifyLightGrey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('shuffle_all_button'),
            iconSize: 26,
            icon: const Icon(Icons.shuffle_rounded, color: AppTheme.spotifyLightGrey),
            tooltip: 'Shuffle',
            onPressed: () => _play(songs, _isSearching ? 'Search results' : 'All songs', shuffle: true),
          ),
          const SizedBox(width: 4),
          Material(
            color: AppTheme.spotifyGreen,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: AppTheme.spotifyGreen.withValues(alpha: 0.5),
            child: InkWell(
              key: const ValueKey('play_all_button'),
              customBorder: const CircleBorder(),
              onTap: () => _play(songs, _isSearching ? 'Search results' : 'All songs'),
              child: const SizedBox(
                width: 50,
                height: 50,
                child: Icon(Icons.play_arrow_rounded, color: Colors.black, size: 30, semanticLabel: 'Play all'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.spotifySubdued),
            const SizedBox(height: 14),
            Text(
              'No results for "${widget.searchQuery}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check the spelling, or search by artist, album, folder or genre.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppTheme.spotifyCard, shape: BoxShape.circle),
              child: const Icon(Icons.library_music_rounded, size: 36, color: AppTheme.spotifyGreen),
            ),
            const SizedBox(height: 18),
            const Text(
              'No music found yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.3),
            ),
            const SizedBox(height: 8),
            const Text(
              'freak player looks in your Music and Download folders. '
              'Keep songs somewhere else? Add that folder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey, height: 1.4),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (widget.onScanStorage != null)
                  ElevatedButton.icon(
                    onPressed: widget.onScanStorage,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Scan again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.spotifyGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                if (widget.onAddFolder != null)
                  OutlinedButton.icon(
                    onPressed: widget.onAddFolder,
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('Add folder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.borderMedium),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _QuickTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.spotifyCardHighlight,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Row(
            children: [
              Container(
                width: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.spotifyLightGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
