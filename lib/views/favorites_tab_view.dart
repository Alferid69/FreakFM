import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_list_tile.dart';

class FavoritesTabView extends StatelessWidget {
  final List<Song> songs;
  final VoidCallback onSongsChanged;

  const FavoritesTabView({
    super.key,
    required this.songs,
    required this.onSongsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final favorites = songs.where((s) => s.isFavorite).toList();
    final mostPlayed = List<Song>.from(songs)..sort((a, b) => b.playCount.compareTo(a.playCount));
    final topPlayed = mostPlayed.take(20).where((s) => s.playCount > 0).toList();

    final player = AudioPlayerService.instance;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub-tabs for Favorites vs Most Played
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppTheme.accentAmber,
                  borderRadius: BorderRadius.circular(9),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF1B1713),
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                tabs: [
                  Tab(text: 'Favorites (${favorites.length})'),
                  Tab(text: 'Most Played (${topPlayed.length})'),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [
                // Favorites List
                favorites.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'No Favorites Yet',
                        subtitle: 'Tap the heart icon on any song to add it here.',
                      )
                    : ValueListenableBuilder<Song?>(
                        valueListenable: player.currentSong,
                        builder: (context, currentSong, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: player.isPlaying,
                            builder: (context, isPlaying, _) {
                              return ListView.builder(
                                itemCount: favorites.length,
                                padding: const EdgeInsets.only(bottom: 90),
                                itemBuilder: (context, index) {
                                  final song = favorites[index];
                                  final isCurrent = currentSong?.id == song.id;

                                  return TrackListTile(
                                    song: song,
                                    index: index + 1,
                                    isCurrent: isCurrent,
                                    isPlaying: isPlaying,
                                    onTap: () => player.playSong(song, contextQueue: favorites),
                                    onFavoriteToggle: () {
                                      song.isFavorite = !song.isFavorite;
                                      onSongsChanged();
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                // Most Played List
                topPlayed.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.graphic_eq_rounded,
                        title: 'No Play History',
                        subtitle: 'Play songs to automatically track your top tracks.',
                      )
                    : ValueListenableBuilder<Song?>(
                        valueListenable: player.currentSong,
                        builder: (context, currentSong, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: player.isPlaying,
                            builder: (context, isPlaying, _) {
                              return ListView.builder(
                                itemCount: topPlayed.length,
                                padding: const EdgeInsets.only(bottom: 90),
                                itemBuilder: (context, index) {
                                  final song = topPlayed[index];
                                  final isCurrent = currentSong?.id == song.id;

                                  return TrackListTile(
                                    song: song,
                                    index: index + 1,
                                    isCurrent: isCurrent,
                                    isPlaying: isPlaying,
                                    onTap: () => player.playSong(song, contextQueue: topPlayed),
                                    onFavoriteToggle: () {
                                      song.isFavorite = !song.isFavorite;
                                      onSongsChanged();
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
