import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

/// Resolves album artwork to a cached image file.
///
/// Results — including "no artwork" — are remembered per song, concurrent
/// requests for the same song share one lookup, and at most [_maxConcurrent]
/// extractions run at once so scrolling a long list stays smooth.
class ArtworkService {
  static final ArtworkService instance = ArtworkService._();
  ArtworkService._();

  static const MethodChannel _mediaStoreChannel = MethodChannel('com.example.freak_shit_show/media_store');
  static const int _maxConcurrent = 3;

  final Map<String, String?> _resolved = {};
  final Map<String, Future<String?>> _pending = {};
  final Queue<Completer<void>> _waiters = Queue();
  int _running = 0;
  Directory? _artworkDir;

  /// True once a lookup for [song] has finished (with or without artwork).
  bool isResolved(Song song) => _resolved.containsKey(song.id);

  /// Synchronously known artwork path, without touching the disk.
  String? peek(Song song) => _resolved[song.id] ?? song.artworkPath;

  Future<String?> getArtworkPath(Song song) {
    if (_resolved.containsKey(song.id)) return Future.value(_resolved[song.id]);
    return _pending[song.id] ??= _withSlot(() => _resolve(song)).then((path) {
      _resolved[song.id] = path;
      if (path != null) song.artworkPath = path;
      return path;
    }).whenComplete(() => _pending.remove(song.id));
  }

  Future<T> _withSlot<T>(Future<T> Function() task) async {
    if (_running >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _running++;
    try {
      return await task();
    } finally {
      _running--;
      if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
    }
  }

  Future<Directory> _getArtworkDir() async {
    if (_artworkDir != null) return _artworkDir!;
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'album_artworks'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return _artworkDir = dir;
  }

  Future<String?> _resolve(Song song) async {
    if (kIsWeb) return null;

    final known = song.artworkPath;
    if (known != null && await File(known).exists()) return known;

    final safeId = song.id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final cacheFile = File(p.join((await _getArtworkDir()).path, 'art_$safeId.img'));
    if (await cacheFile.exists() && await cacheFile.length() > 0) return cacheFile.path;
    // Remember misses across launches so files without art aren't re-probed.
    final missMarker = File('${cacheFile.path}.none');
    if (await missMarker.exists()) return null;

    final found = await _extract(song, safeId, cacheFile);
    if (found == null) {
      try {
        await missMarker.create();
      } catch (_) {}
    }
    return found;
  }

  Future<String?> _extract(Song song, String safeId, File cacheFile) async {

    if (Platform.isAndroid) {
      // MediaMetadataRetriever + MediaStore album art, on a native worker thread.
      try {
        final result = await _mediaStoreChannel.invokeMethod<String>('getArtwork', {
          'targetPath': cacheFile.path,
          'filePath': song.filePath,
          'contentUri': song.contentUri ?? '',
          'albumId': song.albumId ?? 0,
        });
        if (result != null && result.isNotEmpty) return result;
      } catch (e) {
        debugPrint('Android getArtwork error: $e');
      }
      return null;
    }

    if (song.filePath.isEmpty) return null;
    final source = song.filePath;
    final target = cacheFile.path;
    try {
      final written = await Isolate.run(() => _extractEmbeddedArtwork(source, target));
      return written ? target : null;
    } catch (_) {
      return null;
    }
  }

  /// Reads the embedded front cover (ID3 APIC, MP4 covr, FLAC/Vorbis picture)
  /// and writes it to [targetPath]. Runs on a background isolate.
  static bool _extractEmbeddedArtwork(String sourcePath, String targetPath) {
    final file = File(sourcePath);
    if (!file.existsSync()) return false;
    final meta = readMetadata(file, getImage: true);
    if (meta.pictures.isEmpty) return false;
    final cover = meta.pictures.firstWhere(
      (pic) => pic.pictureType == PictureType.coverFront,
      orElse: () => meta.pictures.first,
    );
    if (cover.bytes.isEmpty) return false;
    File(targetPath).writeAsBytesSync(cover.bytes, flush: true);
    return true;
  }
}
