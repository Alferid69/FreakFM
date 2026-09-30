import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'freak_audio_handler.dart';
import 'lyrics_service.dart';

enum AudioRepeatMode { off, all, one }

class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  AudioPlayerService._internal() {
    _initAudioPlayer();
  }

  final AudioPlayer _player = AudioPlayer();

  final ValueNotifier<Song?> currentSong = ValueNotifier<Song?>(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isShuffle = ValueNotifier<bool>(false);
  final ValueNotifier<AudioRepeatMode> repeatMode = ValueNotifier<AudioRepeatMode>(AudioRepeatMode.all);
  final ValueNotifier<List<Song>> queue = ValueNotifier<List<Song>>([]);
  final ValueNotifier<int> queueIndex = ValueNotifier<int>(0);
  final ValueNotifier<double> volume = ValueNotifier<double>(0.85);
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);
  final ValueNotifier<int?> sleepTimerRemainingMinutes = ValueNotifier<int?>(null);
  final ValueNotifier<bool> sleepAtEndOfTrack = ValueNotifier<bool>(false);
  final ValueNotifier<String> equalizerPreset = ValueNotifier<String>('Hi-Fi Warm');

  Timer? _mockPlaybackTimer;
  Timer? _sleepTimer;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _completeSub;

  void _initAudioPlayer() {
    _player.setVolume(volume.value);

    // Request persistent audio focus for music playback so Android routes
    // media button events (Bluetooth earbuds, AirPods, lock screen) to freak player
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final audioContext = AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
            audioMode: AndroidAudioMode.normal,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        );

        AudioPlayer.global.setAudioContext(audioContext);
        _player.setAudioContext(audioContext);
      } catch (e) {
        debugPrint('AudioContext initialization error: $e');
      }
    }

    _posSub = _player.onPositionChanged.listen((pos) {
      if (currentSong.value != null && !currentSong.value!.isSample) {
        position.value = pos;
        if (pos.inMilliseconds > duration.value.inMilliseconds) {
          duration.value = pos;
          currentSong.value!.durationMs = pos.inMilliseconds;
        }
        _broadcastPlaybackState();
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (currentSong.value != null && !currentSong.value!.isSample && dur.inMilliseconds > 0) {
        duration.value = dur;
        currentSong.value!.durationMs = dur.inMilliseconds;
        _broadcastPlaybackState();
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (currentSong.value != null && !currentSong.value!.isSample) {
        isPlaying.value = (state == PlayerState.playing);
        _broadcastPlaybackState();
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      _handleTrackCompleted();
    });
  }

  void _broadcastPlaybackState() {
    try {
      FreakAudioHandler.instance?.updatePlaybackState(
        isPlaying: isPlaying.value,
        position: position.value,
        duration: duration.value,
        isShuffle: isShuffle.value,
        repeatMode: repeatMode.value,
        speed: playbackSpeed.value,
        queueIndex: queueIndex.value,
      );
    } catch (_) {}
  }

  void broadcastStateManually() {
    _broadcastPlaybackState();
  }

  Future<void> playSong(Song song, {List<Song>? contextQueue}) async {
    _mockPlaybackTimer?.cancel();

    if (contextQueue != null && contextQueue.isNotEmpty) {
      queue.value = List<Song>.from(contextQueue);
      final idx = queue.value.indexWhere((s) => s.id == song.id);
      queueIndex.value = idx >= 0 ? idx : 0;
    } else if (!queue.value.any((s) => s.id == song.id)) {
      queue.value = [song, ...queue.value];
      queueIndex.value = 0;
    } else {
      queueIndex.value = queue.value.indexWhere((s) => s.id == song.id);
    }

    currentSong.value = song;
    unawaited(LyricsService.instance.fetchLyrics(song));
    song.playCount++;
    position.value = Duration.zero;
    duration.value = Duration(milliseconds: song.durationMs);

    if (!song.isSample) {
      try {
        await _player.stop();
        final Source source = song.filePath.startsWith('content://')
            ? UrlSource(song.filePath)
            : DeviceFileSource(song.filePath);

        await _player.play(source);
        await _player.setPlaybackRate(playbackSpeed.value);
        isPlaying.value = true;

        if (!kIsWeb && Platform.isAndroid) {
          try {
            await AudioService.androidForceEnableMediaButtons();
          } catch (_) {}
        }
        final d = await _player.getDuration();
        if (d != null && d.inMilliseconds > 0) {
          duration.value = d;
          song.durationMs = d.inMilliseconds;
        }
      } catch (e) {
        debugPrint('Playback error on audio file: $e');
        _startSimulatedPlayback(song);
      }
    } else {
      // High fidelity smooth simulated playback for benchmark catalog
      _startSimulatedPlayback(song);
    }

    try {
      FreakAudioHandler.instance?.broadcastSong(song);
      _broadcastPlaybackState();
    } catch (_) {}
  }

  void _startSimulatedPlayback(Song song) {
    _player.stop();
    isPlaying.value = true;
    _mockPlaybackTimer?.cancel();
    _mockPlaybackTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!isPlaying.value) return;

      final stepMs = (250 * playbackSpeed.value).toInt();
      final nextMs = position.value.inMilliseconds + stepMs;
      if (nextMs >= song.durationMs) {
        _handleTrackCompleted();
      } else {
        position.value = Duration(milliseconds: nextMs);
      }
    });
  }

  void _handleTrackCompleted() {
    if (sleepAtEndOfTrack.value) {
      sleepAtEndOfTrack.value = false;
      isPlaying.value = false;
      _player.pause();
      _broadcastPlaybackState();
      return;
    }

    if (repeatMode.value == AudioRepeatMode.one && currentSong.value != null) {
      seek(Duration.zero);
      if (currentSong.value!.isSample) {
        isPlaying.value = true;
      } else {
        _player.seek(Duration.zero);
        _player.resume();
      }
      _broadcastPlaybackState();
    } else {
      next();
    }
  }

  Future<void> play() async {
    final song = currentSong.value;
    if (song == null) {
      if (queue.value.isNotEmpty) {
        await playSong(queue.value.first);
      }
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await AudioService.androidForceEnableMediaButtons();
      } catch (_) {}
    }

    if (!isPlaying.value) {
      isPlaying.value = true;
      if (!song.isSample) {
        await _player.resume();
      }
      _broadcastPlaybackState();
    }
  }

  Future<void> pause() async {
    final song = currentSong.value;
    if (isPlaying.value) {
      isPlaying.value = false;
      if (song != null && !song.isSample) {
        await _player.pause();
      }
      _broadcastPlaybackState();
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration pos) async {
    position.value = pos;
    final song = currentSong.value;
    if (song != null && !song.isSample) {
      await _player.seek(pos);
    }
    _broadcastPlaybackState();
  }

  Future<void> seekRelative(Duration delta) async {
    final currentMs = position.value.inMilliseconds;
    final totalMs = duration.value.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs : currentMs + 10000;
    final targetMs = (currentMs + delta.inMilliseconds).clamp(0, maxMs);
    await seek(Duration(milliseconds: targetMs));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed.value = speed;
    try {
      await _player.setPlaybackRate(speed);
    } catch (_) {}
    _broadcastPlaybackState();
  }

  void setSleepTimer(int? minutes, {bool endOfTrack = false}) {
    _sleepTimer?.cancel();
    sleepAtEndOfTrack.value = endOfTrack;

    if (endOfTrack) {
      sleepTimerRemainingMinutes.value = null;
      return;
    }

    if (minutes == null) {
      sleepTimerRemainingMinutes.value = null;
      return;
    }

    sleepTimerRemainingMinutes.value = minutes;
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final remaining = sleepTimerRemainingMinutes.value;
      if (remaining == null || remaining <= 1) {
        timer.cancel();
        sleepTimerRemainingMinutes.value = null;
        if (isPlaying.value) {
          togglePlayPause();
        }
      } else {
        sleepTimerRemainingMinutes.value = remaining - 1;
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    sleepTimerRemainingMinutes.value = null;
    sleepAtEndOfTrack.value = false;
  }

  void toggleCurrentFavorite() {
    final song = currentSong.value;
    if (song != null) {
      song.isFavorite = !song.isFavorite;
      currentSong.value = song;
    }
  }

  void next() {
    if (queue.value.isEmpty) return;

    int nextIndex;
    if (isShuffle.value && queue.value.length > 1) {
      final candidates = List.generate(queue.value.length, (i) => i)..remove(queueIndex.value);
      nextIndex = candidates[Random().nextInt(candidates.length)];
    } else {
      nextIndex = queueIndex.value + 1;
      if (nextIndex >= queue.value.length) {
        if (repeatMode.value == AudioRepeatMode.all) {
          nextIndex = 0;
        } else {
          isPlaying.value = false;
          _broadcastPlaybackState();
          return;
        }
      }
    }

    queueIndex.value = nextIndex;
    playSong(queue.value[nextIndex]);
  }

  void previous() {
    if (queue.value.isEmpty) return;

    if (position.value.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }

    int prevIndex = queueIndex.value - 1;
    if (prevIndex < 0) {
      prevIndex = queue.value.length - 1;
    }

    queueIndex.value = prevIndex;
    playSong(queue.value[prevIndex]);
  }

  void toggleShuffle() {
    isShuffle.value = !isShuffle.value;
    _broadcastPlaybackState();
  }

  void cycleRepeatMode() {
    switch (repeatMode.value) {
      case AudioRepeatMode.off:
        repeatMode.value = AudioRepeatMode.all;
        break;
      case AudioRepeatMode.all:
        repeatMode.value = AudioRepeatMode.one;
        break;
      case AudioRepeatMode.one:
        repeatMode.value = AudioRepeatMode.off;
        break;
    }
    _broadcastPlaybackState();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= queue.value.length) return;
    final list = List<Song>.from(queue.value)..removeAt(index);
    queue.value = list;
    if (queueIndex.value >= list.length) {
      queueIndex.value = max(0, list.length - 1);
    }
  }

  void shuffleQueue() {
    if (queue.value.length <= 1) return;
    final current = currentSong.value;
    final shuffled = List<Song>.from(queue.value)..shuffle();
    if (current != null) {
      shuffled.removeWhere((s) => s.id == current.id);
      shuffled.insert(0, current);
      queueIndex.value = 0;
    }
    queue.value = shuffled;
  }

  void clearQueue() {
    final current = currentSong.value;
    if (current != null) {
      queue.value = [current];
      queueIndex.value = 0;
    } else {
      queue.value = [];
      queueIndex.value = 0;
    }
  }

  double _previousVolume = 0.85;

  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    if (clamped > 0) {
      _previousVolume = clamped;
    }
    volume.value = clamped;
    await _player.setVolume(clamped);
  }

  Future<void> toggleMute() async {
    if (volume.value > 0) {
      _previousVolume = volume.value;
      await setVolume(0.0);
    } else {
      await setVolume(_previousVolume > 0 ? _previousVolume : 0.85);
    }
  }

  Future<void> adjustVolumeBy(double delta) async {
    await setVolume(volume.value + delta);
  }

  void setEqualizerPreset(String preset) {
    equalizerPreset.value = preset;
  }

  void dispose() {
    _mockPlaybackTimer?.cancel();
    _sleepTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
  }
}
