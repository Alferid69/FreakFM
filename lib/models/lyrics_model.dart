class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'ms': timestamp.inMilliseconds,
    'text': text,
  };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    timestamp: Duration(milliseconds: json['ms'] as int? ?? 0),
    text: json['text'] as String? ?? '',
  );
}

class LyricsData {
  final String songId;
  final String title;
  final String artist;
  final String? plainLyrics;
  final List<LyricLine> syncedLines;
  final String source;
  final bool isSynced;
  final bool isError;
  final String? errorMessage;

  /// True when the lookup succeeded but no source had lyrics for the song.
  /// Such results are cached for a while instead of re-queried every play.
  final bool isNotFound;
  final int fetchedAtMs;

  LyricsData({
    required this.songId,
    required this.title,
    required this.artist,
    this.plainLyrics,
    this.syncedLines = const [],
    required this.source,
    required this.isSynced,
    this.isError = false,
    this.errorMessage,
    this.isNotFound = false,
    int? fetchedAtMs,
  }) : fetchedAtMs = fetchedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  /// Same lyrics bound to another song id (cache entries are keyed by
  /// artist/title, so one entry can serve several copies of a track).
  LyricsData withSongId(String id) => id == songId
      ? this
      : LyricsData(
          songId: id,
          title: title,
          artist: artist,
          plainLyrics: plainLyrics,
          syncedLines: syncedLines,
          source: source,
          isSynced: isSynced,
          isError: isError,
          errorMessage: errorMessage,
          isNotFound: isNotFound,
          fetchedAtMs: fetchedAtMs,
        );

  bool get isEmpty =>
      (plainLyrics == null || plainLyrics!.trim().isEmpty) && syncedLines.isEmpty;

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'title': title,
    'artist': artist,
    'plainLyrics': plainLyrics,
    'syncedLines': syncedLines.map((l) => l.toJson()).toList(),
    'source': source,
    'isSynced': isSynced,
    'isError': isError,
    'errorMessage': errorMessage,
    'isNotFound': isNotFound,
    'fetchedAtMs': fetchedAtMs,
  };

  factory LyricsData.fromJson(Map<String, dynamic> json) => LyricsData(
    songId: json['songId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    plainLyrics: json['plainLyrics'] as String?,
    syncedLines: (json['syncedLines'] as List<dynamic>?)
            ?.map((l) => LyricLine.fromJson(l as Map<String, dynamic>))
            .toList() ??
        const [],
    source: json['source'] as String? ?? 'Free Source',
    isSynced: json['isSynced'] as bool? ?? false,
    isError: json['isError'] as bool? ?? false,
    errorMessage: json['errorMessage'] as String?,
    isNotFound: json['isNotFound'] as bool? ?? false,
    fetchedAtMs: (json['fetchedAtMs'] as num?)?.toInt() ?? 0,
  );

  factory LyricsData.empty(String songId, String title, String artist, {String? message, bool notFound = false}) =>
      LyricsData(
        songId: songId,
        title: title,
        artist: artist,
        source: 'Free Sources',
        isSynced: false,
        isError: message != null,
        errorMessage: message,
        isNotFound: notFound,
      );
}
