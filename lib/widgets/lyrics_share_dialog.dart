import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/lyrics_share_service.dart';
import '../theme/app_theme.dart';
import 'song_artwork_widget.dart';

class LyricCardTheme {
  final String name;
  final LinearGradient gradient;
  final Color accentColor;

  const LyricCardTheme({
    required this.name,
    required this.gradient,
    required this.accentColor,
  });
}

final List<LyricCardTheme> kLyricCardThemes = [
  const LyricCardTheme(
    name: 'Spotify Obsidian',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF14241B), Color(0xFF0D1410), Color(0xFF080C09)],
    ),
    accentColor: AppTheme.spotifyGreen,
  ),
  const LyricCardTheme(
    name: 'Emerald Vibe',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1DB954), Color(0xFF137A37), Color(0xFF0A441E)],
    ),
    accentColor: Color(0xFF86EFAC),
  ),
  const LyricCardTheme(
    name: 'Neon Velvet',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4C1D95), Color(0xFF2E1065), Color(0xFF120428)],
    ),
    accentColor: Color(0xFFC084FC),
  ),
  const LyricCardTheme(
    name: 'Sunset Ember',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9A3412), Color(0xFF431407), Color(0xFF1C0702)],
    ),
    accentColor: Color(0xFFFDBA74),
  ),
  const LyricCardTheme(
    name: 'Ocean Midnight',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E3A8A), Color(0xFF0F172A), Color(0xFF030712)],
    ),
    accentColor: Color(0xFF93C5FD),
  ),
  const LyricCardTheme(
    name: 'Ruby Rose',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF881337), Color(0xFF4C0519), Color(0xFF1A0108)],
    ),
    accentColor: Color(0xFFFDA4AF),
  ),
  const LyricCardTheme(
    name: 'Onyx Monochrome',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF262626), Color(0xFF171717), Color(0xFF0A0A0A)],
    ),
    accentColor: Colors.white,
  ),
];

class LyricsShareDialog extends StatefulWidget {
  final Song song;
  final List<String> allLines;
  final int initialActiveIndex;

  const LyricsShareDialog({
    super.key,
    required this.song,
    required this.allLines,
    this.initialActiveIndex = -1,
  });

  /// Presents the Spotify Lyrics Share modal
  static Future<void> show(
    BuildContext context, {
    required Song song,
    required List<String> allLines,
    int initialActiveIndex = -1,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LyricsShareDialog(
        song: song,
        allLines: allLines,
        initialActiveIndex: initialActiveIndex,
      ),
    );
  }

  @override
  State<LyricsShareDialog> createState() => _LyricsShareDialogState();
}

