import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import 'library_rules.dart';
import 'storage_cache_service.dart';

class ScanResult {
  final List<Song> songs;
  final int durationMs;

  ScanResult({required this.songs, required this.durationMs});
}

class MusicScannerService {
  static const MethodChannel _mediaStoreChannel = MethodChannel('com.example.freak_shit_show/media_store');

  static const Set<String> audioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.wma',
  };

  /// Folder names (case-insensitive) never descended into during a scan.
  static const Set<String> _skipDirNames = {
    'node_modules',
    'appdata',
    'windows',
    'program files',
    'program files (x86)',
    r'$recycle.bin',
    'system volume information',
    'build',
  };

  /// Requests audio read access. Android 13+ uses READ_MEDIA_AUDIO, older
  /// versions READ_EXTERNAL_STORAGE. Never asks for "All files access".
  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
      return true;
    }
    if ((await Permission.audio.request()).isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await Permission.audio.isGranted || await Permission.storage.isGranted;
  }

  /// Built-in music locations. On Android only public music/download folders
  /// are indexed, so audio cached by other apps (Quran readers, messengers,
  /// podcast apps, ringtones, voice recorders) stays out of the library.
  /// Anything else can be added explicitly with "Add folder".
  static Future<List<String>> defaultLibraryRoots() async {
    final candidates = <String>[];

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        candidates.addAll([
          p.join(userProfile, 'Music'),
          p.join(userProfile, 'Downloads'),
          p.join(userProfile, 'OneDrive', 'Music'),
          p.join(userProfile, 'CrossDevice'),
        ]);
      }
      for (final drive in ['D', 'E', 'F']) {
        candidates.add('$drive:\\Music');
        candidates.add('$drive:\\Audio');
      }
    } else if (Platform.isAndroid) {
      final volumes = <String>['/storage/emulated/0'];
      try {
        await for (final entity in Directory('/storage').list()) {
          final name = p.basename(entity.path);
          if (entity is Directory && name != 'emulated' && name != 'self') {
            volumes.add(entity.path);
          }
        }
      } catch (_) {}
      for (final volume in volumes) {
        for (final folder in const ['Music', 'Download', 'Downloads', 'Audio']) {
          candidates.add('$volume/$folder');
        }
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        candidates.addAll([p.join(home, 'Music'), p.join(home, 'Downloads')]);
      }
    }

    final roots = <String>[];
    for (final dir in candidates) {
      if (await Directory(dir).exists()) roots.add(dir);
    }
    return roots;
  }

  /// Default roots plus folders the user added.
  static Future<List<String>> libraryRoots() async {
    final roots = await defaultLibraryRoots();
    for (final dir in await StorageCacheService.loadCustomDirectories()) {
      if (!roots.any((r) => LibraryRules.normalize(r) == LibraryRules.normalize(dir)) &&
          await Directory(dir).exists()) {
        roots.add(dir);
      }
    }
    return roots;
  }

  /// Scans the library. On Android the MediaStore index is combined with a
  /// filesystem walk; everything is filtered through [LibraryRules.isInLibrary].
  static Future<ScanResult> scanLibrary({
    List<String>? roots,
    List<String>? excluded,
    bool includeMediaStore = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    roots ??= await libraryRoots();
    excluded ??= await StorageCacheService.loadExcludedDirectories();

    final songs = <Song>[];

    if (includeMediaStore && !kIsWeb && Platform.isAndroid) {
      final mediaStoreSongs = await queryAndroidMediaStore();
      final nomediaCache = <String, bool>{};
      for (final song in mediaStoreSongs) {
        if (LibraryRules.isInLibrary(song.filePath, roots, excluded) &&
            !_hasNomediaAncestor(song.filePath, roots, nomediaCache)) {
          songs.add(song);
        }
      }
    }

    if (roots.isNotEmpty) {
      try {
        final request = _FsScanRequest(
          roots: roots,
          excluded: excluded,
          // Files MediaStore already described don't need their tags re-read.
          knownPaths: songs.map((s) => LibraryRules.normalize(s.filePath)).toSet(),
        );
        final fsSongs = await Isolate.run(() => _scanFileSystem(request));
        songs.addAll(fsSongs);
      } catch (e) {
        debugPrint('Filesystem scan error: $e');
      }
    }

    stopwatch.stop();
    return ScanResult(
      songs: LibraryRules.dedupeByPath(songs),
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  static bool _hasNomediaAncestor(String filePath, List<String> roots, Map<String, bool> cache) {
    var dir = p.dirname(filePath);
    final visited = <String>[];
    bool result = false;
    while (true) {
      final cached = cache[dir];
      if (cached != null) {
        result = cached;
        break;
      }
      visited.add(dir);
      if (File(p.join(dir, '.nomedia')).existsSync()) {
        result = true;
        break;
      }
      final isRoot = roots.any((r) => LibraryRules.normalize(r) == LibraryRules.normalize(dir));
      final parent = p.dirname(dir);
      if (isRoot || parent == dir) break;
      dir = parent;
    }
    for (final v in visited) {
      cache[v] = result;
    }
    return result;
  }

  /// Queries Android's MediaStore via the native channel (runs off the UI
  /// thread on the Kotlin side).
  static Future<List<Song>> queryAndroidMediaStore() async {
    try {
      final List<dynamic>? result = await _mediaStoreChannel.invokeMethod('queryAudioFiles');
      if (result == null || result.isEmpty) return [];

      final List<Song> songs = [];
      for (final item in result) {
        if (item is! Map) continue;
        final rawId = item['id']?.toString();
        final filePath = item['filePath']?.toString() ?? '';
        if (rawId == null || filePath.isEmpty) continue;

        songs.add(Song(
          id: 'ms_$rawId',
          title: item['title']?.toString() ?? p.basenameWithoutExtension(filePath),
          artist: item['artist']?.toString() ?? 'Unknown Artist',
          album: item['album']?.toString() ?? 'Unknown Album',
          durationMs: (item['durationMs'] as num?)?.toInt() ?? 0,
          filePath: filePath,
          fileSize: (item['fileSize'] as num?)?.toInt() ?? 0,
          folder: item['folder']?.toString() ?? 'Music',
          genre: LibraryRules.cleanGenre(item['genre']?.toString()),
          year: (item['year'] as num?)?.toInt(),
          dateAdded: (item['dateAdded'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          bitrate: ((item['bitrate'] as num?)?.toInt() ?? 0) ~/ 1000,
          albumId: (item['albumId'] as num?)?.toInt(),
          contentUri: item['contentUri']?.toString(),
        ));
      }
      return songs;
    } catch (e) {
      debugPrint('MediaStore query error: $e');
      return [];
    }
  }

  /// Walks the library roots on a background isolate.
  static List<Song> _scanFileSystem(_FsScanRequest request) {
    final found = <Song>[];
    final queue = <Directory>[
      for (final root in request.roots)
        if (Directory(root).existsSync()) Directory(root),
    ];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final dir = queue.removeLast();
      final key = LibraryRules.normalize(dir.path);
      if (!visited.add(key)) continue;
      if (LibraryRules.isAppPrivatePath(dir.path) ||
          request.excluded.any((e) => LibraryRules.isUnder(dir.path, e))) {
        continue;
      }

      List<FileSystemEntity> entities;
      try {
        entities = dir.listSync(followLinks: false);
      } catch (_) {
        continue; // unreadable folder
      }

      // Folders marked .nomedia are private to whatever app created them.
      if (entities.any((e) => e is File && p.basename(e.path).toLowerCase() == '.nomedia')) {
        continue;
      }

      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          if (name.startsWith('.') || _skipDirNames.contains(name.toLowerCase())) continue;
          queue.add(entity);
        } else if (entity is File) {
          if (name.startsWith('.')) continue;
          final ext = p.extension(name).toLowerCase();
          if (!audioExtensions.contains(ext)) continue;
          if (request.knownPaths.contains(LibraryRules.normalize(entity.path))) continue;
          final song = parseAudioFile(entity);
          if (song != null) found.add(song);
        }
      }
    }
    return found;
  }

  /// Builds a [Song] from a file's tags, falling back to the file name.
  /// Public so the integration tests can exercise real tag parsing.
  static Song? parseAudioFile(File file) {
    final path = file.path;
    final FileStat stat;
    try {
      stat = file.statSync();
    } catch (_) {
      return null;
    }
    if (stat.type != FileSystemEntityType.file || stat.size < 1024) return null;

    final ext = p.extension(path).toLowerCase();
    final baseName = p.basenameWithoutExtension(path);
    final folderName = p.basename(file.parent.path);
    final fromName = LibraryRules.parseFileName(baseName);

    String? title;
    String? artist;
    String? album;
    String? genre;
    int? year;
    int durationMs = 0;
    int bitrateKbps = 0;
    int sampleRate = 0;

    try {
      final meta = readMetadata(file, getImage: false);
      title = _clean(meta.title);
      artist = _clean(meta.artist) ?? _clean(meta.albumArtist);
      album = _clean(meta.album);
      genre = meta.genres.isNotEmpty ? meta.genres.first : null;
      year = meta.year?.year;
      durationMs = meta.duration?.inMilliseconds ?? 0;
      final bps = meta.bitrate ?? 0;
      // RIFF/WAV reports the byte rate; everything else bits per second.
      bitrateKbps = ext == '.wav' ? (bps * 8) ~/ 1000 : bps ~/ 1000;
      sampleRate = meta.sampleRate ?? 0;
    } catch (_) {
      // Unsupported container or broken tags: file-name fallback below.
    }

    return Song(
      id: LibraryRules.stableSongId(path),
      title: title ?? fromName.title,
      artist: artist ?? fromName.artist ?? 'Unknown Artist',
      album: album ?? (folderName.isNotEmpty ? folderName : 'Unknown Album'),
      durationMs: durationMs,
      filePath: path,
      fileSize: stat.size,
      folder: folderName,
      genre: LibraryRules.cleanGenre(genre),
      year: (year != null && year > 0) ? year : null,
      dateAdded: stat.modified.millisecondsSinceEpoch,
      bitrate: bitrateKbps,
      sampleRate: sampleRate,
    );
  }

  static String? _clean(String? value) {
    final v = value?.replaceAll('\x00', '').trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}

class _FsScanRequest {
  final List<String> roots;
  final List<String> excluded;
  final Set<String> knownPaths;
  const _FsScanRequest({required this.roots, required this.excluded, required this.knownPaths});
}
