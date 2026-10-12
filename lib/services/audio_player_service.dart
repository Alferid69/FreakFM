import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'freak_audio_handler.dart';
import 'library_service.dart';
import 'lyrics_service.dart';
import 'playback_queue.dart';

export 'playback_queue.dart' show AudioRepeatMode;

/// One equalizer band as exposed to the UI.
class EqualizerBandInfo {
  final int index;
  final double centerFrequencyHz;
  final double gainDb;
  const EqualizerBandInfo(this.index, this.centerFrequencyHz, this.gainDb);
}

class EqualizerState {
  final double minDb;
  final double maxDb;
  final List<EqualizerBandInfo> bands;
  const EqualizerState({required this.minDb, required this.maxDb, required this.bands});
}

class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  AudioPlayerService._internal() {
    _init();
  }

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  final AndroidEqualizer? _equalizer = _isAndroid ? AndroidEqualizer() : null;
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: _equalizer == null ? null : AudioPipeline(androidAudioEffects: [_equalizer]),
  );
  final PlaybackQueue _queue = PlaybackQueue();

  final ValueNotifier<Song?> currentSong = ValueNotifier<Song?>(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(false);
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
  final ValueNotifier<String> equalizerPreset = ValueNotifier<String>('Flat');
  final ValueNotifier<bool> equalizerEnabled = ValueNotifier<bool>(false);

  /// Where the current queue came from, e.g. "Album • After Hours".
  final ValueNotifier<String> playingFrom = ValueNotifier<String>('Your library');

  final StreamController<String> _errors = StreamController<String>.broadcast();

  /// User-facing playback errors (e.g. a file that can't be decoded).
  Stream<String> get errors => _errors.stream;

  Timer? _sleepTimer;
  final List<StreamSubscription<dynamic>> _subs = [];
  int _loadToken = 0;
  bool _loadInFlight = false;
  Duration? _pendingSeek;
  int _consecutiveFailures = 0;
  bool _completionHandled = false;
  bool _equalizerRestored = false;
  double _previousVolume = 0.85;

  static const String _prefEqPreset = 'pref_eq_preset';
  static const String _prefEqEnabled = 'pref_eq_enabled';
  static const String _prefEqCustom = 'pref_eq_custom_gains';

  /// Preset curves sampled at these frequencies; device bands interpolate.
  static const List<double> presetFrequencies = [60, 230, 910, 3600, 14000];
  static const Map<String, List<double>> equalizerPresets = {
    'Flat': [0, 0, 0, 0, 0],
    'Bass Boost': [6, 4.5, 1, 0, 0],
    'Warm': [3, 2, 0, 1.5, 3.5],
    'Vocal': [-1, 1, 4.5, 3, 1],
    'Acoustic': [2, 1, 2, 3, 4],
    'Electronic': [5, 3, 0, 2.5, 4.5],
    'Treble Boost': [0, 0, 1, 4, 6],
  };

  bool get equalizerSupported => _equalizer != null;

  void _init() {
    _player.setVolume(volume.value);
    unawaited(_configureSession());
    unawaited(_loadEqualizerPrefs());

    _subs.add(_player.positionStream.listen((pos) {
      position.value = pos;
    }));

    _subs.add(_player.durationStream.listen((dur) {
      final song = currentSong.value;
      if (dur == null || dur <= Duration.zero || song == null) return;
      duration.value = dur;
      LibraryService.instance.updateDuration(song, dur);
    }));

    _subs.add(_player.playerStateStream.listen((state) {
      final completed = state.processingState == ProcessingState.completed;
      final playing = state.playing && !completed;
      final buffering = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      final changed = playing != isPlaying.value || buffering != isBuffering.value;
      isPlaying.value = playing;
      isBuffering.value = buffering;
      if (changed) _broadcastPlaybackState();

      if (completed && !_completionHandled) {
        _completionHandled = true;
        _handleTrackCompleted();
      }
    }));
  }

  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // Headphones unplugged / Bluetooth disconnected: pause instead of
      // suddenly blasting through the speaker.
      _subs.add(session.becomingNoisyEventStream.listen((_) => pause()));
    } catch (e) {
      debugPrint('Audio session setup failed: $e');
    }
  }

  void _broadcastPlaybackState() {
    try {
      FreakAudioHandler.instance?.updatePlaybackState(
        isPlaying: isPlaying.value,
        isBuffering: isBuffering.value,
        position: _player.position,
        isShuffle: isShuffle.value,
        repeatMode: repeatMode.value,
        speed: playbackSpeed.value,
        queueIndex: queueIndex.value,
      );
    } catch (_) {}
  }

  void _syncQueueNotifiers() {
    queue.value = _queue.songs;
    queueIndex.value = _queue.index;
  }

  /// Plays [song]. With [contextQueue] the queue is replaced by that list;
  /// otherwise the song is jumped to (if queued) or inserted next.
  Future<void> playSong(Song song, {List<Song>? contextQueue, String? source}) async {
    if (source != null) playingFrom.value = source;
    if (contextQueue != null && contextQueue.isNotEmpty) {
      final idx = contextQueue.indexWhere((s) => s.id == song.id);
      _queue.setQueue(contextQueue, idx >= 0 ? idx : 0);
      _queue.setShuffle(isShuffle.value);
    } else {
      final idx = _queue.songs.indexWhere((s) => s.id == song.id);
      _queue.jumpTo(idx >= 0 ? idx : _queue.insertNext(song));
    }
    _syncQueueNotifiers();
    await _loadAndPlay(song);
  }

  Future<void> _loadAndPlay(Song song) async {
    final token = ++_loadToken;
    // Swapping sources can emit a stale "completed" for the previous track;
    // ignore completions until the new source has loaded.
    _completionHandled = true;

    currentSong.value = song;
    position.value = Duration.zero;
    duration.value = Duration(milliseconds: song.durationMs);
    unawaited(FreakAudioHandler.instance?.broadcastSong(song));

    _pendingSeek = null;
    _loadInFlight = true;
    try {
      final source = _sourceFor(song);
      final loaded = await _player.setAudioSource(source);
      if (token != _loadToken) return; // superseded by a newer request
      _loadInFlight = false;
      _completionHandled = false;
      final pending = _pendingSeek;
      if (pending != null) {
        _pendingSeek = null;
        await _seekPlatform(pending);
      }

      if (loaded != null && loaded > Duration.zero) {
        duration.value = loaded;
        LibraryService.instance.updateDuration(song, loaded);
      }
      unawaited(_player.play());
      _consecutiveFailures = 0;
      LibraryService.instance.recordPlay(song);
      unawaited(LyricsService.instance.fetchLyrics(song));
      if (!_equalizerRestored) unawaited(_restoreEqualizer());
      _broadcastPlaybackState();
    } catch (e) {
      if (token != _loadToken) return;
      _loadInFlight = false;
      debugPrint('Playback error for ${song.filePath}: $e');
      _errors.add('Can\'t play "${song.title}" — the file is missing or unsupported.');
      isPlaying.value = false;
      _broadcastPlaybackState();

      _consecutiveFailures++;
      if (_consecutiveFailures < _queue.songs.length) {
        await next();
      } else {
        _consecutiveFailures = 0;
      }
    }
  }

  AudioSource _sourceFor(Song song) {
    final uri = song.contentUri;
    if (_isAndroid && uri != null && uri.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(uri));
    }
    if (song.filePath.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(song.filePath));
    }
    if (!File(song.filePath).existsSync()) {
      throw FileSystemException('File not found', song.filePath);
    }
    return AudioSource.file(song.filePath);
  }

  void _handleTrackCompleted() {
    if (sleepAtEndOfTrack.value) {
      sleepAtEndOfTrack.value = false;
      unawaited(_player.pause());
      unawaited(_player.seek(Duration.zero));
      return;
    }

    if (repeatMode.value == AudioRepeatMode.one && currentSong.value != null) {
      _completionHandled = false;
      unawaited(_player.seek(Duration.zero));
      unawaited(_player.play());
      return;
    }
    unawaited(next(fromCompletion: true));
  }

  Future<void> play() async {
    final song = currentSong.value;
    if (song == null) {
      if (_queue.songs.isNotEmpty) await playSong(_queue.songs[_queue.index]);
      return;
    }
    final state = _player.processingState;
    if (state == ProcessingState.idle) {
      await _loadAndPlay(song);
      return;
    }
    if (state == ProcessingState.completed) {
      _completionHandled = false;
      await _seekPlatform(Duration.zero);
    }
    unawaited(_player.play());
  }

  Future<void> pause() async {
    await _player.pause();
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
    if (_loadInFlight) {
      // Seeking while a source is still loading can stall on some platforms;
      // apply it as soon as the load finishes instead.
      _pendingSeek = pos;
      return;
    }
    await _seekPlatform(pos);
    _broadcastPlaybackState();
  }

  /// Never lets a stuck platform seek freeze the caller (e.g. the seek bar).
  Future<void> _seekPlatform(Duration pos) async {
    try {
      await _player.seek(pos).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint('Seek to $pos timed out');
    }
  }

  Future<void> seekRelative(Duration delta) async {
    final totalMs = duration.value.inMilliseconds;
    final targetMs = position.value.inMilliseconds + delta.inMilliseconds;
    await seek(Duration(milliseconds: targetMs.clamp(0, totalMs > 0 ? totalMs : max(targetMs, 0))));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed.value = speed;
    await _player.setSpeed(speed);
    _broadcastPlaybackState();
  }

  void setSleepTimer(int? minutes, {bool endOfTrack = false}) {
    _sleepTimer?.cancel();
    sleepAtEndOfTrack.value = endOfTrack;

    if (endOfTrack || minutes == null) {
      sleepTimerRemainingMinutes.value = null;
      return;
    }

    sleepTimerRemainingMinutes.value = minutes;
    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final remaining = sleepTimerRemainingMinutes.value;
      if (remaining == null || remaining <= 1) {
        timer.cancel();
        sleepTimerRemainingMinutes.value = null;
        pause();
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
    if (song != null) LibraryService.instance.toggleFavorite(song);
  }

  Future<void> next({bool fromCompletion = false}) async {
    final idx = _queue.advance(repeatMode.value);
    if (idx == null) {
      // End of the queue with repeat off: stop at the start of the last song.
      await _player.pause();
      await _seekPlatform(Duration.zero);
      return;
    }
    _syncQueueNotifiers();
    await _loadAndPlay(_queue.songs[idx]);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (position.value.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final idx = _queue.retreat(repeatMode.value);
    if (idx == null) {
      await seek(Duration.zero);
      return;
    }
    _syncQueueNotifiers();
    await _loadAndPlay(_queue.songs[idx]);
  }

  /// Queues [song] to play right after the current one.
  void playNext(Song song) {
    if (currentSong.value == null) {
      playSong(song, contextQueue: [song]);
      return;
    }
    _removeUpcomingCopy(song);
    _queue.insertNext(song);
    _syncQueueNotifiers();
  }

  /// Adds [song] to the end of the queue.
  void addToQueue(Song song) {
    if (currentSong.value == null) {
      playSong(song, contextQueue: [song]);
      return;
    }
    _removeUpcomingCopy(song);
    _queue.append(song);
    _syncQueueNotifiers();
  }

  void _removeUpcomingCopy(Song song) {
    final idx = _queue.songs.indexWhere((s) => s.id == song.id);
    if (idx >= 0 && idx != _queue.index) _queue.removeAt(idx);
  }

  void toggleShuffle() => setShuffle(!isShuffle.value);

  void setShuffle(bool enabled) {
    isShuffle.value = enabled;
    _queue.setShuffle(enabled);
    _broadcastPlaybackState();
  }

  void setRepeatMode(AudioRepeatMode mode) {
    repeatMode.value = mode;
    _broadcastPlaybackState();
  }

  void cycleRepeatMode() {
    setRepeatMode(switch (repeatMode.value) {
      AudioRepeatMode.off => AudioRepeatMode.all,
      AudioRepeatMode.all => AudioRepeatMode.one,
      AudioRepeatMode.one => AudioRepeatMode.off,
    });
  }

  void removeFromQueue(int index) {
    if (index == _queue.index) return; // can't remove what's playing
    _queue.removeAt(index);
    _syncQueueNotifiers();
  }

  void shuffleQueue() {
    _queue.shuffleInPlace();
    _syncQueueNotifiers();
  }

  void clearQueue() {
    _queue.clearUpcoming();
    _syncQueueNotifiers();
  }

  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    if (clamped > 0) _previousVolume = clamped;
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

  // ---------------------------------------------------------------------------
  // Equalizer (Android only — backed by android.media.audiofx.Equalizer)
  // ---------------------------------------------------------------------------

  Future<void> _loadEqualizerPrefs() async {
    if (!equalizerSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      equalizerPreset.value = prefs.getString(_prefEqPreset) ?? 'Flat';
      equalizerEnabled.value = prefs.getBool(_prefEqEnabled) ?? false;
    } catch (_) {}
  }

  /// Band layout and gains from the device; null when the equalizer is not
  /// available yet (nothing has been loaded) or not supported.
  Future<EqualizerState?> equalizerState() async {
    final eq = _equalizer;
    if (eq == null || currentSong.value == null) return null;
    try {
      final params = await eq.parameters.timeout(const Duration(seconds: 3));
      return EqualizerState(
        minDb: params.minDecibels,
        maxDb: params.maxDecibels,
        bands: [
          for (final b in params.bands) EqualizerBandInfo(b.index, _toHz(b.centerFrequency), b.gain),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    final eq = _equalizer;
    if (eq == null) return;
    equalizerEnabled.value = enabled;
    await eq.setEnabled(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEqEnabled, enabled);
  }

  Future<void> applyEqualizerPreset(String name) async {
    final eq = _equalizer;
    final curve = equalizerPresets[name];
    if (eq == null || curve == null) return;
    equalizerPreset.value = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefEqPreset, name);
    try {
      final params = await eq.parameters.timeout(const Duration(seconds: 3));
      for (final band in params.bands) {
        final gain = presetGainAt(curve, _toHz(band.centerFrequency))
            .clamp(params.minDecibels, params.maxDecibels);
        await band.setGain(gain.toDouble());
      }
    } catch (_) {}
  }

  Future<void> setEqualizerBandGain(int bandIndex, double gainDb) async {
    final eq = _equalizer;
    if (eq == null) return;
    try {
      final params = await eq.parameters.timeout(const Duration(seconds: 3));
      await params.bands[bandIndex].setGain(gainDb);
      equalizerPreset.value = 'Custom';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefEqPreset, 'Custom');
      await prefs.setStringList(_prefEqCustom, params.bands.map((b) => b.gain.toString()).toList());
    } catch (_) {}
  }

  Future<void> _restoreEqualizer() async {
    final eq = _equalizer;
    if (eq == null) return;
    _equalizerRestored = true;
    try {
      await eq.setEnabled(equalizerEnabled.value);
      if (equalizerPreset.value == 'Custom') {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getStringList(_prefEqCustom) ?? const [];
        final params = await eq.parameters.timeout(const Duration(seconds: 3));
        for (var i = 0; i < params.bands.length && i < saved.length; i++) {
          await params.bands[i].setGain(double.tryParse(saved[i]) ?? 0);
        }
      } else {
        await applyEqualizerPreset(equalizerPreset.value);
      }
    } catch (_) {}
  }

  /// just_audio reports Hz; guard against platforms that report milliHertz.
  static double _toHz(double f) => f > 100000 ? f / 1000 : f;

  /// Interpolates a preset curve (defined at [presetFrequencies]) at [hz]
  /// on a log-frequency scale.
  static double presetGainAt(List<double> curve, double hz) {
    if (hz <= presetFrequencies.first) return curve.first;
    if (hz >= presetFrequencies.last) return curve.last;
    for (var i = 0; i < presetFrequencies.length - 1; i++) {
      final f0 = presetFrequencies[i], f1 = presetFrequencies[i + 1];
      if (hz >= f0 && hz <= f1) {
        final t = (log(hz) - log(f0)) / (log(f1) - log(f0));
        return curve[i] + (curve[i + 1] - curve[i]) * t;
      }
    }
    return 0;
  }

  void dispose() {
    _sleepTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _errors.close();
    _player.dispose();
  }
}
