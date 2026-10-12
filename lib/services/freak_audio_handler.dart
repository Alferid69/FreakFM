import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import 'artwork_service.dart';
import 'audio_player_service.dart';

/// Bridges the system media session (notification, lock screen, Bluetooth
/// and headset buttons) to [AudioPlayerService].
class FreakAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static FreakAudioHandler? _instance;
  static FreakAudioHandler? get instance => _instance;

  DateTime? _lastMediaClickTime;

  FreakAudioHandler() {
    _instance = this;
    playbackState.add(PlaybackState(
      controls: [MediaControl.skipToPrevious, MediaControl.play, MediaControl.skipToNext],
      systemActions: _systemActions,
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  static const Set<MediaAction> _systemActions = {
    MediaAction.play,
    MediaAction.pause,
    MediaAction.playPause,
    MediaAction.stop,
    MediaAction.skipToNext,
    MediaAction.skipToPrevious,
    MediaAction.seek,
    MediaAction.seekForward,
    MediaAction.seekBackward,
    MediaAction.setShuffleMode,
    MediaAction.setRepeatMode,
    MediaAction.setSpeed,
    MediaAction.fastForward,
    MediaAction.rewind,
  };

  /// Publishes track metadata. Artwork is attached when it becomes available.
  Future<void> broadcastSong(Song song) async {
    MediaItem item(Uri? art) => MediaItem(
          id: song.id,
          album: song.album,
          title: song.title,
          artist: song.artist,
          duration: song.durationMs > 0 ? Duration(milliseconds: song.durationMs) : null,
          artUri: art,
        );

    mediaItem.add(item(null));
    try {
      final artPath = await ArtworkService.instance.getArtworkPath(song);
      if (artPath != null && mediaItem.value?.id == song.id) {
        mediaItem.add(item(Uri.file(artPath)));
      }
    } catch (_) {}
  }

  /// Publishes play state. The system extrapolates position from
  /// [position] and [speed], so this is only called on state changes.
  void updatePlaybackState({
    required bool isPlaying,
    required bool isBuffering,
    required Duration position,
    bool isShuffle = false,
    AudioRepeatMode repeatMode = AudioRepeatMode.all,
    double speed = 1.0,
    int? queueIndex,
  }) {
    final current = mediaItem.value;
    final player = AudioPlayerService.instance;
    if (current != null && player.duration.value > Duration.zero && current.duration != player.duration.value) {
      mediaItem.add(current.copyWith(duration: player.duration.value));
    }

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: _systemActions,
      androidCompactActionIndices: const [0, 1, 2],
      processingState: isBuffering ? AudioProcessingState.buffering : AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: position,
      bufferedPosition: position,
      speed: speed,
      queueIndex: queueIndex,
      shuffleMode: isShuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      repeatMode: switch (repeatMode) {
        AudioRepeatMode.off => AudioServiceRepeatMode.none,
        AudioRepeatMode.all => AudioServiceRepeatMode.all,
        AudioRepeatMode.one => AudioServiceRepeatMode.one,
      },
    ));
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    final now = DateTime.now();
    if (_lastMediaClickTime != null && now.difference(_lastMediaClickTime!).inMilliseconds < 120) {
      return; // debounce hardware contact bounce
    }
    _lastMediaClickTime = now;

    switch (button) {
      case MediaButton.media:
        await AudioPlayerService.instance.togglePlayPause();
      case MediaButton.next:
        await AudioPlayerService.instance.next();
      case MediaButton.previous:
        await AudioPlayerService.instance.previous();
    }
  }

  @override
  Future<void> play() => AudioPlayerService.instance.play();

  @override
  Future<void> pause() => AudioPlayerService.instance.pause();

  @override
  Future<void> skipToNext() => AudioPlayerService.instance.next();

  @override
  Future<void> skipToPrevious() => AudioPlayerService.instance.previous();

  @override
  Future<void> seek(Duration position) => AudioPlayerService.instance.seek(position);

  @override
  Future<void> fastForward() => AudioPlayerService.instance.seekRelative(const Duration(seconds: 10));

  @override
  Future<void> rewind() => AudioPlayerService.instance.seekRelative(const Duration(seconds: -10));

  @override
  Future<void> setSpeed(double speed) => AudioPlayerService.instance.setPlaybackSpeed(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    AudioPlayerService.instance.setShuffle(
      shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group,
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    AudioPlayerService.instance.setRepeatMode(switch (repeatMode) {
      AudioServiceRepeatMode.none => AudioRepeatMode.off,
      AudioServiceRepeatMode.one => AudioRepeatMode.one,
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => AudioRepeatMode.all,
    });
  }

  @override
  Future<void> stop() async {
    await AudioPlayerService.instance.pause();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }
}
