import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/lyrics_model.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import '../theme/app_theme.dart';
import 'lyrics_share_dialog.dart';

class LyricsView extends StatefulWidget {
  final Song song;
  final bool isCompact;
  final VoidCallback? onOpenFullPlayer;

  const LyricsView({
    super.key,
    required this.song,
    this.isCompact = false,
    this.onOpenFullPlayer,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  final LyricsService _lyricsService = LyricsService.instance;
  final AudioPlayerService _playerService = AudioPlayerService.instance;

  final Map<int, GlobalKey> _lineKeys = {};
  Timer? _userScrollResumeTimer;
  Timer? _programmaticScrollResetTimer;
  bool _isProgrammaticScroll = false;

  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  bool _preferPlainLyrics = false;

  @override
  void initState() {
    super.initState();
    _loadLyricsForCurrentSong();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _userScrollResumeTimer?.cancel();
      _programmaticScrollResetTimer?.cancel();
      _lineKeys.clear();
      _lastActiveIndex = -1;
      _userIsScrolling = false;
      _loadLyricsForCurrentSong();
    }
  }

  void _loadLyricsForCurrentSong({bool forceRefresh = false}) {
    _userScrollResumeTimer?.cancel();
    _programmaticScrollResetTimer?.cancel();
    _lineKeys.clear();
    _userIsScrolling = false;
    _lastActiveIndex = -1;
    _lyricsService.fetchLyrics(widget.song, forceRefresh: forceRefresh);
  }

  @override
  void dispose() {
    _userScrollResumeTimer?.cancel();
    _programmaticScrollResetTimer?.cancel();
    _lineKeys.clear();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleUserStartedScrolling() {
    _isProgrammaticScroll = false;
    _programmaticScrollResetTimer?.cancel();

    if (!_userIsScrolling) {
      setState(() {
        _userIsScrolling = true;
      });
    }

    // Keep user scroll unblocked for 8 seconds of inactivity before auto-resuming
    _userScrollResumeTimer?.cancel();
    _userScrollResumeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _userIsScrolling = false;
        });
        if (_lastActiveIndex >= 0) {
          _scrollToActiveLine(_lastActiveIndex);
        }
      }
    });
  }

  void _scrollToActiveLine(int index) {
    if (_userIsScrolling || !_scrollController.hasClients) return;

    final key = _lineKeys[index];
    final lineContext = key?.currentContext;

    _isProgrammaticScroll = true;
    _programmaticScrollResetTimer?.cancel();
    _programmaticScrollResetTimer = Timer(const Duration(milliseconds: 500), () {
      _isProgrammaticScroll = false;
    });

    if (lineContext != null) {
      // Direct pixel-accurate alignment: centers the singing line at 42% from top
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.42,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Accurate calibrated fallback if item is not yet rendered
      final calibratedHeight = widget.isCompact ? 28.0 : 38.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = ((index * calibratedHeight) - (viewportHeight * 0.42))
          .clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      ).then((_) {
        if (!mounted || _userIsScrolling) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _userIsScrolling) return;
          final keyNow = _lineKeys[index];
          if (keyNow?.currentContext != null) {
            Scrollable.ensureVisible(
              keyNow!.currentContext!,
              alignment: 0.42,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _lyricsService.isLoading,
      builder: (context, isLoading, _) {
        return ValueListenableBuilder<LyricsData?>(
          valueListenable: _lyricsService.currentLyrics,
          builder: (context, lyrics, _) {
            final hasLyrics = lyrics != null &&
                lyrics.songId == widget.song.id &&
                !lyrics.isEmpty &&
                !lyrics.isError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar with Source & Actions
                _buildLyricsHeader(context, lyrics, isLoading, hasLyrics),

                // Main Content
                Expanded(
                  child: _buildBody(lyrics, isLoading, hasLyrics),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLyricsHeader(
    BuildContext context,
    LyricsData? lyrics,
    bool isLoading,
    bool hasLyrics,
  ) {
    final isSynced = hasLyrics && lyrics!.isSynced && !_preferPlainLyrics;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 12 : 16,
        vertical: widget.isCompact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Source Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasLyrics
                  ? (isSynced
                      ? AppTheme.accentAmber.withValues(alpha: 0.18)
                      : AppTheme.borderMedium)
                  : AppTheme.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasLyrics && isSynced
                    ? AppTheme.accentAmber.withValues(alpha: 0.5)
                    : AppTheme.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSynced ? Icons.graphic_eq_rounded : Icons.lyrics_rounded,
                  size: 13,
                  color: hasLyrics && isSynced
                      ? AppTheme.accentAmberLight
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  hasLyrics
                      ? (lyrics!.source)
                      : 'Free Lyrics Engine',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasLyrics && isSynced
                        ? AppTheme.accentAmberLight
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Toggle plain / synced if synced lyrics available
          if (hasLyrics && lyrics!.syncedLines.isNotEmpty && lyrics.plainLyrics != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                _preferPlainLyrics ? Icons.timer_rounded : Icons.notes_rounded,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              label: Text(
                _preferPlainLyrics ? 'Sync' : 'Text',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              onPressed: () {
                setState(() {
                  _preferPlainLyrics = !_preferPlainLyrics;
                });
              },
            ),

          // Spotify-style Share Lyrics Button
          if (hasLyrics)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 2),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.spotifyGreen.withValues(alpha: 0.16),
                  foregroundColor: AppTheme.spotifyGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppTheme.spotifyGreen.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                ),
                icon: const Icon(Icons.share_rounded, size: 13, color: AppTheme.spotifyGreen),
                label: const Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                onPressed: () => _openShareLyrics(lyrics!),
              ),
            ),

          // Refresh button
          IconButton(
            iconSize: 18,
            splashRadius: 18,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
            tooltip: 'Refresh lyrics from free sources',
            onPressed: isLoading
                ? null
                : () => _loadLyricsForCurrentSong(forceRefresh: true),
          ),

          // Open Full Player if requested
          if (widget.isCompact && widget.onOpenFullPlayer != null) ...[
            const SizedBox(width: 4),
            IconButton(
              iconSize: 18,
              splashRadius: 18,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.open_in_full_rounded, color: AppTheme.textMuted),
              tooltip: 'Expand full player',
              onPressed: widget.onOpenFullPlayer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(LyricsData? lyrics, bool isLoading, bool hasLyrics) {
    if (isLoading) return _buildLoadingState();
    if (!hasLyrics || lyrics == null) return _buildEmptyState(lyrics);
    return _buildLyricsContent(lyrics);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fetching free lyrics for "${widget.song.title}"...',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sources: LRCLIB & Lyrics.ovh',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LyricsData? lyrics) {
    final msg = lyrics?.errorMessage ?? 'No lyrics found for this track';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderMedium),
              ),
              child: const Icon(
                Icons.lyrics_outlined,
                size: 24,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.borderMedium),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search_rounded, size: 15, color: AppTheme.accentAmber),
              label: const Text(
                'Retry Search',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentAmberLight,
                ),
              ),
              onPressed: () => _loadLyricsForCurrentSong(forceRefresh: true),
            ),
          ],
        ),
      ),
    );
  }

  void _openShareLyrics(LyricsData lyrics) {
    List<String> allLines;
    if (lyrics.isSynced && lyrics.syncedLines.isNotEmpty) {
      allLines = lyrics.syncedLines.map((l) => l.text).toList();
    } else if (lyrics.plainLyrics != null && lyrics.plainLyrics!.isNotEmpty) {
      allLines = lyrics.plainLyrics!.split('\n');
    } else {
      return;
    }

    LyricsShareDialog.show(
      context,
      song: widget.song,
      allLines: allLines,
      initialActiveIndex: _lastActiveIndex,
    );
  }

  Widget _buildLyricsContent(LyricsData lyrics) {
    if (lyrics.isSynced && !_preferPlainLyrics) {
      return _buildSyncedLyricsList(lyrics, lyrics.syncedLines);
    } else {
      return _buildPlainLyricsView(lyrics, lyrics.plainLyrics ?? '');
    }
  }

  Widget _buildSyncedLyricsList(LyricsData lyrics, List<LyricLine> lines) {
    return ValueListenableBuilder<Duration>(
      valueListenable: _playerService.position,
      builder: (context, position, _) {
        int activeIndex = -1;
        for (int i = 0; i < lines.length; i++) {
          if (position >= lines[i].timestamp) {
            activeIndex = i;
          } else {
            break;
          }
        }

        if (activeIndex != _lastActiveIndex && activeIndex >= 0) {
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActiveLine(activeIndex);
          });
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (notif is UserScrollNotification) {
                  if (notif.direction != ScrollDirection.idle) {
                    _handleUserStartedScrolling();
                  }
                } else if (notif is ScrollUpdateNotification) {
                  // Intercept mouse wheel, trackpad, and touch drag when not programmatic
                  if (!_isProgrammaticScroll) {
                    if (notif.dragDetails != null ||
                        (notif.scrollDelta != null && notif.scrollDelta!.abs() > 0.5)) {
                      _handleUserStartedScrolling();
                    }
                  }
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: widget.isCompact ? 16 : 24,
                  right: widget.isCompact ? 16 : 24,
                  top: widget.isCompact ? 16 : 32,
                  bottom: widget.isCompact ? 80 : 160,
                ),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isActive = index == activeIndex;
                  final isPast = index < activeIndex;
                  final lineKey = _lineKeys.putIfAbsent(index, () => GlobalKey());

                  return Container(
                    key: lineKey,
                    child: InkWell(
                      onTap: () {
                        _userScrollResumeTimer?.cancel();
                        if (mounted) {
                          setState(() {
                            _userIsScrolling = false;
                          });
                        }
                        _playerService.seek(line.timestamp);
                        _scrollToActiveLine(index);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: widget.isCompact ? 5.0 : 8.0,
                          horizontal: 6.0,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: isActive
                                ? (widget.isCompact ? 15.5 : 20.0)
                                : (widget.isCompact ? 13.0 : 16.0),
                            fontWeight: isActive
                                ? FontWeight.w800
                                : (isPast ? FontWeight.w500 : FontWeight.w400),
                            color: isActive
                                ? AppTheme.accentAmber
                                : (isPast
                                    ? AppTheme.textPrimary.withValues(alpha: 0.75)
                                    : AppTheme.textMuted.withValues(alpha: 0.55)),
                            letterSpacing: isActive ? -0.2 : 0.0,
                            height: 1.35,
                            shadows: isActive
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentAmber.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            line.text.isEmpty ? '♪  ♪  ♪' : line.text,
                            textAlign: widget.isCompact ? TextAlign.left : TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Floating "Resume Sync" Chip displayed when user scrolled manually
            if (_userIsScrolling)
              Positioned(
                bottom: widget.isCompact ? 10 : 18,
                right: widget.isCompact ? 12 : 20,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _userScrollResumeTimer?.cancel();
                      if (mounted) {
                        setState(() {
                          _userIsScrolling = false;
                        });
                      }
                      if (_lastActiveIndex >= 0) {
                        _scrollToActiveLine(_lastActiveIndex);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: AppTheme.accentAmber.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.sync_rounded, size: 14, color: Color(0xFF0D0F12)),
                          SizedBox(width: 5),
                          Text(
                            'Resume Sync',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D0F12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlainLyricsView(LyricsData lyrics, String plainLyrics) {
    final lines = plainLyrics.split('\n');

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 16 : 24,
            vertical: 16,
          ),
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index].trim();
            if (line.isEmpty) {
              return const SizedBox(height: 12);
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Text(
                line,
                textAlign: widget.isCompact ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  fontSize: widget.isCompact ? 13.0 : 15.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
