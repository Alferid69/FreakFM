import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

class LyricsShareService {
  static const MethodChannel _channel = MethodChannel('com.alferid.freakfm/media_store');

  /// Renders a widget identified by [boundaryKey] to crisp high-DPI PNG bytes
  static Future<Uint8List?> captureCardToPng(GlobalKey boundaryKey, {double pixelRatio = 3.0}) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing lyrics card: $e');
      return null;
    }
  }

  /// Writes PNG bytes to a temporary share file and invokes native sharing
  static Future<bool> shareLyricCard({
    required GlobalKey boundaryKey,
    required Song song,
    required List<String> lines,
    double pixelRatio = 3.0,
  }) async {
    final bytes = await captureCardToPng(boundaryKey, pixelRatio: pixelRatio);
    if (bytes == null || bytes.isEmpty) return false;

    try {
      final tempDir = await getTemporaryDirectory();
      final safeTitle = song.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim();
      final filePath = p.join(
        tempDir.path,
        'lyrics_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!kIsWeb && Platform.isAndroid) {
        // Native Android Share Sheet via FileProvider
        await _channel.invokeMethod('shareImage', {
          'filePath': filePath,
          'title': '${song.title} - Lyrics',
        });
        return true;
      } else if (!kIsWeb && Platform.isWindows) {
        // On Windows, save to Pictures and open in Windows photo viewer
        final picDir = await getApplicationDocumentsDirectory();
        final savedPath = p.join(
          picDir.path,
          'freakfm_lyrics_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.copy(savedPath);

        try {
          await Process.run('explorer.exe', [savedPath]);
        } catch (_) {}
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('Error sharing lyric card: $e');
      return false;
    }
  }

  /// Saves the captured PNG card. On Android it goes into the gallery
  /// (Pictures/FreakFM) via MediaStore; elsewhere into Documents.
  /// Returns a human-readable location, or null on failure.
  static Future<String?> saveLyricCardToDisk({
    required GlobalKey boundaryKey,
    required Song song,
  }) async {
    final bytes = await captureCardToPng(boundaryKey, pixelRatio: 3.0);
    if (bytes == null || bytes.isEmpty) return null;

    final safeTitle = song.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim();
    final fileName = 'freakfm_lyrics_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, fileName));
        await tempFile.writeAsBytes(bytes);
        final saved = await _channel.invokeMethod<String>('saveImageToGallery', {
          'filePath': tempFile.path,
          'fileName': fileName,
        });
        return saved;
      }

      final targetDir = await getApplicationDocumentsDirectory();
      final filePath = p.join(targetDir.path, fileName);
      await File(filePath).writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      debugPrint('Error saving lyric card: $e');
      return null;
    }
  }

  /// Copies formatted lyrics text with song title & artist attribution to clipboard
  static Future<void> copyLyricsText({
    required Song song,
    required List<String> lines,
  }) async {
    final text = formatLyricsText(song, lines);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Formats lyrics into a clean, Spotify-inspired quote block
  static String formatLyricsText(Song song, List<String> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      buffer.writeln(line);
    }
    buffer.writeln();
    buffer.writeln('— "${song.title}" by ${song.artist}');
    buffer.write('FreakFM 🎵');
    return buffer.toString();
  }
}
