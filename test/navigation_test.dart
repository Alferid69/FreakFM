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
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider(Directory.systemTemp.createTempSync('freak_nav_'));
    await LibraryService.instance.setSongs([
      _song('One', 'First Album'),
      _song('Two', 'First Album'),
      _song('Three', 'Second Album'),
    ]);
  });

  testWidgets('Back closes an open album, then returns to Songs', (tester) async {
    tester.view.physicalSize = const Size(412 * 2.6, 915 * 2.6);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FreakMusicPlayerApp());
    await settle(tester);
    expect(find.text('One'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('tab_Albums')));
    await tester.tap(find.byKey(const ValueKey('tab_Albums')));
    await settle(tester);

    await tester.tap(find.text('First Album').hitTestable().first);
    await settle(tester);
    expect(find.text('Play Album'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

    expect(await navigator.maybePop(), isTrue);
    await settle(tester);
    expect(find.text('Play Album'), findsNothing);
    expect(find.text('Second Album'), findsOneWidget, reason: 'still on the album grid');

    expect(await navigator.maybePop(), isTrue);
    await settle(tester);
    expect(find.byKey(const ValueKey('play_all_button')), findsOneWidget, reason: 'back on Songs');

    // On Songs with nothing open, Back is no longer intercepted.
    expect(await navigator.maybePop(), isFalse);
  });
}
