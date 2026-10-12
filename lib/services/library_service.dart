import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'library_rules.dart';
import 'music_scanner_service.dart';
import 'storage_cache_service.dart';

enum ScanOutcome { success, permissionDenied, failed }

/// Single source of truth for the music library. Owns persistence of user
/// state (favourites, play counts, learned durations) so every screen and
/// the player can change it without each having to remember to save.
class LibraryService {
  static final LibraryService instance = LibraryService._();
  LibraryService._();

  /// Replaced when the song list itself changes (load/scan/hide).
  final ValueNotifier<List<Song>> songs = ValueNotifier<List<Song>>(const []);

  /// Bumped when songs change in place (favourite, play count, duration).
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);

  Timer? _saveTimer;
  Future<ScanOutcome>? _activeScan;

  static const Duration _saveDelay = Duration(milliseconds: 800);

  /// Bump when scanning rules change so existing libraries rescan once.
  static const int scannerVersion = 2;

  /// True when the cached library was built by older scanning rules.
  Future<bool> isScanOutdated() async =>
      await StorageCacheService.loadScannerVersion() < scannerVersion;

  /// Loads the cached library. Returns false when there is no cache yet.
  Future<bool> loadFromCache() async {
    final cached = await StorageCacheService.loadCachedSongs();
    if (cached == null || cached.isEmpty) return false;
    songs.value = cached;
    return true;
  }

  /// Rescans storage. User state from the current library is carried over,
  /// and the existing library is kept untouched if permission is missing or
  /// the scan fails.
  Future<ScanOutcome> rescan({bool requestPermission = true}) {
    return _activeScan ??= _rescan(requestPermission).whenComplete(() => _activeScan = null);
  }

  Future<ScanOutcome> _rescan(bool requestPermission) async {
    isScanning.value = true;
    try {
      final granted = requestPermission
          ? await MusicScannerService.requestStoragePermissions()
          : await MusicScannerService.hasStoragePermission();
      if (!granted) return ScanOutcome.permissionDenied;

      final result = await MusicScannerService.scanLibrary();
      // Use the saved copy too, in case the library hasn't been loaded yet.
      final previous = songs.value.isNotEmpty
          ? songs.value
          : (await StorageCacheService.loadCachedSongs() ?? const <Song>[]);
      final merged = LibraryRules.mergeWithPrevious(previous, result.songs);

      songs.value = merged;
      await flush();
      await StorageCacheService.saveScannerVersion(scannerVersion);
      return ScanOutcome.success;
    } catch (e) {
      debugPrint('Library rescan failed: $e');
      return ScanOutcome.failed;
    } finally {
      isScanning.value = false;
    }
  }

  /// Replaces the library wholesale (used by tests and first-run seeding).
  Future<void> setSongs(List<Song> newSongs) async {
    songs.value = List<Song>.unmodifiable(newSongs);
    await flush();
  }

  void toggleFavorite(Song song) {
    final value = !song.isFavorite;
    _updateEverywhere(song, (s) => s.isFavorite = value);
  }

  void recordPlay(Song song) {
    final count = song.playCount + 1;
    _updateEverywhere(song, (s) => s.playCount = count);
  }

  /// Stores the real duration reported by the player, replacing metadata
  /// estimates so sorting and lyric matching use accurate values.
  void updateDuration(Song song, Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0 || (song.durationMs - ms).abs() < 1000) return;
    _updateEverywhere(song, (s) => s.durationMs = ms);
  }

  /// Hides a folder: its songs leave the library and future scans skip it.
  Future<void> hideFolder(String folderPath) async {
    final excluded = await StorageCacheService.loadExcludedDirectories();
    if (!excluded.any((e) => LibraryRules.normalize(e) == LibraryRules.normalize(folderPath))) {
      await StorageCacheService.saveExcludedDirectories([...excluded, folderPath]);
    }
    final custom = await StorageCacheService.loadCustomDirectories();
    final remaining = custom.where((d) => !LibraryRules.isUnder(d, folderPath)).toList();
    if (remaining.length != custom.length) {
      await StorageCacheService.saveCustomDirectories(remaining);
    }
    songs.value = songs.value.where((s) => !LibraryRules.isUnder(s.filePath, folderPath)).toList();
    await flush();
  }

  Future<void> unhideFolder(String folderPath) async {
    final excluded = await StorageCacheService.loadExcludedDirectories();
    await StorageCacheService.saveExcludedDirectories(
      excluded.where((e) => LibraryRules.normalize(e) != LibraryRules.normalize(folderPath)).toList(),
    );
  }

  Future<void> addFolder(String folderPath) async {
    final custom = await StorageCacheService.loadCustomDirectories();
    if (!custom.any((d) => LibraryRules.normalize(d) == LibraryRules.normalize(folderPath))) {
      await StorageCacheService.saveCustomDirectories([...custom, folderPath]);
    }
    await unhideFolder(folderPath);
  }

  Future<void> removeFolder(String folderPath) async {
    final custom = await StorageCacheService.loadCustomDirectories();
    await StorageCacheService.saveCustomDirectories(
      custom.where((d) => LibraryRules.normalize(d) != LibraryRules.normalize(folderPath)).toList(),
    );
  }

  /// Writes any pending changes immediately.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await StorageCacheService.saveCachedSongs(songs.value);
  }

  void _updateEverywhere(Song song, void Function(Song s) update) {
    update(song);
    // The player or a filtered view may hold a different object for the same
    // track (e.g. after a rescan); keep the library copy in sync too.
    for (final s in songs.value) {
      if (!identical(s, song) && s.id == song.id) update(s);
    }
    revision.value++;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, () {
      _saveTimer = null;
      StorageCacheService.saveCachedSongs(songs.value);
    });
  }
}
