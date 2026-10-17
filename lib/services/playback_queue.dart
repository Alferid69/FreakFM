import 'dart:math';
import '../models/song.dart';

enum AudioRepeatMode { off, all, one }

/// Pure queue/shuffle bookkeeping, independent of the audio engine.
///
/// The queue keeps its original order; shuffle walks a separate permutation
/// of indices, so "previous" goes back to what was actually heard and no song
/// repeats until every song in the queue has played once.
class PlaybackQueue {
  PlaybackQueue({Random? random}) : _random = random ?? Random();

  final Random _random;
  List<Song> _songs = const [];
  int _index = 0;
  bool _shuffle = false;
  List<int> _order = const [];
  int _orderPos = 0;

  List<Song> get songs => _songs;
  int get index => _index;
  bool get isShuffled => _shuffle;
  bool get isEmpty => _songs.isEmpty;
  Song? get current => (_index >= 0 && _index < _songs.length) ? _songs[_index] : null;

  /// Indices of the songs still to come, in the order they will play.
  List<int> get upcomingIndices => _shuffle
      ? _order.sublist(_orderPos + 1)
      : [for (var i = _index + 1; i < _songs.length; i++) i];

  /// Up to [count] indices that will play after the current song, in order.
  /// Unshuffled queues wrap around under repeat-all; a shuffled queue stops
  /// at the end of its pass (a fresh pass is only drawn when it is reached).
  List<int> lookahead(int count, AudioRepeatMode repeat) {
    if (_songs.isEmpty || repeat == AudioRepeatMode.one || count <= 0) return const [];
    if (_shuffle) return upcomingIndices.take(count).toList();
    final out = <int>[];
    var i = _index;
    while (out.length < count) {
      i++;
      if (i >= _songs.length) {
        if (repeat == AudioRepeatMode.off || _songs.length == 1) break;
        i = 0;
      }
      out.add(i);
    }
    return out;
  }

  /// Replaces the queue and positions it at [startIndex].
  void setQueue(List<Song> songs, int startIndex) {
    _songs = List<Song>.unmodifiable(songs);
    _index = songs.isEmpty ? 0 : startIndex.clamp(0, songs.length - 1);
    _rebuildOrder();
  }

  /// Moves to [index] directly (e.g. tapping a song in the queue).
  void jumpTo(int index) {
    if (index < 0 || index >= _songs.length) return;
    _index = index;
    if (_shuffle) {
      final pos = _order.indexOf(index);
      if (pos > _orderPos) {
        // Pull the chosen song forward so it plays now and the rest of the
        // upcoming shuffle order is preserved.
        _order = List<int>.from(_order)
          ..removeAt(pos)
          ..insert(_orderPos + 1, index);
        _orderPos++;
      } else if (pos >= 0) {
        _orderPos = pos;
      }
    }
  }

  /// Inserts [song] right after the current one and returns its index.
  int insertNext(Song song) {
    final at = _songs.isEmpty ? 0 : _index + 1;
    _songs = List<Song>.unmodifiable(List<Song>.from(_songs)..insert(at, song));
    if (_shuffle) {
      final shifted = _order.map((i) => i >= at ? i + 1 : i).toList()..insert(_orderPos + 1, at);
      _order = shifted;
    }
    return at;
  }

  /// Adds [song] to the end of the queue (and of the shuffle order).
  int append(Song song) {
    final at = _songs.length;
    _songs = List<Song>.unmodifiable([..._songs, song]);
    if (_shuffle) _order = [..._order, at];
    return at;
  }

  void setShuffle(bool enabled) {
    if (_shuffle == enabled) return;
    _shuffle = enabled;
    _rebuildOrder();
  }

  /// Advances and returns the new index, or null when playback should stop.
  int? advance(AudioRepeatMode repeat) {
    if (_songs.isEmpty) return null;
    if (_shuffle) {
      if (_orderPos + 1 < _order.length) {
        _orderPos++;
      } else if (repeat == AudioRepeatMode.off) {
        return null;
      } else {
        // New pass: fresh permutation, avoiding an immediate repeat.
        final last = _index;
        _order = _permutation(exclude: null);
        if (_order.length > 1 && _order.first == last) {
          final swap = 1 + _random.nextInt(_order.length - 1);
          _order[0] = _order[swap];
          _order[swap] = last;
        }
        _orderPos = 0;
      }
      _index = _order[_orderPos];
      return _index;
    }
    if (_index + 1 < _songs.length) {
      _index++;
      return _index;
    }
    if (repeat == AudioRepeatMode.off) return null;
    _index = 0;
    return _index;
  }

  /// Steps back and returns the new index, or null when already at the start
  /// (callers then restart the current song).
  int? retreat(AudioRepeatMode repeat) {
    if (_songs.isEmpty) return null;
    if (_shuffle) {
      if (_orderPos == 0) return null;
      _orderPos--;
      _index = _order[_orderPos];
      return _index;
    }
    if (_index > 0) {
      _index--;
      return _index;
    }
    if (repeat == AudioRepeatMode.all) {
      _index = _songs.length - 1;
      return _index;
    }
    return null;
  }

  void removeAt(int index) {
    if (index < 0 || index >= _songs.length) return;
    _songs = List<Song>.unmodifiable(List<Song>.from(_songs)..removeAt(index));
    if (index < _index || _index >= _songs.length) {
      _index = max(0, _index - 1);
    }
    if (_shuffle) {
      final removedPos = _order.indexOf(index);
      _order = _order.where((i) => i != index).map((i) => i > index ? i - 1 : i).toList();
      if (removedPos >= 0 && removedPos <= _orderPos) _orderPos = max(0, _orderPos - 1);
      if (_orderPos >= _order.length) _orderPos = max(0, _order.length - 1);
    }
  }

  /// Physically shuffles the upcoming songs, keeping the current one first.
  void shuffleInPlace() {
    final cur = current;
    if (cur == null || _songs.length <= 1) return;
    final rest = List<Song>.from(_songs)..removeAt(_index);
    rest.shuffle(_random);
    _songs = List<Song>.unmodifiable([cur, ...rest]);
    _index = 0;
    _rebuildOrder();
  }

  void clearUpcoming() {
    final cur = current;
    _songs = cur == null ? const [] : List<Song>.unmodifiable([cur]);
    _index = 0;
    _rebuildOrder();
  }

  void _rebuildOrder() {
    if (!_shuffle || _songs.isEmpty) {
      _order = const [];
      _orderPos = 0;
      return;
    }
    _order = [_index, ..._permutation(exclude: _index)];
    _orderPos = 0;
  }

  List<int> _permutation({required int? exclude}) {
    final list = [
      for (var i = 0; i < _songs.length; i++)
        if (i != exclude) i,
    ]..shuffle(_random);
    return list;
  }
}
