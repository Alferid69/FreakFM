import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_list_tile.dart';

class GenresTabView extends StatefulWidget {
  final List<Song> songs;
  final VoidCallback onSongsChanged;

  const GenresTabView({
    super.key,
    required this.songs,
    required this.onSongsChanged,
  });

  @override
  State<GenresTabView> createState() => _GenresTabViewState();
}

class _GenresTabViewState extends State<GenresTabView> {
  String? _selectedGenre;

  final Map<String, IconData> _genreIcons = {
    'Hip-Hop / Rap': Icons.spatial_audio_rounded,
    'Pop': Icons.star_rounded,
    'Dance & Electronic': Icons.bolt_rounded,
    'Pop / Reggae': Icons.beach_access_rounded,
    'R&B': Icons.favorite_rounded,
    'Voice Recordings': Icons.mic_rounded,
    'Ethiopian / Reggae': Icons.flare_rounded,
    'Quran / Recitation': Icons.auto_stories_rounded,
    'Electronic': Icons.electric_bolt_rounded,
    'Rock': Icons.equalizer_rounded,
    'R&B / Soul': Icons.favorite_rounded,
    'Hip-Hop': Icons.spatial_audio_off_rounded,
    'Jazz': Icons.nightlife_rounded,
    'Synthwave': Icons.blur_on_rounded,
    'Ambient': Icons.cloud_queue_rounded,
    'Alternative': Icons.waves_rounded,
    'Funk': Icons.music_note_rounded,
    'Classical': Icons.piano_rounded,
    'Indie': Icons.audiotrack_rounded,
    'Lo-Fi': Icons.radio_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Song>> genreMap = {};
    for (final song in widget.songs) {
      genreMap.putIfAbsent(song.genre, () => []).add(song);
    }

    final genreGroups = genreMap.entries.map((entry) {
      return GenreGroup(
        genreName: entry.key,
        songs: entry.value,
      );
    }).toList()
      ..sort((a, b) => b.trackCount.compareTo(a.trackCount));

    if (_selectedGenre != null && genreMap.containsKey(_selectedGenre)) {
      final genreSongs = genreMap[_selectedGenre]!;
      return _buildGenreSongsView(_selectedGenre!, genreSongs);
    }

    return ListView.builder(
      itemCount: genreGroups.length,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final group = genreGroups[index];
        final icon = _genreIcons[group.genreName] ?? Icons.music_note_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderMedium),
              ),
              child: Center(
                child: Icon(icon, color: AppTheme.accentAmber, size: 22),
              ),
            ),
            title: Text(
              group.genreName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              '${group.trackCount} tracks in catalog',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accentAmber, size: 34),
              onPressed: () {
                AudioPlayerService.instance.playSong(group.songs.first, contextQueue: group.songs);
              },
            ),
            onTap: () {
              setState(() {
                _selectedGenre = group.genreName;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildGenreSongsView(String genreName, List<Song> genreSongs) {
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
                onPressed: () => setState(() => _selectedGenre = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      genreName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${genreSongs.length} tracks in genre',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  player.playSong(genreSongs.first, contextQueue: genreSongs);
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play Genre'),
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
                    itemCount: genreSongs.length,
                    padding: const EdgeInsets.only(bottom: 90),
                    itemBuilder: (context, index) {
                      final song = genreSongs[index];
                      final isCurrent = currentSong?.id == song.id;

                      return TrackListTile(
                        song: song,
                        index: index + 1,
                        isCurrent: isCurrent,
                        isPlaying: isPlaying,
                        onTap: () => player.playSong(song, contextQueue: genreSongs),
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
