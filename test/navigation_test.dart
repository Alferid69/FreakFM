import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/main.dart';
import 'package:freak_shit_show/models/song.dart';
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

Song _song(String title, String album) => Song(
      id: 'id_$title',
      title: title,
      artist: 'Artist',
      album: album,
      durationMs: 180000,
      filePath: '/music/$album/$title.mp3',
      fileSize: 1,
      folder: album,
      genre: 'Pop',
      dateAdded: 0,
    );

Future<void> settle(WidgetTester tester) async {
  // Alternate real time (so file I/O such as the library cache completes)
  // with frames (so animations and continuations run).
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Mark the seeded library as built by the current scanner so the app
    // doesn't replace it with a fresh device scan on launch.
    SharedPreferences.setMockInitialValues({'pref_scanner_version': LibraryService.scannerVersion});
    PathProviderPlatform.instance = _FakePathProvider(Directory.systemTemp.createTempSync('freak_nav_'));
    await LibraryService.instance.setSongs([
      _song('One', 'First Album'),
      _song('Two', 'First Album'),
      _song('Three', 'Second Album'),
    ]);
  });

  testWidgets('Back closes an open album, then leaves Library for Home, then exits', (tester) async {
    tester.view.physicalSize = const Size(412 * 2.6, 915 * 2.6);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FreakMusicPlayerApp());
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('library_filter_albums')));
    await settle(tester);
    await tester.tap(find.text('First Album').hitTestable().first);
    await settle(tester);
    expect(find.byKey(const ValueKey('collection_play')).hitTestable(), findsOneWidget);
    expect(find.text('One').hitTestable(), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

    // Back #1: closes the album, still in Your Library.
    expect(await navigator.maybePop(), isTrue);
    await settle(tester);
    expect(find.byKey(const ValueKey('collection_play')).hitTestable(), findsNothing);
    expect(find.text('Second Album').hitTestable(), findsOneWidget, reason: 'still on the album list');

    // Back #2: from the Library root to Home.
    expect(await navigator.maybePop(), isTrue);
    await settle(tester);
    expect(find.byKey(const ValueKey('home_filter_all')).hitTestable(), findsOneWidget, reason: 'back on Home');

    // On Home with nothing open, Back is no longer intercepted.
    expect(await navigator.maybePop(), isFalse);
  });

  testWidgets('re-tapping a tab returns to its first page', (tester) async {
    tester.view.physicalSize = const Size(412 * 2.6, 915 * 2.6);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FreakMusicPlayerApp());
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('collection_allSongs_all')));
    await settle(tester);
    expect(find.byKey(const ValueKey('collection_play')).hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav_library')));
    await settle(tester);
    expect(find.byKey(const ValueKey('collection_play')).hitTestable(), findsNothing);
    expect(find.byKey(const ValueKey('library_filter_albums')).hitTestable(), findsOneWidget);
  });
}
