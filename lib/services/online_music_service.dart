import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// A source of streamable songs from the internet.
abstract class OnlineMusicProvider {
  String get name;

  Future<List<Song>> search(String query, {int limit = 30});

  Future<List<Song>> trending({int limit = 30, String? genre});
}

/// Thrown when the provider can't be reached or answers with an error.
class OnlineMusicException implements Exception {
  final String message;
  OnlineMusicException(this.message);
  @override
  String toString() => message;
}

/// Audius (audius.co): a free, open music-sharing platform whose public API
/// needs no account or key. Only tracks the artist made streamable are used.
class AudiusProvider implements OnlineMusicProvider {
  AudiusProvider({http.Client? client}) : _client = client ?? http.Client();

  static const String _host = 'https://api.audius.co';
  static const String _app = 'FreakFM';

  final http.Client _client;

  @override
  String get name => 'Audius';

  @override
  Future<List<Song>> search(String query, {int limit = 30}) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    return _fetch('/v1/tracks/search', {'query': q, 'limit': '$limit'});
  }

  @override
  Future<List<Song>> trending({int limit = 30, String? genre}) {
    return _fetch('/v1/tracks/trending', {
      'limit': '$limit',
      'time': 'week',
      if (genre != null && genre.isNotEmpty) 'genre': genre,
    });
  }

  Future<List<Song>> _fetch(String path, Map<String, String> params) async {
    final uri = Uri.parse('$_host$path').replace(queryParameters: {...params, 'app_name': _app});
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw OnlineMusicException('Audius took too long to respond.');
    } catch (_) {
      throw OnlineMusicException('Can\'t reach Audius. Check your internet connection.');
    }
    if (response.statusCode != 200) {
      throw OnlineMusicException('Audius is unavailable right now (${response.statusCode}).');
    }
    try {
      return parseTracks(jsonDecode(utf8.decode(response.bodyBytes)));
    } catch (_) {
      throw OnlineMusicException('Audius sent an unexpected response.');
    }
  }

  /// Converts an Audius `{data: [track, ...]}` payload to songs, skipping
  /// deleted or non-streamable tracks.
  static List<Song> parseTracks(dynamic json) {
    final data = json is Map ? json['data'] : null;
    if (data is! List) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final songs = <Song>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final id = raw['id'];
      final title = raw['title'];
      if (id is! String || title is! String || title.isEmpty) continue;
      if (raw['is_delete'] == true) continue;
      final access = raw['access'];
      if (access is Map && access['stream'] == false) continue;

      final user = raw['user'];
      final artist = user is Map && user['name'] is String ? user['name'] as String : 'Unknown Artist';
      final art = raw['artwork'];
      final artUrl = art is Map ? (art['480x480'] ?? art['1000x1000'] ?? art['150x150']) : null;
      final genre = raw['genre'];

      songs.add(Song(
        id: 'audius:$id',
        title: title,
        artist: artist,
        album: 'Audius',
        durationMs: ((raw['duration'] as num?)?.toInt() ?? 0) * 1000,
        filePath: '$_host/v1/tracks/$id/stream?app_name=$_app',
        fileSize: 0,
        folder: 'Audius',
        genre: genre is String && genre.isNotEmpty ? genre : 'Music',
        dateAdded: now,
        artworkUrl: artUrl is String ? artUrl : null,
      ));
    }
    return songs;
  }
}

/// App-wide access point; tests swap [provider] for a fake.
class OnlineMusic {
  OnlineMusic._();
  static OnlineMusicProvider provider = AudiusProvider();
}
