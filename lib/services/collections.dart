import 'package:path/path.dart' as p;
import '../models/song.dart';

enum CollectionKind { liked, allSongs, mostPlayed, recentlyAdded, recentlyPlayed, album, artist, folder, genre }

/// A browsable group of songs (album, artist, folder, genre or one of the
/// built-in playlists). Identified by [kind] + [key] so pages can re-resolve
/// their songs whenever the library changes.
class CollectionRef {
  final CollectionKind kind;
  final String key;
  final String title;

  const CollectionRef(this.kind, this.key, this.title);

  static const liked = CollectionRef(CollectionKind.liked, 'liked', 'Liked Songs');
  static const allSongs = CollectionRef(CollectionKind.allSongs, 'all', 'All Songs');
  static const mostPlayed = CollectionRef(CollectionKind.mostPlayed, 'most', 'Most Played');
  static const recentlyAdded = CollectionRef(CollectionKind.recentlyAdded, 'recent', 'Recently Added');
  static const recentlyPlayed = CollectionRef(CollectionKind.recentlyPlayed, 'history', 'Recently Played');

  bool get isPlaylist => switch (kind) {
        CollectionKind.liked ||
        CollectionKind.allSongs ||
        CollectionKind.mostPlayed ||
        CollectionKind.recentlyAdded ||
        CollectionKind.recentlyPlayed =>
          true,
        _ => false,
      };

  /// "Album", "Artist", "Playlist"… as shown under titles in lists.
  String get typeLabel => switch (kind) {
        CollectionKind.album => 'Album',
        CollectionKind.artist => 'Artist',
        CollectionKind.folder => 'Folder',
        CollectionKind.genre => 'Genre',
        _ => 'Playlist',
      };

  /// Label for the player's "Playing from" header.
  String get playingFrom => isPlaylist ? title : '$typeLabel • $title';

  @override
  bool operator ==(Object other) => other is CollectionRef && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);
}

/// A resolved collection: its reference plus songs in play order.
class Collection {
  final CollectionRef ref;
  final List<Song> songs;

  const Collection(this.ref, this.songs);

  Song? get cover => songs.isEmpty ? null : songs.first;
  int get totalMs => songs.fold(0, (sum, s) => sum + s.durationMs);

  /// Most recent play of any song in this collection (0 if never played).
  int get lastPlayedAt => songs.fold(0, (m, s) => (s.lastPlayedAt ?? 0) > m ? s.lastPlayedAt! : m);
  int get playCount => songs.fold(0, (sum, s) => sum + s.playCount);
  int get newestAdded => songs.fold(0, (m, s) => s.dateAdded > m ? s.dateAdded : m);

  String get artistLine {
    final artists = songs.map((s) => s.artist).toSet();
    if (artists.length == 1) return artists.first;
    return 'Various Artists';
  }
}

/// Pure grouping helpers over the library.
class Collections {
  Collections._();

  /// Same-named albums by different artists stay separate: MediaStore's album
  /// id when known, else name + folder.
  static String albumKey(Song s) =>
      (s.albumId != null && s.albumId! > 0) ? 'id:${s.albumId}' : '${s.album.toLowerCase()}|${s.folderPath}';

  static List<Collection> albums(List<Song> songs) {
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(albumKey(s), () => []).add(s);
    }
    return [
      for (final e in map.entries)
        Collection(CollectionRef(CollectionKind.album, e.key, e.value.first.album), _albumOrder(e.value)),
    ]..sort((a, b) => a.ref.title.toLowerCase().compareTo(b.ref.title.toLowerCase()));
  }

  static List<Collection> artists(List<Song> songs) => _groupBy(songs, CollectionKind.artist, (s) => s.artist);

  static List<Collection> genres(List<Song> songs) => _groupBy(songs, CollectionKind.genre, (s) => s.genre);

  static List<Collection> folders(List<Song> songs) {
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(s.folderPath, () => []).add(s);
    }
    return [
      for (final e in map.entries)
        Collection(
          CollectionRef(CollectionKind.folder, e.key, p.basename(e.key).isEmpty ? e.value.first.folder : p.basename(e.key)),
          _titleOrder(e.value),
        ),
    ]..sort((a, b) => a.ref.title.toLowerCase().compareTo(b.ref.title.toLowerCase()));
  }

  /// Resolves [ref] against the current library.
  static Collection resolve(CollectionRef ref, List<Song> library) {
    final List<Song> songs = switch (ref.kind) {
      CollectionKind.liked => _titleOrder(library.where((s) => s.isFavorite)),
      CollectionKind.allSongs => _titleOrder(library),
      CollectionKind.mostPlayed =>
        (library.where((s) => s.playCount > 0).toList()..sort((a, b) => b.playCount.compareTo(a.playCount)))
            .take(50)
            .toList(),
      CollectionKind.recentlyAdded =>
        (List.of(library)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded))).take(50).toList(),
      CollectionKind.recentlyPlayed =>
        (library.where((s) => s.lastPlayedAt != null).toList()
              ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!)))
            .take(50)
            .toList(),
      CollectionKind.album => _albumOrder(library.where((s) => albumKey(s) == ref.key)),
      CollectionKind.artist => _titleOrder(library.where((s) => s.artist == ref.key)),
      CollectionKind.genre => _titleOrder(library.where((s) => s.genre == ref.key)),
      CollectionKind.folder => _titleOrder(library.where((s) => s.folderPath == ref.key)),
    };
    return Collection(ref, songs);
  }

  static CollectionRef albumOf(Song s) => CollectionRef(CollectionKind.album, albumKey(s), s.album);
  static CollectionRef artistOf(Song s) => CollectionRef(CollectionKind.artist, s.artist, s.artist);

  static List<Collection> _groupBy(List<Song> songs, CollectionKind kind, String Function(Song) keyOf) {
    final map = <String, List<Song>>{};
    for (final s in songs) {
      map.putIfAbsent(keyOf(s), () => []).add(s);
    }
    return [
      for (final e in map.entries) Collection(CollectionRef(kind, e.key, e.key), _titleOrder(e.value)),
    ]..sort((a, b) => a.ref.title.toLowerCase().compareTo(b.ref.title.toLowerCase()));
  }

  static List<Song> _titleOrder(Iterable<Song> songs) =>
      songs.toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  /// Albums play in file-name order, which usually follows track numbers.
  static List<Song> _albumOrder(Iterable<Song> songs) =>
      songs.toList()..sort((a, b) => p.basename(a.filePath).toLowerCase().compareTo(p.basename(b.filePath).toLowerCase()));
}
