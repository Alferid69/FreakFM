import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/freak_audio_handler.dart';
import 'services/lyrics_service.dart';
import 'theme/app_theme.dart';
import 'views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline persistent lyrics cache
  try {
    await LyricsService.instance.initCache();
  } catch (_) {}

  // Edge-to-edge immersive system navigation on mobile platforms
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.bgObsidian,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  // Initialize AudioService for background playback and notification panel on mobile platforms
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    try {
      await AudioService.init(
        builder: () => FreakAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.freak_shit_show.channel.audio',
          androidNotificationChannelName: 'freak player',
          androidNotificationChannelDescription: 'Background audio playback and controls for freak player',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidShowNotificationBadge: true,
          androidStopForegroundOnPause: false,
          androidResumeOnClick: true,
        ),
      );

      if (Platform.isAndroid) {
        try {
          await AudioService.androidForceEnableMediaButtons();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('AudioService init skipped or failed: $e');
    }
  }

  runApp(const FreakMusicPlayerApp());
}

class FreakMusicPlayerApp extends StatelessWidget {
  const FreakMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'freak player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeView(),
    );
  }
}
