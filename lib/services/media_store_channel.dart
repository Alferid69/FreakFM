import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only helpers implemented in MainActivity.kt.
class MediaStoreChannel {
  MediaStoreChannel._();

  static const MethodChannel _channel = MethodChannel('com.alferid.freakfm/media_store');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// True when Android won't put FreakFM to sleep to save battery.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openBatterySettings() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('openBatterySettings');
    } catch (e) {
      debugPrint('openBatterySettings failed: $e');
    }
  }
}
