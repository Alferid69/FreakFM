import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/artwork_service.dart';
import '../theme/app_theme.dart';

class SongArtworkWidget extends StatefulWidget {
  final Song song;
  final double size;
  final double borderRadius;
  final bool isPlaying;
  final BoxFit fit;
  final Widget? fallback;
  final bool showPlayingBadge;

  const SongArtworkWidget({
    super.key,
    required this.song,
    this.size = 46,
    this.borderRadius = 4,
    this.isPlaying = false,
    this.fit = BoxFit.cover,
    this.fallback,
    this.showPlayingBadge = true,
  });

  @override
  State<SongArtworkWidget> createState() => _SongArtworkWidgetState();
}

class _SongArtworkWidgetState extends State<SongArtworkWidget> {
  String? _path;

  Song get song => widget.song;
  double get size => widget.size;
  double get borderRadius => widget.borderRadius;
  bool get isPlaying => widget.isPlaying;
  BoxFit get fit => widget.fit;
  Widget? get fallback => widget.fallback;
  bool get showPlayingBadge => widget.showPlayingBadge;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SongArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) _resolve();
  }

  /// Looks the artwork up once per song; the service caches hits and misses,
  /// so rebuilds never touch the disk.
  void _resolve() {
    final service = ArtworkService.instance;
    final requested = widget.song;
    _path = service.peek(requested);
    if (service.isResolved(requested)) return;
    service.getArtworkPath(requested).then((path) {
      if (mounted && widget.song.id == requested.id && path != _path) {
        setState(() => _path = path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path != null) return _buildImageContainer(path);
    return fallback ?? _buildPlaceholder();
  }

  Widget _buildImageContainer(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.file(
              File(path),
              width: size,
              height: size,
              fit: fit,
              cacheWidth: (size * 2.5).toInt(),
              cacheHeight: (size * 2.5).toInt(),
              errorBuilder: (context, error, stackTrace) => fallback ?? _buildPlaceholder(),
            ),
            if (isPlaying && showPlayingBadge)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.spotifyGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.spotifyCardElevated,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFF282828), width: 0.8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF282828), Color(0xFF181818)],
                ),
              ),
            ),
            Icon(
              Icons.music_note_rounded,
              size: size * 0.48,
              color: isPlaying ? AppTheme.spotifyGreen : AppTheme.spotifySubdued,
            ),
            if (isPlaying && showPlayingBadge)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.spotifyGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
