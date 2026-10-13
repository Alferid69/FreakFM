import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/artwork_service.dart';
import 'package:freak_shit_show/widgets/art_color.dart';

Future<Song> _songWithCover(Color color, String id) async {
  final dir = Directory.systemTemp.createTempSync('cover_');
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 40), Paint()..color = color);
  final image = await recorder.endRecording().toImage(40, 40);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${dir.path}/cover.png')..writeAsBytesSync(png!.buffer.asUint8List());
  return Song(
    id: id,
    title: 't',
    artist: 'a',
    album: 'Album $id',
    durationMs: 1,
    filePath: '/music/$id.mp3',
    fileSize: 1,
    folder: 'music',
    genre: 'g',
    dateAdded: 0,
    artworkPath: file.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('artwork lookups complete (and repeat lookups too)', () async {
    final song = await _songWithCover(const Color(0xFF1565C0), 'lookup');
    final first = await ArtworkService.instance.getArtworkPath(song).timeout(const Duration(seconds: 5));
    final second = await ArtworkService.instance.getArtworkPath(song).timeout(const Duration(seconds: 5));
    expect(first, song.artworkPath);
    expect(second, first);
  });

  test('backdrop colour follows the cover hue and stays dark enough for white text', () async {
    final song = await _songWithCover(const Color(0xFFD32F2F), 'red');
    final color = await ArtColorService.instance.colorFor(song).timeout(const Duration(seconds: 5));
    final hsl = HSLColor.fromColor(color);
    expect(hsl.hue < 20 || hsl.hue > 340, isTrue, reason: 'expected a red backdrop, got $hsl');
    expect(hsl.lightness, lessThanOrEqualTo(0.39)); // 0.38 cap + 8-bit rounding
  });
}
