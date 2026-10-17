import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/main.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/online_music_service.dart';
import 'package:freak_shit_show/services/audio_player_service.dart';
import 'package:freak_shit_show/services/library_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
  @override
  Future<String?> getTemporaryPath() async => dir.path;
  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens every screen at phone size. The test font is wider than real
/// text, so this doubles as an overflow check for long titles / big fonts.
class _FakeProvider implements OnlineMusicProvider {
  @override
  String get name => 'Fake';

  Song _s() => Song(
        id: 'fake:1',
        title: 'Cloud Song',
        artist: 'Streamer',
        album: 'Fake',
        durationMs: 120000,
        filePath: 'https://example.com/1.mp3',
        fileSize: 0,
        folder: 'Fake',
        genre: 'Music',
        dateAdded: 0,
      );

  @override
  Future<List<Song>> search(String query, {int limit = 30}) async => [_s()];

  @override
  Future<List<Song>> trending({int limit = 30, String? genre}) async => [_s()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'pref_scanner_version': LibraryService.scannerVersion});
    PathProviderPlatform.instance = _FakePathProvider(Directory.systemTemp.createTempSync('freak_smoke_'));
    final now = DateTime.now().millisecondsSinceEpoch;
    await LibraryService.instance.setSongs([
      for (var i = 0; i < 12; i++)
        Song(
          id: 's$i',
          title: i == 0 ? 'A very long song title that keeps going and going' : 'Song $i',
          artist: i.isEven ? 'An Artist With A Really Long Name' : 'Short',
          album: 'Album ${i % 4}',
          durationMs: 200000,
          filePath: '/music/f${i % 3}/s$i.mp3',
          fileSize: 1000,
          folder: 'f${i % 3}',
          genre: ['Pop', 'Hip-Hop / Rap', 'Dance & Electronic'][i % 3],
          dateAdded: now - i * 1000,
          isFavorite: i % 3 == 0,
          playCount: i,
          lastPlayedAt: i.isEven ? now - i * 1000 : null,
        ),
    ]);
  });

  testWidgets('every screen lays out without errors', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3); // a small phone
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FreakMusicPlayerApp());
    await settle(tester);

    for (final f in ['albums', 'artists', 'all']) {
      await tapVisible(tester, find.byKey(ValueKey('home_filter_$f')));
      await settle(tester);
    }

    await tester.tap(find.byKey(const ValueKey('nav_search')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('search_field')), 'song');
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('search_field')), 'zzzz');
    await settle(tester);
    expect(find.textContaining('Couldn\'t find'), findsOneWidget);

    // Online search through the provider.
    OnlineMusic.provider = _FakeProvider();
    addTearDown(() => OnlineMusic.provider = AudiusProvider());
    await tester.enterText(find.byKey(const ValueKey('search_field')), '');
    await tester.tap(find.byKey(const ValueKey('scope_online')));
    await settle(tester);
    expect(find.text('Trending on Fake'), findsOneWidget);
    expect(find.text('Cloud Song'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('search_field')), 'cloud');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await settle(tester);
    expect(find.text('Results for "cloud"'), findsOneWidget);
    expect(find.text('Cloud Song'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scope_device')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await settle(tester);
    for (final f in ['artists', 'albums', 'folders', 'genres']) {
      await tapVisible(tester, find.byKey(ValueKey('library_filter_$f')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('library_view_toggle')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('library_view_toggle')));
      await settle(tester);
      await tapVisible(tester, find.byKey(const ValueKey('library_filter_clear')));
      await settle(tester);
    }

    await tapVisible(tester, find.byKey(const ValueKey('library_filter_artists')));
    await settle(tester);
    await tester.tap(find.text('An Artist With A Really Long Name').hitTestable().first);
    await settle(tester);
    expect(find.byKey(const ValueKey('collection_play')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('collection_back')).hitTestable());
    await settle(tester);

    // Settings from the avatar.
    await tester.tap(find.byType(CircleAvatar).hitTestable().first);
    await settle(tester);
    expect(find.text('Rescan library'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    // Now playing, queue and lyrics.
    final player = AudioPlayerService.instance;
    player.currentSong.value = LibraryService.instance.songs.value.first;
    player.playingFrom.value = 'Album • Album 0';
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('mini_player')));
    await settle(tester);
    expect(find.text('PLAYING FROM ALBUM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('np_queue')));
    await settle(tester);
    expect(find.text('Now playing'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('queue_close')));
    await settle(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('np_lyrics_card')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lyrics_close')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('np_close')));
    await settle(tester);
    player.currentSong.value = null;
  });
}
