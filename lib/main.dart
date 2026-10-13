import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/freak_audio_handler.dart';
import 'services/lyrics_service.dart';
import 'theme/app_theme.dart';
import 'views/root_shell.dart';

bool _initialized = false;

/// One-time app setup (lyrics cache, system UI, media session). Safe to call
/// more than once, which the integration tests rely on.
Future<void> initializeApp() async {
  if (_initialized) return;
  _initialized = true;
  WidgetsFlutterBinding.ensureInitialized();

  await LyricsService.instance.initCache();

  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (isMobile) {
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

  // Background playback + notification / lock screen / headset controls.
  if (isMobile || (!kIsWeb && Platform.isMacOS)) {
    try {
      await AudioService.init(
        builder: () => FreakAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.freak_shit_show.channel.audio',
          androidNotificationChannelName: 'FreakFM',
          androidNotificationChannelDescription: 'Playback controls for FreakFM',
          androidNotificationIcon: 'mipmap/ic_launcher',
          // Lets the notification be swiped away while paused instead of
          // pinning a foreground service forever.
          androidStopForegroundOnPause: true,
          androidResumeOnClick: true,
        ),
      );
    } catch (e) {
      debugPrint('AudioService init skipped or failed: $e');
    }
  }
}

void main() async {
  await initializeApp();
  runApp(const FreakMusicPlayerApp());
}

class FreakMusicPlayerApp extends StatelessWidget {
  const FreakMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreakFM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: RootShell(key: RootShell.globalKey),
    );
  }
}
