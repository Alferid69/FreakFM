import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/lyrics_model.dart';
import '../models/song.dart';

class LyricsService {
  static final LyricsService instance = LyricsService._internal();
  LyricsService._internal();

  static const String _lyricsCacheFileName = 'freak_lyrics_cache_v1.json';

  final Map<String, LyricsData> _memoryCache = {};
  final ValueNotifier<LyricsData?> currentLyrics = ValueNotifier<LyricsData?>(null);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  String? _currentFetchingSongId;

  /// Loads persistent lyrics cache from disk
  Future<void> initCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_lyricsCacheFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          decoded.forEach((key, val) {
            if (val is Map<String, dynamic>) {
              _memoryCache[key] = LyricsData.fromJson(val);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error reading lyrics cache: $e');
    }
  }

  /// Persists lyrics cache to disk
  Future<void> _saveCacheToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_lyricsCacheFileName');
      final map = <String, dynamic>{};
      _memoryCache.forEach((key, val) {
        if (!val.isEmpty && !val.isError) {
          map[key] = val.toJson();
        }
      });
      await file.writeAsString(jsonEncode(map), flush: false);
    } catch (e) {
      debugPrint('Error writing lyrics cache: $e');
    }
  }

  /// Cleans artist and song title to optimize match rates on free APIs
  static String cleanTrackName(String name) {
    var s = name.trim();
    // Strip leading track numbers like "01. " or "01 - "
    s = s.replaceFirst(RegExp(r'^\d{1,3}[\s\.\-_]+'), '');
    // Strip parenthetical garbage: (Official Video), [Audio], etc.
    s = s.replaceAll(
      RegExp(r'\s*[\(\[](?:official|audio|video|lyrics|lyric video|remastered|explicit|deluxe|version|edit|hd|4k|hq|visualizer)[^\)\]]*[\)\]]', caseSensitive: false),
      '',
    );
    // Strip trailing feat / ft
    s = s.replaceAll(RegExp(r'\s*(?:feat\.|ft\.|featuring)\s+.*$', caseSensitive: false), '');
    return s.trim();
  }

  static String cleanArtistName(String name) {
    var a = name.trim();
    if (a.toLowerCase() == 'unknown artist') return '';
    // Strip featuring
    a = a.replaceAll(RegExp(r'\s*(?:feat\.|ft\.|featuring)\s+.*$', caseSensitive: false), '');
    // If multi-artist like "Artist1, Artist2" or "Artist1 & Artist2", grab primary
    if (a.contains(',')) {
      a = a.split(',').first.trim();
    } else if (a.contains(' & ')) {
      a = a.split(' & ').first.trim();
    }
    return a.trim();
  }

  /// Parses LRC string into a list of sorted LyricLine instances
  static List<LyricLine> parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'^\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)$');

    for (final rawLine in const LineSplitter().convert(lrc)) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final match = regExp.firstMatch(trimmed);
      if (match != null) {
        final min = int.tryParse(match.group(1)!) ?? 0;
        final sec = int.tryParse(match.group(2)!) ?? 0;
        final msStr = match.group(3);
        int ms = 0;
        if (msStr != null) {
          final parsed = int.tryParse(msStr) ?? 0;
          ms = msStr.length == 2 ? parsed * 10 : parsed;
        }

        final text = match.group(4)?.trim() ?? '';
        lines.add(LyricLine(
          timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
          text: text,
        ));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Fetches lyrics for the given song, prioritizing LRCLIB then Lyrics.ovh
  Future<LyricsData> fetchLyrics(Song song, {bool forceRefresh = false}) async {
    final cacheKey = '${song.artist}__${song.title}'.toLowerCase();

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (!cached.isError) {
        currentLyrics.value = cached;
        return cached;
      }
    }

    _currentFetchingSongId = song.id;
    isLoading.value = true;

    try {
      final cleanTitle = cleanTrackName(song.title);
      final cleanArtist = cleanArtistName(song.artist);

      // 1. Try LRCLIB exact get
      LyricsData? result = await _tryLrcLibGet(song, cleanTitle, cleanArtist);

      // 2. Try LRCLIB search
      result ??= await _tryLrcLibSearch(song, cleanTitle, cleanArtist);

      // 3. Try Lyrics.ovh fallback (for plain lyrics)
      result ??= await _tryLyricsOvh(song, cleanTitle, cleanArtist);

      if (result != null && !result.isEmpty) {
        _memoryCache[cacheKey] = result;
        _saveCacheToDisk();
        if (_currentFetchingSongId == song.id) {
          currentLyrics.value = result;
        }
        return result;
      }

      final notFound = LyricsData.empty(
        song.id,
        song.title,
        song.artist,
        message: 'No lyrics found online for "${song.title}"',
      );
      _memoryCache[cacheKey] = notFound;
      if (_currentFetchingSongId == song.id) {
        currentLyrics.value = notFound;
      }
      return notFound;
    } catch (e) {
      final err = LyricsData.empty(
        song.id,
        song.title,
        song.artist,
        message: 'Could not connect to lyrics server: $e',
      );
      if (_currentFetchingSongId == song.id) {
        currentLyrics.value = err;
      }
      return err;
    } finally {
      if (_currentFetchingSongId == song.id) {
        isLoading.value = false;
      }
    }
  }

  /// Internal helper to perform HTTP GET requests safely
  Future<String?> _httpGet(Uri uri) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'FreakPlayer/1.0 (https://github.com/freak-player)');
      final resp = await req.close().timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        return body;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<LyricsData?> _tryLrcLibGet(Song song, String cleanTitle, String cleanArtist) async {
    if (cleanTitle.isEmpty) return null;

    final queryParams = <String, String>{
      'track_name': cleanTitle,
      if (cleanArtist.isNotEmpty) 'artist_name': cleanArtist,
      if (song.album.isNotEmpty && !song.album.toLowerCase().contains('unknown'))
        'album_name': song.album,
      if (song.durationMs > 0)
        'duration': (song.durationMs / 1000).round().toString(),
    };

    final uri = Uri.https('lrclib.net', '/api/get', queryParams);
    final jsonStr = await _httpGet(uri);
    if (jsonStr == null) return null;

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _buildLyricsDataFromLrcLib(song, data);
    } catch (_) {
      return null;
    }
  }

  Future<LyricsData?> _tryLrcLibSearch(Song song, String cleanTitle, String cleanArtist) async {
    if (cleanTitle.isEmpty) return null;

    final query = cleanArtist.isNotEmpty ? '$cleanArtist $cleanTitle' : cleanTitle;
    final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
    final jsonStr = await _httpGet(uri);
    if (jsonStr == null) return null;

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      if (list.isEmpty) return null;

      final first = list.first as Map<String, dynamic>;
      return _buildLyricsDataFromLrcLib(song, first);
    } catch (_) {
      return null;
    }
  }

  LyricsData? _buildLyricsDataFromLrcLib(Song song, Map<String, dynamic> data) {
    final syncedLrc = data['syncedLyrics'] as String?;
    final plain = data['plainLyrics'] as String?;

    if ((syncedLrc == null || syncedLrc.trim().isEmpty) &&
        (plain == null || plain.trim().isEmpty)) {
      return null;
    }

    List<LyricLine> lines = [];
    if (syncedLrc != null && syncedLrc.isNotEmpty) {
      lines = parseLrc(syncedLrc);
    }

    return LyricsData(
      songId: song.id,
      title: (data['trackName'] as String?) ?? song.title,
      artist: (data['artistName'] as String?) ?? song.artist,
      plainLyrics: plain,
      syncedLines: lines,
      source: 'LRCLIB (Free & Synced)',
      isSynced: lines.isNotEmpty,
    );
  }

  Future<LyricsData?> _tryLyricsOvh(Song song, String cleanTitle, String cleanArtist) async {
    if (cleanTitle.isEmpty || cleanArtist.isEmpty) return null;

    final encodedArtist = Uri.encodeComponent(cleanArtist);
    final encodedTitle = Uri.encodeComponent(cleanTitle);
    final uri = Uri.parse('https://api.lyrics.ovh/v1/$encodedArtist/$encodedTitle');

    final jsonStr = await _httpGet(uri);
    if (jsonStr == null) return null;

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final lyrics = data['lyrics'] as String?;
      if (lyrics != null && lyrics.trim().isNotEmpty) {
        return LyricsData(
          songId: song.id,
          title: song.title,
          artist: song.artist,
          plainLyrics: lyrics.trim(),
          source: 'Lyrics.ovh (Free)',
          isSynced: false,
        );
      }
    } catch (_) {}

    return null;
  }
}
