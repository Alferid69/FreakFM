import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class StorageCacheService {
  static const String _cacheFileName = 'freak_music_cache_v2.json';
  static const String _playlistsFileName = 'freak_playlists_v1.json';
  static const String _prefCustomDirs = 'pref_custom_scan_dirs';
  static const String _prefExcludedDirs = 'pref_excluded_scan_dirs';
  static const String _prefScannerVersion = 'pref_scanner_version';

  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  static Future<File> _getPlaylistsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_playlistsFileName');
  }

  /// Writes [content] to a sibling temp file and renames it over [file], so a
  /// crash or kill mid-write never leaves a truncated/corrupt cache behind.
  static Future<void> writeAtomic(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  }

  static Future<List<Song>?> loadCachedSongs() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      final decoded = jsonDecode(content) as List<dynamic>;
      return decoded
          .map((item) => Song.fromJson(item as Map<String, dynamic>))
          // Drop entries left over from the old synthetic benchmark library.
          .where(_isRealSong)
          .toList();
    } catch (e) {
      debugPrint('Error loading cached songs: $e');
      return null;
    }
  }

  static bool _isRealSong(Song song) => song.id.isNotEmpty && !song.id.startsWith('bench_track_');

  static Future<void> saveCachedSongs(List<Song> songs) async {
    try {
      final file = await _getCacheFile();
      final content = jsonEncode(songs.map((s) => s.toJson()).toList());
      await writeAtomic(file, content);
    } catch (e) {
      debugPrint('Error saving cached songs: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  static Future<List<Playlist>> loadPlaylists() async {
    try {
      final file = await _getPlaylistsFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final decoded = jsonDecode(content) as List<dynamic>;
      return decoded.map((item) => Playlist.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      return [];
    }
  }

  static Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      final file = await _getPlaylistsFile();
      await writeAtomic(file, jsonEncode(playlists.map((p) => p.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  /// Extra folders the user added to the library.
  static Future<void> saveCustomDirectories(List<String> dirs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefCustomDirs, dirs);
  }

  static Future<List<String>> loadCustomDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefCustomDirs) ?? [];
  }

  /// Folders the user hid from the library; nothing below them is indexed.
  static Future<void> saveExcludedDirectories(List<String> dirs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefExcludedDirs, dirs);
  }

  static Future<List<String>> loadExcludedDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefExcludedDirs) ?? [];
  }

  /// Version of the scanning rules the cached library was built with.
  static Future<int> loadScannerVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefScannerVersion) ?? 1;
  }

  static Future<void> saveScannerVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefScannerVersion, version);
  }
}
