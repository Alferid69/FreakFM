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

    test('Live fetch from free source (LRCLIB)', () async {
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
