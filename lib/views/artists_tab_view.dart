import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/detail_back_handler.dart';
import '../widgets/track_list_tile.dart';

class ArtistsTabView extends StatefulWidget {
  final List<Song> songs;

  const ArtistsTabView({
    super.key,
    required this.songs,
  });

  @override
  State<ArtistsTabView> createState() => _ArtistsTabViewState();
}

class _ArtistsTabViewState extends State<ArtistsTabView> {
  String? _selectedArtist;

  void _openDetail(String value) {
    setState(() => _selectedArtist = value);
    DetailBackHandler.register('artists', _closeDetail);
  }

  void _closeDetail() {
    DetailBackHandler.unregister('artists');
    if (mounted) _closeDetail();
  }

  @override
  void dispose() {
    DetailBackHandler.unregister('artists');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Song>> artistMap = {};
    for (final song in widget.songs) {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }

    final artistGroups = artistMap.entries.map((entry) {
      return ArtistGroup(
        artistName: entry.key,
        songs: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.artistName.compareTo(b.artistName));

    if (_selectedArtist != null && artistMap.containsKey(_selectedArtist)) {
      final artistSongs = artistMap[_selectedArtist]!;
      return _buildArtistSongsView(_selectedArtist!, artistSongs);
    }

    return ListView.builder(
      itemCount: artistGroups.length,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final group = artistGroups[index];
        final initials = group.artistName.isNotEmpty
            ? group.artistName.trim().substring(0, 1).toUpperCase()
            : '?';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppTheme.bgSurface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.borderSubtle),
            ),
            child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF1B202D),
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppTheme.accentAmber, width: 1.5),
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentAmberLight,
                  ),
                ),
              ),
            ),
            title: Text(
              group.artistName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            subtitle: Text(
              '${plural(group.trackCount, 'song')} • ${plural(group.albums.length, 'album')}',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onTap: () {
              _openDetail(group.artistName);
            },
          ),
          ),
        );
      },
    );
  }

  Widget _buildArtistSongsView(String artistName, List<Song> artistSongs) {
    final player = AudioPlayerService.instance;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.bgSurface,
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => _closeDetail(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      plural(artistSongs.length, 'song'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  player.playSong(artistSongs.first, contextQueue: artistSongs, source: 'Artist • $artistName');
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play All'),
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
                    itemCount: artistSongs.length,
                    padding: const EdgeInsets.only(bottom: 90),
                    itemBuilder: (context, index) {
                      final song = artistSongs[index];
                      final isCurrent = currentSong?.id == song.id;

                      return TrackListTile(
                        song: song,
                        index: index + 1,
                        isCurrent: isCurrent,
                        isPlaying: isPlaying,
                        onTap: () => player.playSong(song, contextQueue: artistSongs, source: 'Artist • $artistName'),
                        onFavoriteToggle: () {
                          LibraryService.instance.toggleFavorite(song);
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
