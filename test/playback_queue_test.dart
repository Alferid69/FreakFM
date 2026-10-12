import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/playback_queue.dart';

List<Song> _songs(int n) => [
      for (var i = 0; i < n; i++)
        Song(
          id: 's$i',
          title: 'Song $i',
          artist: 'A',
          album: 'B',
          durationMs: 1000,
          filePath: '/m/$i.mp3',
          fileSize: 1,
          folder: 'm',
          genre: 'g',
          dateAdded: 0,
        ),
    ];

void main() {
  group('linear order', () {
    test('advances and stops at the end with repeat off', () {
      final q = PlaybackQueue()..setQueue(_songs(3), 0);
      expect(q.advance(AudioRepeatMode.off), 1);
      expect(q.advance(AudioRepeatMode.off), 2);
      expect(q.advance(AudioRepeatMode.off), isNull);
      expect(q.index, 2);
    });

    test('wraps with repeat all', () {
      final q = PlaybackQueue()..setQueue(_songs(2), 1);
      expect(q.advance(AudioRepeatMode.all), 0);
    });

    test('previous does not wrap when repeat is off', () {
      final q = PlaybackQueue()..setQueue(_songs(3), 0);
      expect(q.retreat(AudioRepeatMode.off), isNull);
      expect(q.retreat(AudioRepeatMode.all), 2);
    });
  });

  group('shuffle', () {
    test('plays every song exactly once per pass, starting with the current', () {
      final q = PlaybackQueue(random: Random(42))
        ..setQueue(_songs(10), 3)
        ..setShuffle(true);
      final heard = <int>[q.index];
      for (var i = 0; i < 9; i++) {
        heard.add(q.advance(AudioRepeatMode.off)!);
      }
      expect(heard.first, 3);
      expect(heard.toSet().length, 10);
      expect(q.advance(AudioRepeatMode.off), isNull);
    });

    test('previous returns to the song actually heard before', () {
      final q = PlaybackQueue(random: Random(7))
        ..setQueue(_songs(8), 0)
        ..setShuffle(true);
      final a = q.advance(AudioRepeatMode.all)!;
      final b = q.advance(AudioRepeatMode.all)!;
      expect(q.index, b);
      expect(q.retreat(AudioRepeatMode.all), a);
      expect(q.retreat(AudioRepeatMode.all), 0);
      expect(q.retreat(AudioRepeatMode.all), isNull);
    });

    test('new pass with repeat all does not repeat the last song immediately', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = PlaybackQueue(random: Random(seed))
          ..setQueue(_songs(4), 0)
          ..setShuffle(true);
        int last = q.index;
        for (var i = 0; i < 12; i++) {
          final next = q.advance(AudioRepeatMode.all)!;
          expect(next, isNot(last), reason: 'seed $seed step $i');
          last = next;
        }
      }
    });

    test('jumping to a song keeps the rest of the shuffle order', () {
      final q = PlaybackQueue(random: Random(1))
        ..setQueue(_songs(6), 0)
        ..setShuffle(true);
      q.jumpTo(5);
      expect(q.current!.id, 's5');
      final rest = <int>[];
      int? n;
      while ((n = q.advance(AudioRepeatMode.off)) != null) {
        rest.add(n!);
      }
      expect({0, 5, ...rest}.length, 6);
      expect(rest.contains(5), isFalse);
    });
  });

  group('editing', () {
    test('insertNext places the song after the current one', () {
      final q = PlaybackQueue()..setQueue(_songs(3), 1);
      final extra = _songs(4).last;
      final at = q.insertNext(extra);
      expect(at, 2);
      expect(q.advance(AudioRepeatMode.off), 2);
      expect(q.current!.id, 's3');
    });

    test('removing an earlier song keeps the current song selected', () {
      final q = PlaybackQueue()..setQueue(_songs(4), 2);
      q.removeAt(0);
      expect(q.current!.id, 's2');
      expect(q.songs.length, 3);
    });

    test('clearUpcoming leaves only the current song', () {
      final q = PlaybackQueue()..setQueue(_songs(4), 2);
      q.clearUpcoming();
      expect(q.songs.map((s) => s.id), ['s2']);
      expect(q.index, 0);
    });

    test('shuffleInPlace keeps the current song first', () {
      final q = PlaybackQueue(random: Random(3))..setQueue(_songs(6), 4);
      q.shuffleInPlace();
      expect(q.current!.id, 's4');
      expect(q.index, 0);
      expect(q.songs.length, 6);
    });
  });
}
