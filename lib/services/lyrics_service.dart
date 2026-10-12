import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/lyrics_model.dart';
import '../models/song.dart';
import 'storage_cache_service.dart';

class LyricsService {
  static final LyricsService instance = LyricsService._internal();
  LyricsService._internal();

  static const String _lyricsCacheFileName = 'freak_lyrics_cache_v1.json';

  /// How long a "no lyrics found" answer is trusted before asking again.
  static const Duration notFoundTtl = Duration(days: 7);

  final Map<String, LyricsData> _memoryCache = {};
  final ValueNotifier<LyricsData?> currentLyrics = ValueNotifier<LyricsData?>(null);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  String? _currentFetchingSongId;

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

  Future<void> _saveCacheToDisk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_lyricsCacheFileName');
      final map = <String, dynamic>{};
      _memoryCache.forEach((key, val) {
        // Persist real lyrics and "not found" answers, never network errors.
        if ((!val.isEmpty && !val.isError) || val.isNotFound) {
          map[key] = val.toJson();
        }
      });
      await StorageCacheService.writeAtomic(file, jsonEncode(map));
    } catch (e) {
      debugPrint('Error writing lyrics cache: $e');
    }
  }

  /// Cleans artist and song title to optimize match rates on free APIs
  static String cleanTrackName(String name) {
    var s = name.trim();
    // Strip leading track numbers like "01. " or "01 - "
    s = s.replaceFirst(RegExp(r'^\d{1,3}\s*[\.\-_]\s+'), '');
    // Strip parenthetical garbage: (Official Video), [Audio], etc.
    s = s.replaceAll(
      RegExp(r'\s*[\(\[](?:official|audio|video|lyrics|lyric video|remastered|explicit|deluxe|version|edit|hd|4k|hq|visualizer)[^\)\]]*[\)\]]', caseSensitive: false),
      '',
    );
    // Strip trailing feat / ft
    s = s.replaceAll(RegExp(r'\s*[\(\[]?(?:feat\.|ft\.|featuring)\s+.*$', caseSensitive: false), '');
    return s.trim();
  }

  static String cleanArtistName(String name) {
    var a = name.trim();
    if (a.toLowerCase() == 'unknown artist') return '';
    a = a.replaceAll(RegExp(r'\s*(?:feat\.|ft\.|featuring)\s+.*$', caseSensitive: false), '');
    if (a.contains(',')) {
      a = a.split(',').first.trim();
    } else if (a.contains(' & ')) {
      a = a.split(' & ').first.trim();
    }
    return a.trim();
  }

  static final RegExp _lrcTimestamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[\.:](\d{1,3}))?\]');

  /// Parses LRC text into sorted lines. Supports several timestamps per line
  /// ("[00:12.00][01:30.00]chorus"), 1–3 digit minutes and both "." and ":"
  /// fraction separators. Metadata tags like [ar:...] are ignored.
  static List<LyricLine> parseLrc(String lrc) {
    final lines = <LyricLine>[];

    for (final rawLine in const LineSplitter().convert(lrc)) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final stamps = <Duration>[];
      var rest = trimmed;
      while (true) {
        final match = _lrcTimestamp.matchAsPrefix(rest);
        if (match == null) break;
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final frac = match.group(3);
        var ms = 0;
        if (frac != null) {
          final v = int.parse(frac);
          ms = switch (frac.length) { 1 => v * 100, 2 => v * 10, _ => v };
        }
        stamps.add(Duration(minutes: min, seconds: sec, milliseconds: ms));
        rest = rest.substring(match.end).trimLeft();
      }
      if (stamps.isEmpty) continue;

      for (final t in stamps) {
        lines.add(LyricLine(timestamp: t, text: rest.trim()));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static bool looksLikeLrc(String text) => _lrcTimestamp.hasMatch(text);

  static String _normalizeForMatch(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();

  /// Picks the LRCLIB search result that best fits the song, or null when
  /// nothing is plausibly the same recording. Prefers matching artist and
  /// title, then the closest duration, then synced lyrics.
  static Map<String, dynamic>? pickBestMatch(
    List<Map<String, dynamic>> candidates, {
    required String title,
    required String artist,
    required int durationSec,
  }) {
    final wantTitle = _normalizeForMatch(title);
    final wantArtist = _normalizeForMatch(artist);

    Map<String, dynamic>? best;
    var bestScore = double.negativeInfinity;

    for (final c in candidates) {
      final synced = (c['syncedLyrics'] as String?)?.trim() ?? '';
      final plain = (c['plainLyrics'] as String?)?.trim() ?? '';
      if (synced.isEmpty && plain.isEmpty) continue;

      final cTitle = _normalizeForMatch(c['trackName'] as String? ?? '');
      final cArtist = _normalizeForMatch(c['artistName'] as String? ?? '');
      final cDuration = (c['duration'] as num?)?.toDouble() ?? 0;

      final titleMatch = cTitle == wantTitle || cTitle.contains(wantTitle) || wantTitle.contains(cTitle);
      final artistMatch = wantArtist.isEmpty ||
          cArtist.contains(wantArtist) ||
          wantArtist.contains(cArtist);
      final durationDiff = (durationSec > 0 && cDuration > 0) ? (cDuration - durationSec).abs() : null;

      // Reject results that are clearly another song.
      if (!titleMatch) continue;
      if (!artistMatch && (durationDiff == null || durationDiff > 3)) continue;
      if (durationDiff != null && durationDiff > 20) continue;

      var score = 0.0;
      if (artistMatch) score += 50;
      if (cTitle == wantTitle) score += 20;
      if (durationDiff != null) score += 30 - durationDiff.clamp(0, 30);
      if (synced.isNotEmpty) score += 10;

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  static String cacheKeyFor(Song song) => '${song.artist}__${song.title}'.toLowerCase();

  /// Loads lyrics for [song]: embedded tags first, then LRCLIB (exact, then
  /// best search match), then Lyrics.ovh. Only the most recent request may
  /// update [currentLyrics].
  Future<LyricsData> fetchLyrics(Song song, {bool forceRefresh = false}) async {
    // Claim the "current" slot first so an older in-flight request can't
    // overwrite this song's lyrics when it finishes.
    _currentFetchingSongId = song.id;
    final cacheKey = cacheKeyFor(song);

    if (!forceRefresh) {
      final cached = _memoryCache[cacheKey];
      final freshNotFound = cached != null &&
          cached.isNotFound &&
          DateTime.now().millisecondsSinceEpoch - cached.fetchedAtMs < notFoundTtl.inMilliseconds;
      if (cached != null && (!cached.isError || freshNotFound)) {
        final bound = cached.withSongId(song.id);
        currentLyrics.value = bound;
        isLoading.value = false;
        return bound;
      }
    }

    isLoading.value = true;
    if (currentLyrics.value?.songId != song.id) currentLyrics.value = null;

    try {
      final cleanTitle = cleanTrackName(song.title);
      final cleanArtist = cleanArtistName(song.artist);

      LyricsData? result = await _tryEmbedded(song);
      result ??= await _tryLrcLibGet(song, cleanTitle, cleanArtist);
      result ??= await _tryLrcLibSearch(song, cleanTitle, cleanArtist);
      result ??= await _tryLyricsOvh(song, cleanTitle, cleanArtist);

      final LyricsData outcome;
      if (result != null && !result.isEmpty) {
        outcome = result;
      } else {
        outcome = LyricsData.empty(
          song.id,
          song.title,
          song.artist,
          message: 'No lyrics found for "${song.title}"',
          notFound: true,
        );
      }
      _memoryCache[cacheKey] = outcome;
      unawaited(_saveCacheToDisk());
      if (_currentFetchingSongId == song.id) currentLyrics.value = outcome;
      return outcome;
    } on _NetworkFailure {
      final err = LyricsData.empty(
        song.id,
        song.title,
        song.artist,
        message: 'Could not reach the lyrics servers. Check your connection.',
      );
      if (_currentFetchingSongId == song.id) currentLyrics.value = err;
      return err;
    } finally {
      if (_currentFetchingSongId == song.id) isLoading.value = false;
    }
  }

  Future<LyricsData?> _tryEmbedded(Song song) async {
    final path = song.filePath;
    if (kIsWeb || path.isEmpty || path.startsWith('content://')) return null;
    try {
      final text = await Isolate.run(() {
        final f = File(path);
        if (!f.existsSync()) return null;
        return readMetadata(f).lyrics;
      });
      if (text == null || text.trim().isEmpty) return null;
      final synced = looksLikeLrc(text) ? parseLrc(text) : <LyricLine>[];
      return LyricsData(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        plainLyrics: synced.isEmpty ? text.trim() : synced.map((l) => l.text).join('\n'),
        syncedLines: synced,
        source: 'Embedded in file',
        isSynced: synced.isNotEmpty,
      );
    } catch (_) {
      return null;
    }
  }

  /// Performs an HTTP GET. Returns null for a non-200 answer and throws
  /// [_NetworkFailure] when the server can't be reached at all.
  Future<String?> _httpGet(Uri uri) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'FreakPlayer/1.1 (offline music player)');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        return await resp.transform(utf8.decoder).join();
      }
      await resp.drain<void>();
      return null;
    } on SocketException {
      throw const _NetworkFailure();
    } on TimeoutException {
      throw const _NetworkFailure();
    } on HandshakeException {
      throw const _NetworkFailure();
    } finally {
      client?.close(force: true);
    }
  }

  Future<LyricsData?> _tryLrcLibGet(Song song, String cleanTitle, String cleanArtist) async {
    if (cleanTitle.isEmpty || cleanArtist.isEmpty || song.durationMs <= 0) return null;

    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': cleanTitle,
      'artist_name': cleanArtist,
      if (song.album.isNotEmpty && !song.album.toLowerCase().contains('unknown')) 'album_name': song.album,
      'duration': (song.durationMs / 1000).round().toString(),
    });
    final jsonStr = await _httpGet(uri);
    if (jsonStr == null) return null;

    try {
      return _buildLyricsDataFromLrcLib(song, jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<LyricsData?> _tryLrcLibSearch(Song song, String cleanTitle, String cleanArtist) async {
    if (cleanTitle.isEmpty) return null;

    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': cleanTitle,
      if (cleanArtist.isNotEmpty) 'artist_name': cleanArtist,
    });
    final jsonStr = await _httpGet(uri);
    if (jsonStr == null) return null;

    try {
      final list = (jsonDecode(jsonStr) as List<dynamic>).whereType<Map<String, dynamic>>().toList();
      final best = pickBestMatch(
        list,
        title: cleanTitle,
        artist: cleanArtist,
        durationSec: (song.durationMs / 1000).round(),
      );
      return best == null ? null : _buildLyricsDataFromLrcLib(song, best);
    } catch (_) {
      return null;
    }
  }

  LyricsData? _buildLyricsDataFromLrcLib(Song song, Map<String, dynamic> data) {
    final syncedLrc = data['syncedLyrics'] as String?;
    final plain = data['plainLyrics'] as String?;

    if ((syncedLrc == null || syncedLrc.trim().isEmpty) && (plain == null || plain.trim().isEmpty)) {
      return null;
    }

    final lines = (syncedLrc != null && syncedLrc.isNotEmpty) ? parseLrc(syncedLrc) : <LyricLine>[];

    return LyricsData(
      songId: song.id,
      title: (data['trackName'] as String?) ?? song.title,
      artist: (data['artistName'] as String?) ?? song.artist,
      plainLyrics: plain,
      syncedLines: lines,
      source: 'LRCLIB',
      isSynced: lines.isNotEmpty,
    );
  }

  Future<LyricsData?> _tryLyricsOvh(Song song, String cleanTitle, String cleanArtist) async {
    if (cleanTitle.isEmpty || cleanArtist.isEmpty) return null;

    final uri = Uri.parse(
      'https://api.lyrics.ovh/v1/${Uri.encodeComponent(cleanArtist)}/${Uri.encodeComponent(cleanTitle)}',
    );
    final String? jsonStr;
    try {
      jsonStr = await _httpGet(uri);
    } on _NetworkFailure {
      return null; // secondary source; LRCLIB already answered
    }
    if (jsonStr == null) return null;

    try {
      final lyrics = (jsonDecode(jsonStr) as Map<String, dynamic>)['lyrics'] as String?;
      if (lyrics != null && lyrics.trim().isNotEmpty) {
        return LyricsData(
          songId: song.id,
          title: song.title,
          artist: song.artist,
          plainLyrics: lyrics.trim(),
          source: 'Lyrics.ovh',
          isSynced: false,
        );
      }
    } catch (_) {}
    return null;
  }
}

class _NetworkFailure implements Exception {
  const _NetworkFailure();
}
