import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'song_artwork_widget.dart';
import 'song_options_sheet.dart';
import 'waveform_visualizer.dart';

/// Spotify-style song row: cover, title (green while playing), artist,
/// a like toggle (+ / green tick) and the ⋮ menu. Long-press opens the menu.
class TrackListTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final int? index;
  final bool showArtwork;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onMoreOptions;

  const TrackListTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    this.index,
    this.showArtwork = true,
    this.subtitle,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    final online = song.isOnline;
    final openMenu = onMoreOptions ?? () => showSongOptions(context, song);

    return InkWell(
      key: ValueKey('track_${song.id}'),
      onTap: onTap,
      onLongPress: online ? null : openMenu,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, showArtwork ? 6 : 8, 4, showArtwork ? 6 : 8),
        child: Row(
          children: [
            if (showArtwork) ...[
              SongArtworkWidget(song: song, size: 48, borderRadius: 2, showPlayingBadge: false),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCurrent && isPlaying) ...[
                        const WaveformVisualizer(isPlaying: true, barCount: 3, height: 11, barWidth: 2.2),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isCurrent ? AppTheme.spotifyGreen : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ?? song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: AppTheme.spotifyLightGrey),
                  ),
                ],
              ),
            ),
            if (online)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.cloud_queue_rounded, size: 20, color: AppTheme.spotifyLightGrey),
              )
            else ...[
            IconButton(
              key: ValueKey('favorite_${song.id}'),
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                song.isFavorite ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                color: song.isFavorite ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey,
              ),
              onPressed: onFavoriteToggle,
              tooltip: song.isFavorite ? 'Remove from Liked Songs' : 'Save to Liked Songs',
            ),
            IconButton(
              key: ValueKey('more_${song.id}'),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.spotifyLightGrey),
              tooltip: 'More options',
              onPressed: openMenu,
            ),
            ],
          ],
        ),
      ),
    );
  }
}
