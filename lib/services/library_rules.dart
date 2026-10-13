import '../models/song.dart';

/// Pure, platform-independent library rules: path matching for hidden
/// folders, stable ids, tag clean-up, and merging scans with saved state.
/// Kept free of Flutter/IO so they can be unit tested directly.
class LibraryRules {
  LibraryRules._();

  /// Normalises a path for comparisons: forward slashes, lowercase, no
  /// trailing slash.
  static String normalize(String path) {
    var s = path.replaceAll('\\', '/').toLowerCase();
    while (s.length > 1 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// True when [path] is [root] itself or lives somewhere below it.
  static bool isUnder(String path, String root) {
    final np = normalize(path);
    final nr = normalize(root);
    if (nr.isEmpty) return false;
    return np == nr || np.startsWith('$nr/');
  }

  /// True when [path] is inside a folder the user chose to hide.
  static bool isExcluded(String path, List<String> excluded) =>
      excluded.any((e) => isUnder(path, e));

  /// Stable id derived from the file path (64-bit FNV-1a). Unlike
  /// String.hashCode this is identical across runs and platforms.
  static String stableSongId(String path) {
    final bytes = normalize(path).codeUnits;
    // FNV-1a over UTF-16 code units, computed in two 32-bit halves so no
    // intermediate value overflows a 64-bit int.
    var hi = 0xcbf29ce4, lo = 0x84222325;
    for (final b in bytes) {
      lo ^= b;
      // multiply (hi:lo) by FNV prime 0x100000001b3
      final loMul = lo * 0x1b3;
      final newLo = loMul & 0xffffffff;
      final carry = (loMul - newLo) ~/ 0x100000000;
      final newHi = (hi * 0x1b3 + (lo << 8) + carry) & 0xffffffff;
      hi = newHi;
      lo = newLo;
    }
    return 'f_${hi.toRadixString(16).padLeft(8, '0')}${lo.toRadixString(16).padLeft(8, '0')}';
  }

  /// Derives title/artist from a file name such as "01 - Artist - Title".
  /// Leading track numbers are only stripped here, never from tag titles.
  static ({String title, String? artist}) parseFileName(String baseName) {
    var name = baseName.trim();
    final numMatch = RegExp(r'^\d{1,3}\s*[\.\-_)]\s*|^0\d{1,2}\s+(?=\D)').firstMatch(name);
    if (numMatch != null && numMatch.end < name.length) {
      name = name.substring(numMatch.end).trim();
    }
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      final artist = parts.first.trim();
      final title = parts.sublist(1).join(' - ').trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return (title: title, artist: artist);
      }
    }
    return (title: name.isEmpty ? baseName : name, artist: null);
  }

  static const Map<int, String> id3v1Genres = {
    0: 'Blues', 1: 'Classic Rock', 2: 'Country', 3: 'Dance', 4: 'Disco',
    5: 'Funk', 6: 'Grunge', 7: 'Hip-Hop', 8: 'Jazz', 9: 'Metal',
    10: 'New Age', 11: 'Oldies', 12: 'Other', 13: 'Pop', 14: 'R&B',
    15: 'Rap', 16: 'Reggae', 17: 'Rock', 18: 'Techno', 19: 'Industrial',
    20: 'Alternative', 21: 'Ska', 22: 'Death Metal', 23: 'Pranks', 24: 'Soundtrack',
    25: 'Euro-Techno', 26: 'Ambient', 27: 'Trip-Hop', 28: 'Vocal', 29: 'Jazz+Funk',
    30: 'Fusion', 31: 'Trance', 32: 'Classical', 33: 'Instrumental', 34: 'Acid',
    35: 'House', 36: 'Game', 37: 'Sound Clip', 38: 'Gospel', 39: 'Noise',
    40: 'Alternative Rock', 41: 'Bass', 42: 'Soul', 43: 'Punk', 44: 'Space',
    45: 'Meditative', 46: 'Instrumental Pop', 47: 'Instrumental Rock', 48: 'Ethnic',
    49: 'Gothic', 50: 'Darkwave', 51: 'Techno-Industrial', 52: 'Electronic',
    53: 'Pop-Folk', 54: 'Eurodance', 55: 'Dream', 56: 'Southern Rock', 57: 'Comedy',
    58: 'Cult', 59: 'Gangsta', 60: 'Top 40', 61: 'Christian Rap', 62: 'Pop/Funk',
    63: 'Jungle', 64: 'Native American', 65: 'Cabaret', 66: 'New Wave',
    67: 'Psychedelic', 68: 'Rave', 69: 'Showtunes', 70: 'Trailer', 71: 'Lo-Fi',
    72: 'Tribal', 73: 'Acid Punk', 74: 'Acid Jazz', 75: 'Polka', 76: 'Retro',
    77: 'Musical', 78: 'Rock & Roll', 79: 'Hard Rock',
  };

  /// Normalises raw genre tags ("(17)", "17", "hip hop", "POP") into display
  /// names. Unknown or empty values become "Music".
  static String cleanGenre(String? raw) {
    var g = (raw ?? '').replaceAll('\x00', '').trim();
    if (g.isEmpty) return 'Music';

    final numMatch = RegExp(r'^\(?(\d+)\)?$').firstMatch(g);
    if (numMatch != null) {
      return id3v1Genres[int.parse(numMatch.group(1)!)] ?? 'Music';
    }

    final mixedMatch = RegExp(r'^\(\d+\)(.+)$').firstMatch(g);
    if (mixedMatch != null) {
      g = mixedMatch.group(1)!.trim();
    }

    final lower = g.toLowerCase();
    if (RegExp(r'\b(rap|hip[\s-]?hop|trap)\b').hasMatch(lower)) {
      return 'Hip-Hop / Rap';
    }
    if (lower == 'r&b' || lower == 'r&b/soul' || lower == 'rnb' || lower == 'r&b / soul') {
      return 'R&B';
    }
    if (RegExp(r'\b(dance|electronic|edm)\b').hasMatch(lower)) {
      return 'Dance & Electronic';
    }

    if (g.length > 2 && (g == g.toLowerCase() || g == g.toUpperCase())) {
      g = g
          .split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
          .join(' ');
    }
    return g;
  }

  /// Merges a fresh scan with the previously saved library so user state
  /// (favourites, play counts, first-seen date, learned durations) survives
  /// rescans. Songs are matched by file path first, then by id.
  static List<Song> mergeWithPrevious(List<Song> previous, List<Song> scanned) {
    final byPath = <String, Song>{};
    final byId = <String, Song>{};
    for (final s in previous) {
      if (s.filePath.isNotEmpty) byPath[normalize(s.filePath)] = s;
      byId[s.id] = s;
    }

    for (final song in scanned) {
      final old = byPath[normalize(song.filePath)] ?? byId[song.id];
      if (old == null) continue;
      song.isFavorite = old.isFavorite;
      song.playCount = old.playCount;
      song.lastPlayedAt = old.lastPlayedAt;
      if (old.dateAdded > 0 && old.dateAdded < song.dateAdded) {
        song.dateAdded = old.dateAdded;
      }
      if (song.durationMs <= 0 && old.durationMs > 0) {
        song.durationMs = old.durationMs;
      }
    }
    return scanned;
  }

  /// Removes duplicate entries for the same file, keeping the first one.
  static List<Song> dedupeByPath(Iterable<Song> songs) {
    final seen = <String>{};
    final result = <Song>[];
    for (final s in songs) {
      final key = s.filePath.isEmpty ? 'id:${s.id}' : normalize(s.filePath);
      if (seen.add(key)) result.add(s);
    }
    return result;
  }
}
