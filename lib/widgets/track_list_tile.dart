import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'song_artwork_widget.dart';
import 'waveform_visualizer.dart';

class TrackListTile extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final int? index;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onMoreOptions;

  const TrackListTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    this.index,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.spotifyCardHighlight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('track_${song.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppTheme.spotifyCardHighlight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Track Index or Spotify Playing Visualizer
                SizedBox(
                  width: 28,
                  child: Center(
                    child: isCurrent
                        ? WaveformVisualizer(
                            isPlaying: isPlaying,
                            height: 14,
                            barWidth: 2.5,
                            barCount: 3,
                          )
                        : Text(
                            index != null ? '$index' : '•',
                            style: const TextStyle(
                              color: AppTheme.spotifySubdued,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),

                // Spotify Square Album Cover (46x46) with song's real artwork
                SongArtworkWidget(
                  song: song,
                  size: 46,
                  borderRadius: 4,
                  isPlaying: isCurrent && isPlaying,
                ),
                const SizedBox(width: 12),

                // Title & Artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? AppTheme.spotifyGreen
                              : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${song.artist} • ${song.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.spotifyLightGrey,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (song.filePath.endsWith('.flac')) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.spotifyCardElevated,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'LOSSLESS',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.spotifySubdued,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Duration
                Text(
                  song.formattedDuration,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isCurrent ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey,
                  ),
                ),
                const SizedBox(width: 4),

                // Spotify Heart Button
                IconButton(
                  key: ValueKey('favorite_${song.id}'),
                  iconSize: 20,
                  splashRadius: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: song.isFavorite ? AppTheme.spotifyGreen : AppTheme.spotifySubdued,
                  ),
                  onPressed: onFavoriteToggle,
                  tooltip: song.isFavorite ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                ),

                // More Menu Button
                if (onMoreOptions != null)
                  IconButton(
                    iconSize: 18,
                    splashRadius: 18,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.spotifyLightGrey),
                    onPressed: onMoreOptions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
