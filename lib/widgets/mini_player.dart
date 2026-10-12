import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import 'full_player_sheet.dart';
import 'lyrics_view.dart';
import 'song_artwork_widget.dart';
import 'volume_controller.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  int _selectedTab = 0; // 0 = Player, 1 = Lyrics

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;

    // Position ticks several times a second, so only the progress bar and the
    // time label listen to it; the rest rebuilds on song/play-state changes.
    return ValueListenableBuilder<Song?>(
      valueListenable: player.currentSong,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: player.isPlaying,
          builder: (context, isPlaying, _) {
            return ValueListenableBuilder<int>(
              valueListenable: LibraryService.instance.revision,
              builder: (context, _, _) {
                return AnimatedContainer(
                  key: const ValueKey('mini_player'),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: _selectedTab == 1 ? 280 : null,
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.spotifyCardElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E2E2E), width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedTab == 0)
                          _buildPlayerContent(context, song, isPlaying, player)
                        else ...[
                          _buildMiniTabBar(context, song),
                          Expanded(
                            child: _buildLyricsContent(context, song, isPlaying, player),
                          ),
                        ],
                        _MiniProgressBar(song: song),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildArtwork(Song song, bool isPlaying) {
    return SongArtworkWidget(
      song: song,
      size: 42,
      borderRadius: 4,
      isPlaying: isPlaying,
    );
  }

  Widget _buildMiniTabBar(BuildContext context, Song song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // Player Tab Pill
          _buildTabPill(
            index: 0,
            icon: Icons.music_note_rounded,
            label: 'Player',
            isSelected: _selectedTab == 0,
          ),
          const SizedBox(width: 6),

          // Lyrics Tab Pill
          _buildTabPill(
            index: 1,
            icon: Icons.lyrics_rounded,
            label: 'Lyrics',
            isSelected: _selectedTab == 1,
          ),

          const Spacer(),

          // In lyrics tab, show track snippet
          if (_selectedTab == 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${song.title} • ${song.artist}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.spotifyLightGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Volume Quick Control
          const VolumeControllerWidget(
            mode: VolumeDisplayMode.popup,
          ),
          const SizedBox(width: 4),

          // Close / Return to Player
          IconButton(
            iconSize: 18,
            splashRadius: 18,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.close_rounded, color: AppTheme.spotifyLightGrey),
            tooltip: 'Return to player',
            onPressed: () => setState(() => _selectedTab = 0),
          ),

          // Full Player Expand Icon
          IconButton(
            iconSize: 17,
            splashRadius: 18,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(Icons.open_in_full_rounded, color: AppTheme.spotifyLightGrey),
            tooltip: 'Expand full player',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => FullPlayerSheet(initialTab: _selectedTab),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.spotifyGreen
              : AppTheme.spotifyCardHighlight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.spotifyDeepBlack : AppTheme.spotifyLightGrey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.spotifyDeepBlack : AppTheme.spotifyLightGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent(
    BuildContext context,
    Song song,
    bool isPlaying,
    AudioPlayerService player,
  ) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const FullPlayerSheet(initialTab: 0),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            // Square Spotify Album Art
            _buildArtwork(song, isPlaying),
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.spotifyWhite,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.spotifyLightGrey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // Lyrics Quick Button
            IconButton(
              iconSize: 20,
              splashRadius: 20,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(
                Icons.lyrics_rounded,
                color: AppTheme.spotifyLightGrey,
              ),
              tooltip: 'Lyrics',
              onPressed: () {
                setState(() => _selectedTab = 1);
              },
            ),

            // Favorite Toggle
            IconButton(
              iconSize: 22,
              splashRadius: 20,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                song.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: song.isFavorite
                    ? AppTheme.spotifyGreen
                    : AppTheme.spotifyLightGrey,
              ),
              onPressed: () {
                LibraryService.instance.toggleFavorite(song);
              },
            ),

            // Play / Pause
            IconButton(
              iconSize: 32,
              splashRadius: 22,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: AppTheme.spotifyWhite,
              ),
              onPressed: () => player.togglePlayPause(),
            ),

            // Skip Next
            IconButton(
              iconSize: 26,
              splashRadius: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: const Icon(
                Icons.skip_next_rounded,
                color: AppTheme.spotifyWhite,
              ),
              onPressed: () => player.next(),
            ),

            // Responsive Volume Controller
            Builder(
              builder: (ctx) {
                final isWide = MediaQuery.of(ctx).size.width >= 640;
                if (!isWide) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: VolumeControllerWidget(
                    mode: VolumeDisplayMode.popup,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsContent(
    BuildContext context,
    Song song,
    bool isPlaying,
    AudioPlayerService player,
  ) {
    return Column(
      children: [
        // Lyrics View Body
        Expanded(
          child: LyricsView(
            song: song,
            isCompact: true,
            onOpenFullPlayer: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const FullPlayerSheet(initialTab: 1),
              );
            },
          ),
        ),

        // Bottom Mini Scrubber & Playback Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(
              top: BorderSide(color: Color(0xFF2A2A2A), width: 0.8),
            ),
          ),
          child: Row(
            children: [
              // Previous
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.skip_previous_rounded,
                    color: AppTheme.spotifyLightGrey),
                onPressed: () => player.previous(),
              ),
              const SizedBox(width: 6),

              // Play / Pause
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppTheme.spotifyGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppTheme.spotifyDeepBlack,
                  ),
                  onPressed: () => player.togglePlayPause(),
                ),
              ),
              const SizedBox(width: 6),

              // Next
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.skip_next_rounded,
                    color: AppTheme.spotifyLightGrey),
                onPressed: () => player.next(),
              ),
              const SizedBox(width: 10),

              // Position / Total Time Label
              _PositionLabel(song: song, format: _formatDuration),
              const Spacer(),

              // Volume Controller
              const VolumeControllerWidget(
                mode: VolumeDisplayMode.popup,
              ),
              const SizedBox(width: 4),

              // Favorite
              IconButton(
                iconSize: 19,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  song.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: song.isFavorite
                      ? AppTheme.spotifyGreen
                      : AppTheme.spotifyLightGrey,
                ),
                onPressed: () {
                  LibraryService.instance.toggleFavorite(song);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpinningVinylWidget extends StatefulWidget {
  final bool isPlaying;

  const _SpinningVinylWidget({required this.isPlaying});

  @override
  State<_SpinningVinylWidget> createState() => _SpinningVinylWidgetState();
}

class _SpinningVinylWidgetState extends State<_SpinningVinylWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SpinningVinylWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotationController,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppTheme.accentAmberLight.withValues(alpha: 0.5), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.album_rounded,
              size: 42,
              color: AppTheme.borderFocus,
            ),
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppTheme.accentAmber,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 4,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.bgObsidian,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listens to playback position on its own so the rest of the mini player
/// doesn't rebuild on every tick.
class _PositionListener extends StatelessWidget {
  final Song song;
  final Widget Function(BuildContext context, Duration position, int totalMs) builder;

