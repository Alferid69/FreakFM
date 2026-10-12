import 'dart:io';
import 'package:flutter/foundation.dart';

/// "3:07", or "1:02:07" for anything an hour or longer.
String formatDuration(Duration d) {
  final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  return '$minutes:$seconds';
}

/// "1 track", "2 tracks". Pass [pluralWord] for irregular plurals.
String plural(int count, String word, [String? pluralWord]) =>
    '$count ${count == 1 ? word : (pluralWord ?? '${word}s')}';

/// Desktop builds get an in-app volume slider; phones use hardware buttons.
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
