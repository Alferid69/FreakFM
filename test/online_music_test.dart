import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/online_music_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _track(String id, {String title = 'Track', bool streamable = true, bool deleted = false}) => {
      'id': id,
      'title': title,
      'duration': 95,
      'genre': 'Electronic',
      'is_delete': deleted,
      'access': {'stream': streamable, 'download': false},
      'user': {'name': 'Some Artist'},
      'artwork': {'150x150': 'https://img/150.jpg', '480x480': 'https://img/480.jpg'},
    };

void main() {
  test('maps Audius tracks to streamable songs', () {
    final songs = AudiusProvider.parseTracks({
      'data': [_track('abc', title: 'Hello')],
    });
    expect(songs, hasLength(1));
    final s = songs.single;
    expect(s.id, 'audius:abc');
    expect(s.title, 'Hello');
    expect(s.artist, 'Some Artist');
    expect(s.durationMs, 95000);
    expect(s.isOnline, isTrue);
    expect(s.filePath, contains('/v1/tracks/abc/stream'));
    expect(s.artworkUrl, 'https://img/480.jpg');
  });

  test('skips deleted, locked and malformed tracks', () {
    final songs = AudiusProvider.parseTracks({
      'data': [
        _track('a', deleted: true),
        _track('b', streamable: false),
        {'id': 'c'},
        'nonsense',
        _track('d'),
      ],
    });
    expect([for (final s in songs) s.id], ['audius:d']);
    expect(AudiusProvider.parseTracks({'nothing': 1}), isEmpty);
  });

  test('search sends the query and returns songs', () async {
    late Uri requested;
    final provider = AudiusProvider(
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({'data': [_track('x', title: 'Found')]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final songs = await provider.search('lo fi');
    expect(requested.path, '/v1/tracks/search');
    expect(requested.queryParameters['query'], 'lo fi');
    expect(songs.single.title, 'Found');
    expect(await provider.search('   '), isEmpty);
  });

  test('reports failures as OnlineMusicException', () async {
    final down = AudiusProvider(client: MockClient((_) async => http.Response('', 503)));
    expect(down.trending(), throwsA(isA<OnlineMusicException>()));
    final offline = AudiusProvider(client: MockClient((_) async => throw http.ClientException('no network')));
    expect(offline.search('x'), throwsA(isA<OnlineMusicException>()));
  });

  test('online songs survive a JSON round trip', () {
    final s = AudiusProvider.parseTracks({'data': [_track('q')]}).single;
    final back = Song.fromJson(s.toJson());
    expect(back.isOnline, isTrue);
    expect(back.artworkUrl, s.artworkUrl);
  });
}
