import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('LyricsService Tests', () {
    test('Track and artist cleaning logic', () {
      expect(
        LyricsService.cleanTrackName('01 - God\'s Plan (Official Music Video)'),
        equals('God\'s Plan'),
      );
      expect(
        LyricsService.cleanTrackName('Mockingbird [Explicit Audio]'),
        equals('Mockingbird'),
      );
      expect(
        LyricsService.cleanTrackName('03. Starboy feat. Daft Punk'),
        equals('Starboy'),
      );

      expect(
        LyricsService.cleanArtistName('Drake & 21 Savage'),
        equals('Drake'),
      );
      expect(
        LyricsService.cleanArtistName('Post Malone feat. Swae Lee'),
        equals('Post Malone'),
      );
    });

    test('LRC parsing logic', () {
      const lrc = '''
[00:04.27] Yeah, they wishin' and wishin'
[00:07.48] They wishin' on me, yuh
[00:12.33] I been movin' calm
''';
      final lines = LyricsService.parseLrc(lrc);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals("Yeah, they wishin' and wishin'"));
      expect(lines[0].timestamp.inMilliseconds, equals(4270));
      expect(lines[1].timestamp.inMilliseconds, equals(7480));
    });

    test('LRC parsing handles multiple stamps, short minutes and metadata', () {
      const lrc = '''
[ar:Someone]
[ti:Song]
[00:01.5]one
[0:03.25][01:02.003]chorus
[1:10:50]colon fraction
not a lyric line
''';
      final lines = LyricsService.parseLrc(lrc);
      expect(lines.map((l) => l.text), ['one', 'chorus', 'chorus', 'colon fraction']);
      expect(lines[0].timestamp.inMilliseconds, 1500);
      expect(lines[1].timestamp.inMilliseconds, 3250);
      expect(lines[2].timestamp.inMilliseconds, 62003);
      expect(lines[3].timestamp.inMilliseconds, 70500);
    });

    test('Search picks the matching recording, not the first result', () {
      final candidates = <Map<String, dynamic>>[
        {'trackName': 'Mockingbird', 'artistName': 'Some Cover Band', 'duration': 180.0, 'plainLyrics': 'x'},
        {'trackName': 'Mockingbird', 'artistName': 'Eminem', 'duration': 251.0, 'plainLyrics': 'y'},
        {'trackName': 'Mockingbird', 'artistName': 'Eminem', 'duration': 250.0, 'syncedLyrics': '[00:01.00]z'},
      ];
      final best = LyricsService.pickBestMatch(candidates, title: 'Mockingbird', artist: 'Eminem', durationSec: 250);
      expect(best?['syncedLyrics'], '[00:01.00]z');
    });

    test('Search rejects results that are clearly another song', () {
      final candidates = <Map<String, dynamic>>[
        {'trackName': 'Different Song', 'artistName': 'Eminem', 'duration': 250.0, 'plainLyrics': 'x'},
        {'trackName': 'Mockingbird', 'artistName': 'Other', 'duration': 120.0, 'plainLyrics': 'y'},
      ];
      expect(
        LyricsService.pickBestMatch(candidates, title: 'Mockingbird', artist: 'Eminem', durationSec: 250),
        isNull,
      );
    });

    test('Live fetch from free source (LRCLIB)', tags: ['network'], () async {
      final song = Song(
        id: 'mockingbird',
        title: 'Mockingbird',
        artist: 'Eminem',
        album: 'Encore',
        durationMs: 250000,
        filePath: 'test/path.mp3',
        fileSize: 1000000,
        folder: 'Music',
        genre: 'Hip-Hop / Rap',
        dateAdded: 0,
      );

      final result = await LyricsService.instance.fetchLyrics(song);
      expect(result.isEmpty, isFalse);
      expect(result.source, contains('LRCLIB'));
      expect(result.syncedLines.isNotEmpty || result.plainLyrics != null, isTrue);
    });
  });
}
