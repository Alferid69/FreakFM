import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_artwork_widget.dart';
import '../widgets/track_list_tile.dart';

class AlbumsTabView extends StatefulWidget {
  final List<Song> songs;
  final VoidCallback onSongsChanged;

  const AlbumsTabView({
    super.key,
    required this.songs,
    required this.onSongsChanged,
  });

  @override
  State<AlbumsTabView> createState() => _AlbumsTabViewState();
}

class _AlbumsTabViewState extends State<AlbumsTabView> {
  String? _selectedAlbum;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Song>> albumMap = {};
    for (final song in widget.songs) {
      albumMap.putIfAbsent(song.album, () => []).add(song);
    }

    final albumGroups = albumMap.entries.map((entry) {
      return AlbumGroup(
        albumName: entry.key,
        artistName: entry.value.first.artist,
        songs: entry.value,
        year: entry.value.first.year,
      );
    }).toList()
      ..sort((a, b) => a.albumName.compareTo(b.albumName));

    if (_selectedAlbum != null && albumMap.containsKey(_selectedAlbum)) {
      final albumSongs = albumMap[_selectedAlbum]!;
      return _buildAlbumTracksView(_selectedAlbum!, albumSongs);
    }

    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: albumGroups.length,
      itemBuilder: (context, index) {
        final group = albumGroups[index];

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: AppTheme.softShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedAlbum = group.albumName;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vinyl Sleeve Art
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SongArtworkWidget(
                            song: group.songs.first,
                            size: double.infinity,
                            borderRadius: 8,
                            showPlayingBadge: false,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${group.trackCount} trk',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.spotifyLightGrey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Album & Artist Name
                    Text(
                      group.albumName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumTracksView(String albumName, List<Song> albumSongs) {
    final player = AudioPlayerService.instance;
    final artistName = albumSongs.first.artist;
    final year = albumSongs.first.year;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.bgSurface,
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => setState(() => _selectedAlbum = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      albumName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '$artistName • ${year ?? "Classic"} • ${albumSongs.length} tracks',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  player.playSong(albumSongs.first, contextQueue: albumSongs);
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play Album'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: const Color(0xFF1B1713),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<Song?>(
            valueListenable: player.currentSong,
            builder: (context, currentSong, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: player.isPlaying,
                builder: (context, isPlaying, _) {
                  return ListView.builder(
                    itemCount: albumSongs.length,
                    padding: const EdgeInsets.only(bottom: 90),
                    itemBuilder: (context, index) {
                      final song = albumSongs[index];
                      final isCurrent = currentSong?.id == song.id;

                      return TrackListTile(
                        song: song,
                        index: index + 1,
                        isCurrent: isCurrent,
                        isPlaying: isPlaying,
                        onTap: () => player.playSong(song, contextQueue: albumSongs),
                        onFavoriteToggle: () {
                          song.isFavorite = !song.isFavorite;
                          widget.onSongsChanged();
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
