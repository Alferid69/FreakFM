import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/library_rules.dart';

Song _song(String id, String path, {bool fav = false, int plays = 0, int added = 1000, int duration = 0}) => Song(
      id: id,
      title: id,
      artist: 'a',
      album: 'b',
      durationMs: duration,
      filePath: path,
      fileSize: 1,
      folder: 'f',
      genre: 'g',
      dateAdded: added,
      isFavorite: fav,
      playCount: plays,
    );

void main() {
  const roots = ['/storage/emulated/0/Music', '/storage/emulated/0/Download'];

  group('isInLibrary', () {
    test('accepts files inside library roots', () {
      expect(LibraryRules.isInLibrary('/storage/emulated/0/Music/a.mp3', roots, []), isTrue);
      expect(LibraryRules.isInLibrary('/storage/emulated/0/Download/x/y.flac', roots, []), isTrue);
    });

    test('rejects audio cached by other apps (e.g. a Quran app)', () {
      // Outside any library root.
      expect(
        LibraryRules.isInLibrary('/storage/emulated/0/quran_android/audio/5/001.mp3', roots, []),
        isFalse,
      );
      // App-specific storage, even when nested under a root-like folder name.
      expect(
        LibraryRules.isInLibrary(
          '/storage/emulated/0/Android/data/com.quran.labs.androidquran/files/audio/001001.mp3',
          ['/storage/emulated/0'],
          [],
        ),
        isFalse,
      );
      expect(
        LibraryRules.isInLibrary(
          '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio/a.opus',
          ['/storage/emulated/0'],
          [],
        ),
        isFalse,
      );
    });

    test('rejects hidden folders and user-excluded folders', () {
      expect(LibraryRules.isInLibrary('/storage/emulated/0/Music/.cache/a.mp3', roots, []), isFalse);
      expect(
        LibraryRules.isInLibrary(
          '/storage/emulated/0/Download/Recitations/001.mp3',
          roots,
          ['/storage/emulated/0/Download/Recitations'],
        ),
        isFalse,
      );
    });

    test('folder prefix must match a whole path segment', () {
      expect(LibraryRules.isUnder('/music/rock2/a.mp3', '/music/rock'), isFalse);
      expect(LibraryRules.isUnder('/music/rock/a.mp3', '/music/rock'), isTrue);
    });

    test('works with Windows paths case-insensitively', () {
      expect(
        LibraryRules.isInLibrary(r'C:\Users\me\Music\Album\song.mp3', [r'C:\Users\Me\music'], []),
        isTrue,
      );
    });
  });

  group('stableSongId', () {
    test('is deterministic and path-normalised', () {
      final a = LibraryRules.stableSongId('/storage/emulated/0/Music/a.mp3');
      expect(a, LibraryRules.stableSongId('/storage/emulated/0/Music/a.mp3'));
      expect(a, LibraryRules.stableSongId('/storage/emulated/0/Music/a.mp3/'));
      expect(a, startsWith('f_'));
      expect(a.length, 18);
      expect(a, isNot(LibraryRules.stableSongId('/storage/emulated/0/Music/b.mp3')));
    });

    test('matches the reference FNV-1a 64-bit value', () {
      // FNV-1a 64 of "a" is af63dc4c8601ec8c.
      expect(LibraryRules.stableSongId('a'), 'f_af63dc4c8601ec8c');
    });
  });

  group('parseFileName', () {
    test('splits "Artist - Title" and strips track numbers', () {
      final r = LibraryRules.parseFileName('01 - Drake - God\'s Plan');
      expect(r.artist, 'Drake');
      expect(r.title, 'God\'s Plan');
    });

    test('keeps numbers that are part of the title', () {
      expect(LibraryRules.parseFileName('7 Rings').title, '7 Rings');
      expect(LibraryRules.parseFileName('99 Problems').title, '99 Problems');
      expect(LibraryRules.parseFileName('1999').title, '1999');
      expect(LibraryRules.parseFileName('50 Cent - In Da Club').artist, '50 Cent');
    });

    test('strips zero-padded track numbers', () {
      expect(LibraryRules.parseFileName('03 Starboy').title, 'Starboy');
      expect(LibraryRules.parseFileName('12. Intro').title, 'Intro');
    });
  });

  group('cleanGenre', () {
    test('maps numeric ID3 genres', () {
      expect(LibraryRules.cleanGenre('(17)'), 'Rock');
      expect(LibraryRules.cleanGenre('13'), 'Pop');
      expect(LibraryRules.cleanGenre('(17)Rock'), 'Rock');
    });

    test('normalises families and casing', () {
      expect(LibraryRules.cleanGenre('hip hop'), 'Hip-Hop / Rap');
      expect(LibraryRules.cleanGenre('Trap'), 'Hip-Hop / Rap');
      expect(LibraryRules.cleanGenre('rnb'), 'R&B');
      expect(LibraryRules.cleanGenre('EDM'), 'Dance & Electronic');
      expect(LibraryRules.cleanGenre('JAZZ'), 'Jazz');
    });

    test('does not misfire on substrings', () {
      expect(LibraryRules.cleanGenre('Grapefruit Pop'), isNot('Hip-Hop / Rap'));
    });

    test('empty and null-padded values fall back to Music', () {
      expect(LibraryRules.cleanGenre(null), 'Music');
      expect(LibraryRules.cleanGenre('\x00\x00'), 'Music');
    });
  });

  group('mergeWithPrevious', () {
    test('keeps favourites, play counts and first-seen dates across rescans', () {
      final previous = [_song('old1', '/m/a.mp3', fav: true, plays: 7, added: 100, duration: 200000)];
      final scanned = [_song('new1', '/m/a.mp3', added: 999), _song('new2', '/m/b.mp3')];

      final merged = LibraryRules.mergeWithPrevious(previous, scanned);

      expect(merged.first.isFavorite, isTrue);
      expect(merged.first.playCount, 7);
      expect(merged.first.dateAdded, 100);
      expect(merged.first.durationMs, 200000);
      expect(merged[1].isFavorite, isFalse);
    });

    test('dedupeByPath keeps the first entry per file', () {
      final out = LibraryRules.dedupeByPath([
        _song('ms_1', '/m/a.mp3'),
        _song('f_x', '/M/A.mp3'),
        _song('f_y', '/m/b.mp3'),
      ]);
      expect(out.map((s) => s.id), ['ms_1', 'f_y']);
    });
  });
}
