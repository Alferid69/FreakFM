import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_list_tile.dart';

class TracksTabView extends StatelessWidget {
  final List<Song> songs;
  final VoidCallback onSongsChanged;
  final VoidCallback onShuffleAll;
  final VoidCallback? onScanStorage;
  final VoidCallback? onAddFolder;

  const TracksTabView({
    super.key,
    required this.songs,
    required this.onSongsChanged,
    required this.onShuffleAll,
    this.onScanStorage,
    this.onAddFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.spotifyCard,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.music_note_rounded, size: 36, color: AppTheme.spotifyGreen),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Your Library is Empty',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan your storage to index your personal music collection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onScanStorage != null)
                    ElevatedButton.icon(
                      onPressed: onScanStorage,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Scan Storage'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.spotifyGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  if (onAddFolder != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onAddFolder,
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('Add Folder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.borderMedium),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    final player = AudioPlayerService.instance;
    final likedCount = songs.where((s) => s.isFavorite).length;

    // Derived top artists & albums for Spotify quick access tiles
    final topArtist = songs.isNotEmpty ? songs.first.artist : 'Favorites';
    final topAlbum = songs.isNotEmpty ? songs.first.album : 'Music';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Spotify Quick Access 2-Column Grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    // Tile 1: Liked Songs (Iconic Spotify Gradient Heart)
                    _buildQuickTile(
                      title: 'Liked Songs',
                      subtitle: '$likedCount songs',
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF450AF5), Color(0xFF8E8EE5)],
                          ),
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
                      ),
                      onTap: () {
                        final favs = songs.where((s) => s.isFavorite).toList();
                        if (favs.isNotEmpty) {
                          player.playSong(favs.first, contextQueue: favs);
                        } else {
                          onShuffleAll();
                        }
                      },
                    ),

                    // Tile 2: Top Artist
                    _buildQuickTile(
                      title: topArtist,
                      subtitle: 'Artist',
                      leading: Container(
                        width: 56,
                        height: 56,
                        color: AppTheme.spotifyCardHighlight,
                        child: const Icon(Icons.person_rounded, color: AppTheme.spotifyGreen, size: 24),
                      ),
                      onTap: () {
                        final artistSongs = songs.where((s) => s.artist == topArtist).toList();
                        if (artistSongs.isNotEmpty) {
                          player.playSong(artistSongs.first, contextQueue: artistSongs);
                        }
                      },
                    ),

                    // Tile 3: Top Album
                    _buildQuickTile(
                      title: topAlbum,
                      subtitle: 'Album',
                      leading: Container(
                        width: 56,
                        height: 56,
                        color: AppTheme.spotifyCardHighlight,
                        child: const Icon(Icons.album_rounded, color: AppTheme.spotifyLightGrey, size: 24),
                      ),
                      onTap: () {
                        final albumSongs = songs.where((s) => s.album == topAlbum).toList();
                        if (albumSongs.isNotEmpty) {
                          player.playSong(albumSongs.first, contextQueue: albumSongs);
                        }
                      },
                    ),

                    // Tile 4: Library Mix / Shuffle All
                    _buildQuickTile(
                      title: 'Library Mix',
                      subtitle: '${songs.length} tracks',
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E3264), Color(0xFF1DB954)],
                          ),
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                        ),
                        child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 22),
                      ),
                      onTap: onShuffleAll,
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Spotify Action Header (Track count + Giant Circular Spotify Green Shuffle Button)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'All Songs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${songs.length} tracks in collection',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.spotifyLightGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Spotify Iconic Green Play / Shuffle Circle (50x50)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.spotifyGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.spotifyGreen.withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onShuffleAll,
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: Icon(
                          Icons.shuffle_rounded,
                          color: Color(0xFF000000),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Virtualized Track List
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
                        final isCurrent = currentSong?.id == song.id;

                        return TrackListTile(
                          song: song,
                          index: index + 1,
                          isCurrent: isCurrent,
                          isPlaying: isPlaying,
                          onTap: () {
                            player.playSong(song, contextQueue: songs);
                          },
                          onFavoriteToggle: () {
                            song.isFavorite = !song.isFavorite;
                            onSongsChanged();
                          },
                          onMoreOptions: () {
                            _showTrackDetailsModal(context, song);
                          },
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
  }

  Widget _buildQuickTile({
    required String title,
    required String subtitle,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.spotifyCardHighlight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.spotifyLightGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackDetailsModal(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.spotifyCardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.spotifySubdued,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                song.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${song.artist} • ${song.album}',
                style: const TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open_rounded, color: AppTheme.spotifyGreen),
                title: const Text('Folder', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text(song.folder, style: const TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 12)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.waves_rounded, color: AppTheme.spotifyGreen),
                title: const Text('Genre', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text(song.genre, style: const TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 12)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded, color: AppTheme.spotifyGreen),
                title: const Text('Audio Quality & Size', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text(
                  '${song.qualityBadge} • ${song.formattedFileSize}',
                  style: const TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
