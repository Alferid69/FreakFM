import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'artwork_service.dart';
import 'audio_player_service.dart';

class FreakAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static FreakAudioHandler? _instance;
  static FreakAudioHandler? get instance => _instance;

  DateTime? _lastMediaClickTime;

  FreakAudioHandler() {
    _instance = this;
    _initPlaybackState();
  }

  void _initPlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  /// Broadcasts media item metadata to system notification and lock screen
  Future<void> broadcastSong(Song song) async {
    Uri? artUri;
    try {
      final artPath = await ArtworkService.instance.getArtworkPath(song);
      if (artPath != null && File(artPath).existsSync()) {
        artUri = Uri.file(artPath);
      }
    } catch (_) {}

    artUri ??= Uri.parse('android.resource://com.example.freak_shit_show/mipmap/ic_launcher');

    mediaItem.add(
      MediaItem(
        id: song.id,
        album: song.album,
        title: song.title,
        artist: song.artist,
        duration: Duration(milliseconds: song.durationMs),
        artUri: artUri,
      ),
    );
  }

  /// Broadcasts current playback state to system notification and lock screen
  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    bool isShuffle = false,
    AudioRepeatMode repeatMode = AudioRepeatMode.all,
    double speed = 1.0,
    int? queueIndex,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
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
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
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
      ),
    );
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    final now = DateTime.now();
    if (_lastMediaClickTime != null &&
        now.difference(_lastMediaClickTime!).inMilliseconds < 120) {
      // Debounce hardware contact bounce
      return;
    }
    _lastMediaClickTime = now;

    switch (button) {
      case MediaButton.media:
        await AudioPlayerService.instance.togglePlayPause();
        break;
      case MediaButton.next:
        AudioPlayerService.instance.next();
        break;
      case MediaButton.previous:
        AudioPlayerService.instance.previous();
        break;
    }
  }

  @override
  Future<void> play() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await AudioService.androidForceEnableMediaButtons();
      } catch (_) {}
    }
    await AudioPlayerService.instance.play();
  }

  @override
  Future<void> pause() async {
    await AudioPlayerService.instance.pause();
  }

  @override
  Future<void> skipToNext() async {
    AudioPlayerService.instance.next();
  }

  @override
  Future<void> skipToPrevious() async {
    AudioPlayerService.instance.previous();
  }

  @override
  Future<void> seek(Duration position) async {
    await AudioPlayerService.instance.seek(position);
  }

  @override
  Future<void> fastForward() async {
    await AudioPlayerService.instance.seekRelative(const Duration(seconds: 10));
  }

  @override
  Future<void> rewind() async {
    await AudioPlayerService.instance.seekRelative(const Duration(seconds: -10));
  }

  @override
  Future<void> setSpeed(double speed) async {
    await AudioPlayerService.instance.setPlaybackSpeed(speed);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final player = AudioPlayerService.instance;
    final enable = (shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group);
    if (player.isShuffle.value != enable) {
      player.toggleShuffle();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final player = AudioPlayerService.instance;
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        player.repeatMode.value = AudioRepeatMode.off;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        player.repeatMode.value = AudioRepeatMode.all;
        break;
      case AudioServiceRepeatMode.one:
        player.repeatMode.value = AudioRepeatMode.one;
        break;
    }
    player.broadcastStateManually();
  }

  @override
  Future<void> stop() async {
    final player = AudioPlayerService.instance;
    await player.pause();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }
}
