import 'dart:math';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/lyrics_model.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'equalizer_dialog.dart';
import 'lyrics_view.dart';
import 'song_artwork_widget.dart';
import 'volume_controller.dart';
import 'waveform_visualizer.dart';

class FullPlayerSheet extends StatefulWidget {
  final int initialTab;
  const FullPlayerSheet({super.key, this.initialTab = 0});

  @override
  State<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends State<FullPlayerSheet>
    with SingleTickerProviderStateMixin {
  final player = AudioPlayerService.instance;
  late AnimationController _turntableController;
  late int _selectedTab;
  bool _showVinyl = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    if (player.isPlaying.value) {
      _turntableController.repeat();
    }
  }

  @override
  void dispose() {
    _turntableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Song?>(
      valueListenable: player.currentSong,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: player.isPlaying,
          builder: (context, isPlaying, _) {
            if (isPlaying) {
              if (!_turntableController.isAnimating) {
                _turntableController.repeat();
              }
            } else {
              _turntableController.stop();
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.94,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF383838),
                    Color(0xFF1E1E1E),
                    Color(0xFF121212),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 32,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top Drag Handle & Bar
                    _buildTopHeader(context),

                    // Player Mode Tabs (Now Playing vs Lyrics)
                    _buildPlayerTabs(),

                    Expanded(
                      child: _selectedTab == 0
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  const SizedBox(height: 12),

                                  // Hero Album Artwork (with Turntable toggle)
                                  _buildHeroArtwork(song, isPlaying),
                                  const SizedBox(height: 24),

                                  // Song Metadata & Hi-Res Badge
                                  _buildSongInfo(song),
                                  const SizedBox(height: 12),

                                  // Audio Progress Scrubber
                                  _buildProgressScrubber(song),
                                  const SizedBox(height: 4),

                                  // Main Playback Controls
                                  _buildPlaybackControls(),
                                  const SizedBox(height: 4),

                                  // Seek / speed / EQ (+ volume on desktop)
                                  _buildExtrasRow(context),
                                  const SizedBox(height: 20),

                                  // Spotify Synced Lyrics Preview Card
                                  _buildLyricsPreviewCard(song),
                                  const SizedBox(height: 36),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Song metadata chip in lyrics mode
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${song.artist} • ${song.album}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          song.isFavorite
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: song.isFavorite
                                              ? AppTheme.accentAmber
                                              : AppTheme.textMuted,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            player.toggleCurrentFavorite();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // Live lyrics viewer
                                Expanded(
                                  child: LyricsView(
                                    song: song,
                                    isCompact: false,
                                  ),
                                ),

                                // Bottom scrubber & playback controls
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                       _buildProgressScrubber(song),
                                       _buildPlaybackControls(),
                                       if (isDesktopPlatform) ...[
                                         const SizedBox(height: 8),
                                         const Center(
                                           child: VolumeControllerWidget(
                                             mode: VolumeDisplayMode.inline,
                                             sliderWidth: 150,
                                             showPercentage: true,
                                           ),
                                         ),
                                       ],
                                       const SizedBox(height: 12),
                                     ],
                                   ),
                                 ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            iconSize: 28,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.spotifyWhite),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Minimize player',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PLAYING FROM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppTheme.spotifyLightGrey,
                  ),
                ),
                const SizedBox(height: 2),
                ValueListenableBuilder<String>(
                  valueListenable: player.playingFrom,
                  builder: (context, source, _) => Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.spotifyWhite,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int?>(
                valueListenable: player.sleepTimerRemainingMinutes,
                builder: (context, remaining, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: player.sleepAtEndOfTrack,
                    builder: (context, endOfTrack, _) {
                      final isActive = remaining != null || endOfTrack;
                      return IconButton(
                        iconSize: 20,
                        icon: Icon(
                          isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                          color: isActive ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey,
                        ),
                        onPressed: () => _showSleepTimerModal(context),
                        tooltip: isActive
                            ? (endOfTrack ? 'Sleep: End of Track' : 'Sleep in ${remaining}m')
                            : 'Set Sleep Timer',
                      );
                    },
                  );
                },
              ),
              IconButton(
                iconSize: 22,
                icon: const Icon(Icons.queue_music_rounded, color: AppTheme.spotifyWhite),
                onPressed: () => _showQueueModal(context),
                tooltip: 'View playback queue',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.spotifyCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildFullTabButton(
                index: 0,
                icon: Icons.album_rounded,
                label: 'Now Playing',
                isSelected: _selectedTab == 0,
              ),
            ),
            Expanded(
              child: _buildFullTabButton(
                index: 1,
                icon: Icons.lyrics_rounded,
                label: 'Lyrics',
                isSelected: _selectedTab == 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullTabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.spotifyGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppTheme.spotifyDeepBlack : AppTheme.spotifyLightGrey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.spotifyDeepBlack : AppTheme.spotifyLightGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroArtwork(Song song, bool isPlaying) {
    final screenWidth = MediaQuery.of(context).size.width;
    final size = min(screenWidth - 48, 300.0);

    return Center(
      child: Stack(
        children: [
          if (!_showVinyl)
            // Spotify Hero Square Album Cover with Song's Real Artwork
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    offset: const Offset(0, 16),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SongArtworkWidget(
                song: song,
                size: size,
                borderRadius: 8,
                isPlaying: isPlaying,
                showPlayingBadge: false,
                fit: BoxFit.cover,
                fallback: _buildHeroFallback(song, isPlaying, size),
              ),
            )
          else
            _buildVinylTurntable(song, isPlaying),

          // Corner Mode Toggle between Album Art & Turntable
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  _showVinyl ? Icons.crop_square_rounded : Icons.radio_button_checked_rounded,
                  color: AppTheme.spotifyLightGrey,
                ),
                tooltip: _showVinyl ? 'Show Album Cover' : 'Show Turntable',
                onPressed: () {
                  setState(() {
                    _showVinyl = !_showVinyl;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFallback(Song song, bool isPlaying, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E3338),
                  Color(0xFF1E2124),
                  Color(0xFF121212),
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppTheme.spotifyCardHighlight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPlaying
                        ? AppTheme.spotifyGreen.withValues(alpha: 0.6)
                        : const Color(0xFF383838),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.album_rounded,
                    size: 50,
                    color: isPlaying ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  song.album.isNotEmpty ? song.album : 'Unknown Album',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.spotifyWhite,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  song.artist,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.spotifyLightGrey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVinylTurntable(Song song, bool isPlaying) {
    final size = min(MediaQuery.of(context).size.width - 64, 280.0);

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF11141A),
          border: Border.all(
            color: isPlaying ? AppTheme.spotifyGreen.withValues(alpha: 0.6) : AppTheme.borderMedium,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.spotifyGreen.withValues(alpha: isPlaying ? 0.15 : 0.05),
              offset: const Offset(0, 10),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: RotationTransition(
          turns: _turntableController,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vinyl Concentric Grooves
              for (double r = 0.85; r >= 0.45; r -= 0.1)
                FractionallySizedBox(
                  widthFactor: r,
                  heightFactor: r,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E232E).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                  ),
                ),

              // Center Label Disc
              FractionallySizedBox(
                widthFactor: 0.38,
                heightFactor: 0.38,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF2AE86B),
                        AppTheme.spotifyGreen,
                        Color(0xFF15803D),
                      ],
                    ),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 28,
                      color: AppTheme.spotifyDeepBlack,
                    ),
                  ),
                ),
              ),

              // Spindle Hole
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppTheme.spotifyBlack,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.spotifyWhite,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${song.artist} • ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.spotifyLightGrey,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.spotifyCardHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        song.qualityBadge,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.spotifyLightGrey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 28,
            padding: const EdgeInsets.all(8),
            icon: Icon(
              song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: song.isFavorite ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey,
            ),
            onPressed: () {
              setState(() {
                player.toggleCurrentFavorite();
              });
            },
            tooltip: song.isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressScrubber(Song song) => _ProgressScrubber(song: song);

  Widget _buildPlaybackControls() {
    return Column(
      children: [
        // Primary Playback Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Shuffle Button
            ValueListenableBuilder<bool>(
              valueListenable: player.isShuffle,
              builder: (context, shuffle, _) {
                return IconButton(
                  iconSize: 24,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: shuffle ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey,
                  ),
                  onPressed: () => player.toggleShuffle(),
                  tooltip: shuffle ? 'Shuffle ON (Random Play)' : 'Shuffle OFF (Sequential Play)',
                );
              },
            ),

            // Previous Button
            IconButton(
              iconSize: 38,
              icon: const Icon(Icons.skip_previous_rounded, color: AppTheme.spotifyWhite),
              onPressed: () => player.previous(),
              tooltip: 'Previous Track',
            ),

            // Play / Pause Primary Button (Iconic 64x64 Solid White Circle)
            ValueListenableBuilder<bool>(
              valueListenable: player.isPlaying,
              builder: (context, isPlaying, _) {
                return Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppTheme.spotifyWhite,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        offset: Offset(0, 4),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: IconButton(
                    iconSize: 36,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppTheme.spotifyDeepBlack,
                    ),
                    onPressed: () => player.togglePlayPause(),
                    tooltip: isPlaying ? 'Pause' : 'Play',
                  ),
                );
              },
            ),

            // Next Button
            IconButton(
              iconSize: 38,
              icon: const Icon(Icons.skip_next_rounded, color: AppTheme.spotifyWhite),
              onPressed: () => player.next(),
              tooltip: 'Next Track',
            ),

            // Repeat Mode Button (Off, All, One / Repeat Current)
            ValueListenableBuilder<AudioRepeatMode>(
              valueListenable: player.repeatMode,
              builder: (context, mode, _) {
                IconData icon = Icons.repeat_rounded;
                Color color = AppTheme.spotifyLightGrey;
                String tooltip = 'Repeat: Off';

                if (mode == AudioRepeatMode.all) {
                  icon = Icons.repeat_rounded;
                  color = AppTheme.spotifyGreen;
                  tooltip = 'Repeat: All Tracks';
                } else if (mode == AudioRepeatMode.one) {
                  icon = Icons.repeat_one_rounded;
                  color = AppTheme.spotifyGreen;
                  tooltip = 'Repeat: Current Track (Looping)';
                }

                return IconButton(
                  iconSize: 24,
                  icon: Icon(icon, color: color),
                  onPressed: () => player.cycleRepeatMode(),
                  tooltip: tooltip,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Secondary controls under the transport: ±10s, playback speed, the
  /// equalizer (Android) and — on desktop only — an in-app volume slider.
  Widget _buildExtrasRow(BuildContext context) {
    Widget chip({
      Key? key,
      required IconData icon,
      required String label,
      required bool active,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      final color = active ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey;
      return Tooltip(
        message: tooltip,
        child: Material(
          color: AppTheme.spotifyCardHighlight,
          shape: StadiumBorder(
            side: BorderSide(color: active ? AppTheme.spotifyGreen : const Color(0xFF383838)),
          ),
          child: InkWell(
            key: key,
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? color : AppTheme.spotifyWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded, color: AppTheme.spotifyLightGrey),
              onPressed: () => player.seekRelative(const Duration(seconds: -10)),
              tooltip: 'Back 10 seconds',
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<double>(
              valueListenable: player.playbackSpeed,
              builder: (context, speed, _) => chip(
                icon: Icons.speed_rounded,
                label: '${speed}x',
                active: speed != 1.0,
                tooltip: 'Playback speed',
                onTap: () => _showSpeedSelector(context),
              ),
            ),
            if (player.equalizerSupported) ...[
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: Listenable.merge([player.equalizerPreset, player.equalizerEnabled]),
                builder: (context, _) => chip(
                  key: const ValueKey('equalizer_button'),
                  icon: Icons.tune_rounded,
                  label: player.equalizerEnabled.value ? player.equalizerPreset.value : 'EQ off',
                  active: player.equalizerEnabled.value,
                  tooltip: 'Equalizer',
                  onTap: () => showDialog(context: context, builder: (context) => const EqualizerDialog()),
                ),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded, color: AppTheme.spotifyLightGrey),
              onPressed: () => player.seekRelative(const Duration(seconds: 10)),
              tooltip: 'Forward 10 seconds',
            ),
          ],
        ),
        if (isDesktopPlatform) ...[
          const SizedBox(height: 8),
          const Center(
            child: VolumeControllerWidget(
              mode: VolumeDisplayMode.inline,
              sliderWidth: 160,
              showPercentage: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLyricsPreviewCard(Song song) {
    return Material(
      color: AppTheme.spotifyCardElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('lyrics_preview_card'),
        onTap: () => setState(() => _selectedTab = 1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lyrics',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.spotifyWhite),
                    ),
                    Icon(Icons.open_in_full_rounded, size: 16, color: AppTheme.spotifyLightGrey),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    LyricsService.instance.currentLyrics,
                    LyricsService.instance.isLoading,
                    player.position,
                  ]),
                  builder: (context, _) => _lyricsPreviewText(song),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The current and next synced line, the opening of plain lyrics, or a
  /// status message — so the card is useful without opening the lyrics tab.
  Widget _lyricsPreviewText(Song song) {
    const muted = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.spotifyLightGrey);
    final LyricsData? lyrics = LyricsService.instance.currentLyrics.value;
    final forThisSong = lyrics != null && lyrics.songId == song.id;

    if (!forThisSong || lyrics.isEmpty || lyrics.isError) {
      final String text;
      if (LyricsService.instance.isLoading.value) {
        text = 'Looking for lyrics…';
      } else if (forThisSong && lyrics.errorMessage != null) {
        text = lyrics.errorMessage!;
      } else {
        text = 'Tap to view lyrics';
      }
      return Text(text, style: muted);
    }

    if (lyrics.isSynced) {
      final pos = player.position.value;
      var i = 0;
      for (var j = 0; j < lyrics.syncedLines.length; j++) {
        if (pos >= lyrics.syncedLines[j].timestamp) i = j;
      }
      final current = lyrics.syncedLines[i].text;
      final next = i + 1 < lyrics.syncedLines.length ? lyrics.syncedLines[i + 1].text : '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current.isEmpty ? '♪' : current,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.spotifyWhite, height: 1.3),
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(next, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
          ],
        ],
      );
    }

    final opening = (lyrics.plainLyrics ?? '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .join('\n');
    return Text(
      opening,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: muted.copyWith(color: AppTheme.spotifyWhite, height: 1.4),
    );
  }

  void _showSpeedSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Playback Speed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(color: AppTheme.borderSubtle),
                ...speeds.map((s) {
                  final isSelected = (player.playbackSpeed.value == s);
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${s}x ${s == 1.0 ? "(Normal)" : ""}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.accentAmber : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppTheme.accentAmber)
                        : null,
                    onTap: () {
                      player.setPlaybackSpeed(s);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final options = [
          {'label': '15 minutes', 'minutes': 15, 'endOfTrack': false},
          {'label': '30 minutes', 'minutes': 30, 'endOfTrack': false},
          {'label': '45 minutes', 'minutes': 45, 'endOfTrack': false},
          {'label': '60 minutes', 'minutes': 60, 'endOfTrack': false},
          {'label': 'End of current track', 'minutes': null, 'endOfTrack': true},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sleep Timer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (player.sleepTimerRemainingMinutes.value != null ||
                          player.sleepAtEndOfTrack.value)
                        TextButton(
                          onPressed: () {
                            player.cancelSleepTimer();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Turn Off',
                            style: TextStyle(
                              color: AppTheme.accentAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: AppTheme.borderSubtle),
                ...options.map((opt) {
                  final minutes = opt['minutes'] as int?;
                  final endOfTrack = opt['endOfTrack'] as bool;
                  final isSelected = endOfTrack
                      ? player.sleepAtEndOfTrack.value
                      : (player.sleepTimerRemainingMinutes.value == minutes);

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      endOfTrack ? Icons.music_note_rounded : Icons.timer_outlined,
                      size: 20,
                      color: isSelected ? AppTheme.accentAmber : AppTheme.textSecondary,
                    ),
                    title: Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppTheme.accentAmber : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppTheme.accentAmber)
                        : null,
                    onTap: () {
                      player.setSleepTimer(minutes, endOfTrack: endOfTrack);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQueueModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ValueListenableBuilder<List<Song>>(
          valueListenable: player.queue,
          builder: (context, queue, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Queue • ${plural(queue.length, 'song')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  player.shuffleQueue();
                                },
                                icon: const Icon(Icons.shuffle_rounded, size: 16, color: AppTheme.accentAmber),
                                label: const Text('Shuffle', style: TextStyle(color: AppTheme.accentAmber, fontSize: 12)),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  player.clearQueue();
                                },
                                icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppTheme.textMuted),
                                label: const Text('Clear', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppTheme.borderSubtle),
                    Expanded(
                      child: queue.isEmpty
                          ? const Center(
                              child: Text(
                                'Queue is empty',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: queue.length,
                              itemBuilder: (context, index) {
                                final song = queue[index];
                                final isSelected = player.currentSong.value?.id == song.id;

                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: AppTheme.bgSurfaceHover,
                                  leading: isSelected
                                      ? const WaveformVisualizer(isPlaying: true, height: 14)
                                      : Text('${index + 1}', style: const TextStyle(color: AppTheme.textMuted)),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppTheme.accentAmberLight : AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        song.formattedDuration,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        iconSize: 18,
                                        icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                                        onPressed: () {
                                          player.removeFromQueue(index);
                                        },
                                        tooltip: 'Remove from queue',
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    player.playSong(song);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

}

/// Seek bar that follows playback but only seeks when the drag ends, so
/// scrubbing doesn't fire a seek per frame (which makes audio stutter).
class _ProgressScrubber extends StatefulWidget {
  final Song song;
  const _ProgressScrubber({required this.song});

  @override
  State<_ProgressScrubber> createState() => _ProgressScrubberState();
}

class _ProgressScrubberState extends State<_ProgressScrubber> {
  final player = AudioPlayerService.instance;
  double? _dragMs;

  static const _timeStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppTheme.spotifyLightGrey,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([player.duration, player.position]),
      builder: (context, _) {
        final pos = player.position.value;
        final total = player.duration.value;
        final rawTotalMs = total.inMilliseconds > 0
            ? total.inMilliseconds
            : (widget.song.durationMs > 0 ? widget.song.durationMs : 1);
        final totalMs = max(rawTotalMs, pos.inMilliseconds);
        final shownMs = (_dragMs ?? pos.inMilliseconds.toDouble()).clamp(0.0, totalMs.toDouble());

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                activeTrackColor: AppTheme.spotifyGreen,
                inactiveTrackColor: const Color(0xFF4D4D4D),
                thumbColor: AppTheme.spotifyWhite,
                overlayColor: AppTheme.spotifyGreen.withValues(alpha: 0.15),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: _dragMs != null ? 8 : 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                key: const ValueKey('seek_slider'),
                value: shownMs,
                max: totalMs.toDouble(),
                onChangeStart: (v) => setState(() => _dragMs = v),
                onChanged: (v) => setState(() => _dragMs = v),
                onChangeEnd: (v) async {
                  await player.seek(Duration(milliseconds: v.toInt()));
                  if (mounted) setState(() => _dragMs = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(Duration(milliseconds: shownMs.toInt())), style: _timeStyle),
                  Text(formatDuration(Duration(milliseconds: totalMs)), style: _timeStyle),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