class _LyricsShareDialogState extends State<LyricsShareDialog> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  final Set<int> _selectedIndices = {};
  int _selectedThemeIndex = 0;
  bool _isExporting = false;

  static const int _maxSelection = 5;

  @override
  void initState() {
    super.initState();
    // Pre-select the currently active lyric line if valid
    if (widget.initialActiveIndex >= 0 &&
        widget.initialActiveIndex < widget.allLines.length &&
        widget.allLines[widget.initialActiveIndex].trim().isNotEmpty) {
      _selectedIndices.add(widget.initialActiveIndex);
    } else if (widget.allLines.isNotEmpty) {
      // Find first non-empty line
      for (var i = 0; i < widget.allLines.length; i++) {
        if (widget.allLines[i].trim().isNotEmpty) {
          _selectedIndices.add(i);
          break;
        }
      }
    }
  }

  void _toggleLine(int index) {
    if (widget.allLines[index].trim().isEmpty) return;

    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        if (_selectedIndices.length >= _maxSelection) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'You can select up to 5 lines for a card.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF282828),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
        _selectedIndices.add(index);
      }
    });
  }

  List<String> get _orderedSelectedLines {
    final sorted = _selectedIndices.toList()..sort();
    return sorted.map((idx) => widget.allLines[idx].trim()).where((l) => l.isNotEmpty).toList();
  }

  Future<void> _handleShare() async {
    final lines = _orderedSelectedLines;
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 line to share.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    final success = await LyricsShareService.shareLyricCard(
      boundaryKey: _cardBoundaryKey,
      song: widget.song,
      lines: lines,
      pixelRatio: 3.0,
    );
    if (mounted) {
      setState(() => _isExporting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleCopyText() async {
    final lines = _orderedSelectedLines;
    if (lines.isEmpty) return;

    await LyricsShareService.copyLyricsText(song: widget.song, lines: lines);
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppTheme.spotifyGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Lyrics copied to clipboard!',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF282828),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleSaveImage() async {
    final lines = _orderedSelectedLines;
    if (lines.isEmpty) return;

    setState(() => _isExporting = true);
    final savedPath = await LyricsShareService.saveLyricCardToDisk(
      boundaryKey: _cardBoundaryKey,
      song: widget.song,
    );
    if (mounted) {
      setState(() => _isExporting = false);
      if (savedPath != null) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done_rounded, color: AppTheme.spotifyGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved to $savedPath',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF282828),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = kLyricCardThemes[_selectedThemeIndex];
    final selectedLines = _orderedSelectedLines;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: AppTheme.bgObsidian,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3E3E3E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Top Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.spotifyWhite),
                  splashRadius: 20,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Lyrics',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.spotifyWhite,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${_selectedIndices.length}/$_maxSelection lines selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedIndices.isNotEmpty
                            ? AppTheme.spotifyGreen
                            : AppTheme.spotifyLightGrey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_selectedIndices.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selectedIndices.clear()),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF242424), height: 1),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const BouncingScrollPhysics(),
              children: [
                // Live Card Preview
                Center(
                  child: RepaintBoundary(
                    key: _cardBoundaryKey,
                    child: _buildLyricCard(theme, selectedLines),
                  ),
                ),

                const SizedBox(height: 18),

                // Theme Palette Selector
                _buildThemeSelector(),

                const SizedBox(height: 22),

                // Section Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TAP LINES TO INCLUDE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppTheme.spotifySubdued,
                      ),
                    ),
                    Text(
                      '${widget.allLines.length} lines',
                      style: const TextStyle(fontSize: 11, color: AppTheme.spotifySubdued),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Interactive Line Selection List
                _buildLinesList(),
              ],
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(selectedLines.isNotEmpty),
        ],
      ),
    );
  }

  Widget _buildLyricCard(LyricCardTheme theme, List<String> selectedLines) {
    final double cardWidth = 320;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: theme.gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            offset: const Offset(0, 14),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Song artwork & Metadata
          Row(
            children: [
              SongArtworkWidget(
                song: widget.song,
                size: 42,
                borderRadius: 6,
                fit: BoxFit.cover,
                showPlayingBadge: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.graphic_eq_rounded,
                size: 18,
                color: theme.accentColor,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Body: Selected Lyric Lines
          if (selectedLines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Select up to 5 lines below\nto preview your Spotify card',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),
            )
          else ...[
            for (var i = 0; i < selectedLines.length; i++) ...[
              Text(
                selectedLines[i],
                style: TextStyle(
                  fontSize: _getLineFontSize(selectedLines.length),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.35,
                  letterSpacing: -0.3,
                ),
              ),
              if (i < selectedLines.length - 1) const SizedBox(height: 8),
            ],
          ],

          const SizedBox(height: 26),

          // Footer: Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppTheme.spotifyGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.play_arrow_rounded, size: 10, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'FreakFM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Text(
                widget.song.album.isNotEmpty ? widget.song.album : 'Hi-Fi Audio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getLineFontSize(int lineCount) {
    switch (lineCount) {
      case 1:
        return 22;
      case 2:
        return 19;
      case 3:
        return 17;
      default:
        return 15;
    }
  }

  Widget _buildThemeSelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: kLyricCardThemes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, idx) {
          final t = kLyricCardThemes[idx];
          final isSelected = idx == _selectedThemeIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedThemeIndex = idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: t.gradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xFF404040),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: t.accentColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLinesList() {
    return Column(
      children: List.generate(widget.allLines.length, (idx) {
        final line = widget.allLines[idx].trim();
        if (line.isEmpty) return const SizedBox.shrink();

        final isSelected = _selectedIndices.contains(idx);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: isSelected
                ? AppTheme.spotifyCardHighlight
                : AppTheme.spotifyCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _toggleLine(idx),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.spotifyGreen : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.spotifyGreen : const Color(0xFF555555),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(Icons.check_rounded, size: 14, color: Colors.black),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.spotifyWhite : AppTheme.spotifyLightGrey,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomActionBar(bool canShare) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(top: BorderSide(color: Color(0xFF262626), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Copy Text Button
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppTheme.spotifyLightGrey),
              tooltip: 'Copy lyrics text',
              splashRadius: 22,
              onPressed: canShare ? _handleCopyText : null,
            ),
            // Save Image Button
            IconButton(
              icon: const Icon(Icons.download_rounded, color: AppTheme.spotifyLightGrey),
              tooltip: 'Save image to disk',
              splashRadius: 22,
              onPressed: canShare ? _handleSaveImage : null,
            ),
            const SizedBox(width: 8),

            // Share Card Main Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (canShare && !_isExporting) ? _handleShare : null,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  _isExporting ? 'Generating Card...' : 'Share Card',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.spotifyGreen,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF2E2E2E),
                  disabledForegroundColor: const Color(0xFF757575),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
