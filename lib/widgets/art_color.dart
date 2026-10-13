import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/artwork_service.dart';
import '../theme/app_theme.dart';

/// Picks a Spotify-style backdrop colour from a song's cover art: the most
/// colourful average of a tiny downscaled copy, kept dark enough for white
/// text. Songs without art get a stable colour from their album name.
class ArtColorService {
  static final ArtColorService instance = ArtColorService._();
  ArtColorService._();

  final Map<String, Color> _cache = {};
  final Map<String, Future<Color>> _pending = {};

  Color fallbackFor(Song song) => _toBackdrop(AppTheme.colorFor(song.album));

  /// Already-computed colour, or the fallback; never blocks.
  Color peek(Song song) => _cache[song.id] ?? fallbackFor(song);

  Future<Color> colorFor(Song song) {
    final cached = _cache[song.id];
    if (cached != null) return Future.value(cached);
    return _pending[song.id] ??= _compute(song).then((c) {
      _cache[song.id] = c;
      return c;
    }).whenComplete(() {
      // Block body: returning the removed future here would make the
      // future wait on itself and never complete.
      _pending.remove(song.id);
    });
  }

  Future<Color> _compute(Song song) async {
    try {
      final path = await ArtworkService.instance.getArtworkPath(song);
      if (path == null) return fallbackFor(song);
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (data == null) return fallbackFor(song);

      // Weight each pixel by its saturation so a colourful cover doesn't
      // collapse into grey.
      double r = 0, g = 0, b = 0, w = 0;
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
        final pr = data.getUint8(i), pg = data.getUint8(i + 1), pb = data.getUint8(i + 2);
        final hsl = HSLColor.fromColor(Color.fromARGB(255, pr, pg, pb));
        final weight = 0.15 + hsl.saturation * (1 - (hsl.lightness - 0.5).abs() * 2);
        r += pr * weight;
        g += pg * weight;
        b += pb * weight;
        w += weight;
      }
      if (w == 0) return fallbackFor(song);
      return _toBackdrop(Color.fromARGB(255, (r / w).round(), (g / w).round(), (b / w).round()));
    } catch (_) {
      return fallbackFor(song);
    }
  }

  /// Keeps hue, caps lightness so white text stays readable.
  static Color _toBackdrop(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness(hsl.lightness.clamp(0.18, 0.38))
        .withSaturation((hsl.saturation * 0.9).clamp(0.0, 0.75))
        .toColor();
  }
}

/// Rebuilds with the backdrop colour of [song]'s artwork once it is known.
class ArtColorBuilder extends StatefulWidget {
  final Song? song;
  final Widget Function(BuildContext context, Color color) builder;

  const ArtColorBuilder({super.key, required this.song, required this.builder});

  @override
  State<ArtColorBuilder> createState() => _ArtColorBuilderState();
}

class _ArtColorBuilderState extends State<ArtColorBuilder> {
  late Color _color;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtColorBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id) _resolve();
  }

  void _resolve() {
    final song = widget.song;
    if (song == null) {
      _color = AppTheme.spotifyCardElevated;
      return;
    }
    _color = ArtColorService.instance.peek(song);
    ArtColorService.instance.colorFor(song).then((c) {
      if (mounted && widget.song?.id == song.id && c != _color) setState(() => _color = c);
    });
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _color),
        duration: const Duration(milliseconds: 350),
        builder: (context, c, _) => widget.builder(context, c ?? _color),
      );
}
