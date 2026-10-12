import 'package:path/path.dart' as p;

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  int durationMs;
  final String filePath;
  final int fileSize;
  final String folder;
  final String genre;
  final int? year;
  int dateAdded;
  bool isFavorite;
  int playCount;
  final int bitrate; // kbps, 0 when unknown
  final int sampleRate; // Hz, 0 when unknown
  String? artworkPath;
  final int? albumId;
  final String? contentUri;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.filePath,
    required this.fileSize,
    required this.folder,
    required this.genre,
    this.year,
    required this.dateAdded,
    this.isFavorite = false,
    this.playCount = 0,
    this.bitrate = 0,
    this.sampleRate = 0,
    this.artworkPath,
    this.albumId,
    this.contentUri,
  });

  /// Directory that contains the file, used to group and hide folders.
  /// Falls back to the folder name for content:// entries with no real path.
  String get folderPath {
    if (filePath.isEmpty || filePath.startsWith('content://')) return folder;
    return p.dirname(filePath);
  }

  String get extension {
    final ext = p.extension(filePath).replaceFirst('.', '').toUpperCase();
    return ext.isEmpty ? 'AUDIO' : ext;
  }

  String get formattedDuration {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSize <= 0) return '0 KB';
    final mb = fileSize / (1024 * 1024);
    if (mb >= 1.0) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = fileSize / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  String get qualityBadge {
    final ext = extension;
    final isLossless = ext == 'FLAC' || ext == 'WAV' || ext == 'AIFF';
    if (isLossless && sampleRate > 0) {
      return '$ext • ${(sampleRate / 1000).toStringAsFixed(1)}kHz';
    }
    if (bitrate > 0) {
      return '$ext • ${bitrate}kbps';
    }
    return ext;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'filePath': filePath,
        'fileSize': fileSize,
        'folder': folder,
        'genre': genre,
        'year': year,
        'dateAdded': dateAdded,
        'isFavorite': isFavorite,
        'playCount': playCount,
        'bitrate': bitrate,
        'sampleRate': sampleRate,
        'artworkPath': artworkPath,
        'albumId': albumId,
        'contentUri': contentUri,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown Title',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        album: json['album'] as String? ?? 'Unknown Album',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        filePath: json['filePath'] as String? ?? '',
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
        folder: json['folder'] as String? ?? 'Default',
        genre: json['genre'] as String? ?? 'Music',
        year: (json['year'] as num?)?.toInt(),
        dateAdded: (json['dateAdded'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        isFavorite: json['isFavorite'] as bool? ?? false,
        playCount: (json['playCount'] as num?)?.toInt() ?? 0,
        bitrate: (json['bitrate'] as num?)?.toInt() ?? 0,
        sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 0,
        artworkPath: json['artworkPath'] as String?,
        albumId: (json['albumId'] as num?)?.toInt(),
        contentUri: json['contentUri'] as String?,
      );
}

class FolderGroup {
  final String folderPath;
  final String folderName;
  final List<Song> songs;

  FolderGroup({
    required this.folderPath,
    required this.folderName,
    required this.songs,
  });

  int get totalDurationMs => songs.fold(0, (sum, s) => sum + s.durationMs);
  int get totalSizeBytes => songs.fold(0, (sum, s) => sum + s.fileSize);
}

class ArtistGroup {
  final String artistName;
  final List<Song> songs;

  ArtistGroup({
    required this.artistName,
    required this.songs,
  });

  Set<String> get albums => songs.map((s) => s.album).toSet();
  int get trackCount => songs.length;
}

class AlbumGroup {
  final String albumName;
  final String artistName;
  final List<Song> songs;
  final int? year;

  AlbumGroup({
    required this.albumName,
    required this.artistName,
    required this.songs,
    this.year,
  });

  int get trackCount => songs.length;
}

class GenreGroup {
  final String genreName;
  final List<Song> songs;

  GenreGroup({
    required this.genreName,
    required this.songs,
  });

  int get trackCount => songs.length;
}

class Playlist {
  final String id;
  String name;
  final List<String> songIds;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: (json['songIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