  const _PositionListener({required this.song, required this.builder});

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return ValueListenableBuilder<Duration>(
      valueListenable: player.duration,
      builder: (context, totalDur, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: player.position,
          builder: (context, position, _) {
            final rawTotalMs = totalDur.inMilliseconds > 0
                ? totalDur.inMilliseconds
                : (song.durationMs > 0 ? song.durationMs : 1);
            final totalMs = rawTotalMs > position.inMilliseconds ? rawTotalMs : position.inMilliseconds;
            return builder(context, position, totalMs);
          },
        );
      },
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  final Song song;
  const _MiniProgressBar({required this.song});

  @override
  Widget build(BuildContext context) {
    return _PositionListener(
      song: song,
      builder: (context, position, totalMs) => LinearProgressIndicator(
        value: (position.inMilliseconds / totalMs).clamp(0.0, 1.0),
        minHeight: 2.2,
        backgroundColor: const Color(0xFF383838),
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.spotifyGreen),
      ),
    );
  }
}

class _PositionLabel extends StatelessWidget {
  final Song song;
  final String Function(Duration) format;
  const _PositionLabel({required this.song, required this.format});

  @override
  Widget build(BuildContext context) {
    return _PositionListener(
      song: song,
      builder: (context, position, totalMs) => Text(
        '${format(position)} / ${format(Duration(milliseconds: totalMs))}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: AppTheme.spotifyLightGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
