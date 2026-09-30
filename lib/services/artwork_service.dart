import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class ArtworkService {
  static final ArtworkService instance = ArtworkService._();
  ArtworkService._();

  static const MethodChannel _mediaStoreChannel =
      MethodChannel('com.example.freak_shit_show/media_store');

  final Map<String, String?> _cache = {};
  Directory? _artworkDir;

  Future<Directory> _getArtworkDir() async {
    if (_artworkDir != null) return _artworkDir!;
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'album_artworks'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _artworkDir = dir;
    return dir;
  }

  /// Retrieves the local file path of the song's album artwork/logo.
  /// Returns null if no artwork is available.
  Future<String?> getArtworkPath(Song song) async {
    // 1. In-memory cache
    if (_cache.containsKey(song.id)) {
      final cached = _cache[song.id];
      if (cached != null && File(cached).existsSync()) {
        return cached;
      }
    }

    // 2. Already set on song model
    if (song.artworkPath != null && File(song.artworkPath!).existsSync()) {
      _cache[song.id] = song.artworkPath;
      return song.artworkPath;
    }

    final dir = await _getArtworkDir();
    final cacheFile = File(p.join(dir.path, 'art_${song.id.hashCode}.jpg'));

    // 3. Pre-existing on disk
    if (cacheFile.existsSync() && cacheFile.lengthSync() > 0) {
      song.artworkPath = cacheFile.path;
      _cache[song.id] = cacheFile.path;
      return cacheFile.path;
    }

    // 4. Android native extraction (MediaMetadataRetriever + MediaStore AlbumArt + loadThumbnail)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _mediaStoreChannel.invokeMethod<String>('getArtwork', {
          'songId': song.id,
          'filePath': song.filePath,
          'contentUri': song.contentUri ?? '',
          'albumId': song.albumId ?? 0,
        });

        if (result != null && result.isNotEmpty && File(result).existsSync()) {
          song.artworkPath = result;
          _cache[song.id] = result;
          return result;
        }
      } catch (e) {
        debugPrint('Android getArtwork error: $e');
      }
    }

    // 5. Pure Dart embedded ID3 / MP4 / FLAC picture parser (Windows, Linux, Android fallback)
    if (!kIsWeb && song.filePath.isNotEmpty) {
      final extracted = await _extractEmbeddedArtwork(song.filePath, cacheFile);
      if (extracted && cacheFile.existsSync() && cacheFile.lengthSync() > 0) {
        song.artworkPath = cacheFile.path;
        _cache[song.id] = cacheFile.path;
        return cacheFile.path;
      }
    }

    _cache[song.id] = null;
    return null;
  }

  /// Fast pure Dart metadata picture extractor for MP3 (ID3v2 APIC), M4A (covr), and FLAC.
  Future<bool> _extractEmbeddedArtwork(String filePath, File destination) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      final raf = await file.open(mode: FileMode.read);
      try {
        final fileLen = await file.length();
        // Read up to first 2MB where audio headers and cover art frames reside
        final readLen = min(fileLen, 2 * 1024 * 1024);
        final bytes = await raf.read(readLen);

        final artBytes = _findEmbeddedImageBytes(bytes);
        if (artBytes != null && artBytes.isNotEmpty) {
          await destination.writeAsBytes(artBytes, flush: true);
          return true;
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}
    return false;
  }

  /// Locates embedded JPEG or PNG payload inside raw metadata buffer
  Uint8List? _findEmbeddedImageBytes(Uint8List bytes) {
    if (bytes.length < 100) return null;

    // 1. Search for JPEG magic bytes: 0xFF 0xD8 0xFF
    int jpegStart = -1;
    for (int i = 0; i < bytes.length - 4; i++) {
      if (bytes[i] == 0xFF &&
          bytes[i + 1] == 0xD8 &&
          bytes[i + 2] == 0xFF &&
          (bytes[i + 3] == 0xE0 || bytes[i + 3] == 0xE1 || bytes[i + 3] == 0xDB || bytes[i + 3] == 0xEE)) {
        jpegStart = i;
        break;
      }
    }

    if (jpegStart >= 0) {
      // Find JPEG End-Of-Image marker: 0xFF 0xD9
      int jpegEnd = -1;
      for (int i = jpegStart + 4; i < bytes.length - 1; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
          jpegEnd = i + 2;
        }
      }
      if (jpegEnd > jpegStart && (jpegEnd - jpegStart) > 1024) {
        return Uint8List.sublistView(bytes, jpegStart, jpegEnd);
      }
    }

    // 2. Search for PNG magic bytes: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
    int pngStart = -1;
    for (int i = 0; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x89 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x4E &&
          bytes[i + 3] == 0x47 &&
          bytes[i + 4] == 0x0D &&
          bytes[i + 5] == 0x0A &&
          bytes[i + 6] == 0x1A &&
          bytes[i + 7] == 0x0A) {
        pngStart = i;
        break;
      }
    }

    if (pngStart >= 0) {
      // Find PNG IEND chunk: 0x49 0x45 0x4E 0x44 + 4 bytes CRC
      int pngEnd = -1;
      for (int i = pngStart + 8; i < bytes.length - 8; i++) {
        if (bytes[i] == 0x49 &&
            bytes[i + 1] == 0x45 &&
            bytes[i + 2] == 0x4E &&
            bytes[i + 3] == 0x44) {
          pngEnd = i + 8; // Include 4 bytes IEND and 4 bytes CRC
          break;
        }
      }
      if (pngEnd > pngStart && (pngEnd - pngStart) > 1024) {
        return Uint8List.sublistView(bytes, pngStart, pngEnd);
      }
    }

    return null;
  }
}
