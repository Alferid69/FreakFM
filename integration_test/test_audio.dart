import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Writes a small, valid PCM WAV file (a sine tone) with RIFF INFO tags, so
/// tests can exercise real tag parsing and real playback without shipping
/// binary fixtures.
File writeTaggedWav(
  String path, {
  double seconds = 4,
  String? title,
  String? artist,
  String? album,
  String? genre,
  int sampleRate = 8000,
  double frequency = 440,
}) {
  final numSamples = (seconds * sampleRate).round();
  final pcm = ByteData(numSamples * 2);
  for (var i = 0; i < numSamples; i++) {
    final v = (sin(2 * pi * frequency * i / sampleRate) * 0.3 * 32767).round();
    pcm.setInt16(i * 2, v, Endian.little);
  }

  final info = BytesBuilder();
  void tag(String id, String? value) {
    if (value == null) return;
    final data = [...value.codeUnits.map((c) => c & 0xff), 0]; // NUL-terminated
    final size = data.length;
    if (data.length.isOdd) data.add(0); // chunks are word-aligned
    info
      ..add(id.codeUnits)
      ..add(_u32(size))
      ..add(data);
  }

  tag('INAM', title);
  tag('IART', artist);
  tag('IPRD', album);
  tag('IGNR', genre);
  final infoBytes = info.toBytes();

  final body = BytesBuilder()
    ..add('WAVE'.codeUnits)
    // fmt chunk: PCM, mono, 16-bit
    ..add('fmt '.codeUnits)
    ..add(_u32(16))
    ..add(_u16(1))
    ..add(_u16(1))
    ..add(_u32(sampleRate))
    ..add(_u32(sampleRate * 2))
    ..add(_u16(2))
    ..add(_u16(16));
  if (infoBytes.isNotEmpty) {
    body
      ..add('LIST'.codeUnits)
      ..add(_u32(4 + infoBytes.length))
      ..add('INFO'.codeUnits)
      ..add(infoBytes);
  }
  body
    ..add('data'.codeUnits)
    ..add(_u32(pcm.lengthInBytes))
    ..add(pcm.buffer.asUint8List());

  final bodyBytes = body.toBytes();
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync([...'RIFF'.codeUnits, ..._u32(bodyBytes.length), ...bodyBytes], flush: true);
  return file;
}

List<int> _u32(int v) => (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
List<int> _u16(int v) => (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();
