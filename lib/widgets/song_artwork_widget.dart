import 'dart:io';
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/artwork_service.dart';
import '../theme/app_theme.dart';

class SongArtworkWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // 1. Direct path exists
    if (song.artworkPath != null && File(song.artworkPath!).existsSync()) {
      return _buildImageContainer(song.artworkPath!);
    }

    // 2. Fetch asynchronously from ArtworkService
    return FutureBuilder<String?>(
      future: ArtworkService.instance.getArtworkPath(song),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null &&
            File(snapshot.data!).existsSync()) {
          return _buildImageContainer(snapshot.data!);
        }

        return fallback ?? _buildPlaceholder();
      },
    );
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
