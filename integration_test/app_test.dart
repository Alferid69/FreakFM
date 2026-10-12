import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/main.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/audio_player_service.dart';
import 'package:freak_shit_show/services/library_service.dart';
import 'package:freak_shit_show/services/music_scanner_service.dart';
import 'package:freak_shit_show/services/storage_cache_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'test_audio.dart';

/// Waits (in real time) until [condition] holds, pumping frames meanwhile.
Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for ${reason ?? 'condition'}');
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Points every app storage location into the test sandbox so running the
/// suite never touches a real user's library, lyrics or artwork cache.
class _SandboxPathProvider extends PathProviderPlatform {
  _SandboxPathProvider(this.root);
  final Directory root;

  String _dir(String name) => (Directory(p.join(root.path, name))..createSync(recursive: true)).path;

  @override
  Future<String?> getTemporaryPath() async => _dir('tmp');
  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('docs');
  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');
  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');
  @override
  Future<String?> getExternalStoragePath() async => _dir('external');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    final temp = await getTemporaryDirectory();
    sandbox = Directory(p.join(temp.path, 'freak_it_${DateTime.now().millisecondsSinceEpoch}'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _SandboxPathProvider(sandbox);
  });

  tearDownAll(() async {
    await AudioPlayerService.instance.pause();
    try {
      sandbox.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('library scanner', () {
    testWidgets('indexes every song in the scanned folders except hidden ones', (tester) async {
      final root = Directory(p.join(sandbox.path, 'scan'))..createSync();
      final music = p.join(root.path, 'Music');
      final download = p.join(root.path, 'Download');

      // Found, wherever they sit inside the scanned folders.
      writeTaggedWav(p.join(music, 'whatever.wav'),
          seconds: 1, title: 'Tagged Title', artist: 'Tagged Artist', album: 'Tagged Album', genre: 'hip hop');
      writeTaggedWav(p.join(music, 'Album', '01 - Some Artist - From Name.wav'), seconds: 1);
      writeTaggedWav(p.join(download, 'downloaded.wav'), seconds: 1, title: 'Downloaded');
      writeTaggedWav(p.join(download, 'Telegram Audio', 't.wav'), seconds: 1, title: 'From Telegram');
      writeTaggedWav(p.join(music, 'AppCache', 'c.wav'), seconds: 1, title: 'Has nomedia');
      File(p.join(music, 'AppCache', '.nomedia')).createSync();

      // Skipped: dot-folders, app "data" folders, and folders the user hid.
      writeTaggedWav(p.join(music, '.hidden', 'h.wav'), seconds: 1, title: 'Dot folder');
      writeTaggedWav(p.join(music, 'Android', 'data', 'com.example', '002.wav'), seconds: 1, title: 'App data');
      writeTaggedWav(p.join(download, 'Recitations', 'r.wav'), seconds: 1, title: 'User hidden');

      final result = await MusicScannerService.scanLibrary(
        roots: [music, download],
        excluded: [p.join(download, 'Recitations')],
        includeMediaStore: false,
      );

      final titles = result.songs.map((s) => s.title).toSet();
      expect(titles, {'Tagged Title', 'From Name', 'Downloaded', 'From Telegram', 'Has nomedia'});

      final tagged = result.songs.firstWhere((s) => s.title == 'Tagged Title');
      expect(tagged.artist, 'Tagged Artist');
      expect(tagged.album, 'Tagged Album');
      expect(tagged.genre, 'Hip-Hop / Rap');
      expect(tagged.durationMs, closeTo(1000, 50));
      expect(tagged.sampleRate, 8000);

      final fromName = result.songs.firstWhere((s) => s.title == 'From Name');
      expect(fromName.artist, 'Some Artist');

      // Ids are stable across scans.
      final again = await MusicScannerService.scanLibrary(
        roots: [music, download],
        excluded: [p.join(download, 'Recitations')],
        includeMediaStore: false,
      );
      expect(again.songs.map((s) => s.id).toSet(), result.songs.map((s) => s.id).toSet());
    });
  });

  group('app', () {
    late List<Song> seeded;

    setUpAll(() async {
      final dir = p.join(sandbox.path, 'library');
      seeded = [
        for (final (i, name) in ['Alpha Tone', 'Bravo Tone', 'Charlie Tone'].indexed)
          MusicScannerService.parseAudioFile(
            writeTaggedWav(
              p.join(dir, '$name.wav'),
              seconds: 6,
              title: name,
              artist: 'Test Artist',
              album: 'Integration',
              frequency: 330.0 + 110 * i,
            ),
          )!,
      ];
      await LibraryService.instance.setSongs(seeded);
      await initializeApp();
    });

    testWidgets('shows the library, searches, and persists favourites', (tester) async {
      await tester.pumpWidget(const FreakMusicPlayerApp());
      await waitFor(tester, () => find.text('Alpha Tone').evaluate().isNotEmpty, reason: 'library to load');

      expect(find.text('Bravo Tone'), findsWidgets);
      expect(find.text('Charlie Tone'), findsWidgets);

      // Search narrows the list.
      await tester.tap(find.byKey(const ValueKey('search_button')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('search_field')), 'bravo');
      await waitFor(tester, () => find.text('Alpha Tone').evaluate().isEmpty, reason: 'search filter');
      expect(find.text('Bravo Tone'), findsWidgets);

      // Favourite it and make sure it is written to disk.
      final bravo = seeded.firstWhere((s) => s.title == 'Bravo Tone');
      await tester.tap(find.byKey(ValueKey('favorite_${bravo.id}')));
      await tester.pump();
      expect(LibraryService.instance.songs.value.firstWhere((s) => s.id == bravo.id).isFavorite, isTrue);

      await LibraryService.instance.flush();
      final saved = await StorageCacheService.loadCachedSongs();
      expect(saved!.firstWhere((s) => s.id == bravo.id).isFavorite, isTrue);

      // Clear the search again.
      await tester.tap(find.byKey(const ValueKey('search_button')));
      await waitFor(tester, () => find.text('Alpha Tone').evaluate().isNotEmpty, reason: 'search reset');
    });

    testWidgets('plays a track, advances, and counts the play', (tester) async {
      final player = AudioPlayerService.instance;
      player.setRepeatMode(AudioRepeatMode.off);
      player.setShuffle(false);

      await tester.pumpWidget(const FreakMusicPlayerApp());
      await waitFor(tester, () => find.text('Alpha Tone').evaluate().isNotEmpty, reason: 'library to load');

      final alpha = seeded.firstWhere((s) => s.title == 'Alpha Tone');
      final playsBefore = LibraryService.instance.songs.value.firstWhere((s) => s.id == alpha.id).playCount;

      await tester.tap(find.byKey(ValueKey('track_${alpha.id}')));
      await waitFor(tester, () => player.currentSong.value?.id == alpha.id, reason: 'song to load');
      await waitFor(tester, () => player.isPlaying.value, reason: 'playback to start');
      await waitFor(tester, () => player.position.value > const Duration(milliseconds: 500),
          reason: 'position to advance');

      expect(find.byKey(const ValueKey('mini_player')), findsOneWidget);
      expect(
        LibraryService.instance.songs.value.firstWhere((s) => s.id == alpha.id).playCount,
        playsBefore + 1,
      );
      // The real decoded duration replaces the metadata value.
      expect(player.duration.value.inMilliseconds, closeTo(6000, 300));

      // Pause / resume.
      await player.pause();
      await waitFor(tester, () => !player.isPlaying.value, reason: 'pause');
      await player.play();
      await waitFor(tester, () => player.isPlaying.value, reason: 'resume');

      // Skip forward to the next track in the queue.
      await player.next();
      await waitFor(tester, () => player.currentSong.value?.title == 'Bravo Tone', reason: 'next track');

      // Seeking near the end lets the track finish and auto-advance.
      await waitFor(tester, () => player.duration.value > Duration.zero, reason: 'duration');
      await player.seek(player.duration.value - const Duration(milliseconds: 600));
      await waitFor(tester, () => player.currentSong.value?.title == 'Charlie Tone',
          reason: 'auto-advance on completion');

      await player.pause();
    });

    testWidgets('Back closes an open album before leaving the tab', (tester) async {
      await tester.pumpWidget(const FreakMusicPlayerApp());
      await waitFor(tester, () => find.text('Alpha Tone').evaluate().isNotEmpty, reason: 'library to load');

      // On phone widths the Albums pill starts off-screen; scroll it in first.
      await tester.ensureVisible(find.byKey(const ValueKey('tab_Albums')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('tab_Albums')));
      // Wait until the page transition has finished and the card can be hit.
      await waitFor(tester, () => find.text('Integration').hitTestable().evaluate().isNotEmpty,
          reason: 'album grid');
      await tester.tap(find.text('Integration').hitTestable().first);
      await waitFor(tester, () => find.text('Play Album').evaluate().isNotEmpty, reason: 'album detail');

      // The system Back button ends up in Navigator.maybePop; calling it
      // directly can never close the app if Back isn't intercepted.
      Future<bool> pressBack() => tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();

      // First Back: back to the album grid, still on the Albums tab.
      expect(await pressBack(), isTrue);
      await waitFor(tester, () => find.text('Play Album').evaluate().isEmpty, reason: 'album closed');
      expect(find.text('Integration'), findsWidgets);

      // Second Back: return to the Songs tab instead of quitting.
      expect(await pressBack(), isTrue);
      await waitFor(tester, () => find.byKey(const ValueKey('play_all_button')).evaluate().isNotEmpty,
          reason: 'songs tab');
    });

    testWidgets('song menu queues "Play next" right after the current song', (tester) async {
      final player = AudioPlayerService.instance;
      final alpha = seeded.firstWhere((s) => s.title == 'Alpha Tone');
      final charlie = seeded.firstWhere((s) => s.title == 'Charlie Tone');
      await player.playSong(alpha, contextQueue: [alpha]);

      await tester.pumpWidget(const FreakMusicPlayerApp());
      await waitFor(tester, () => find.byKey(ValueKey('more_${charlie.id}')).evaluate().isNotEmpty,
          reason: 'track list');

      await tester.tap(find.byKey(ValueKey('more_${charlie.id}')));
      await waitFor(tester, () => find.byKey(const ValueKey('option_play_next')).evaluate().isNotEmpty,
          reason: 'song menu');
      await tester.tap(find.byKey(const ValueKey('option_play_next')));
      await tester.pump();

      final q = player.queue.value;
      final i = player.queueIndex.value;
      expect(q[i].id, alpha.id);
      expect(q[i + 1].id, charlie.id);
      await player.pause();
    });

    testWidgets('a missing file reports an error instead of fake playback', (tester) async {
      final player = AudioPlayerService.instance;
      await tester.pumpWidget(const FreakMusicPlayerApp());
      await tester.pump();

      final ghost = Song(
        id: 'ghost',
        title: 'Ghost Track',
        artist: 'Nobody',
        album: 'Nowhere',
        durationMs: 1000,
        filePath: p.join(sandbox.path, 'does_not_exist.mp3'),
        fileSize: 1,
        folder: 'x',
        genre: 'Music',
        dateAdded: 0,
      );

      final errors = <String>[];
      final sub = player.errors.listen(errors.add);
      await player.playSong(ghost, contextQueue: [ghost]);
      await waitFor(tester, () => errors.isNotEmpty, reason: 'error event');
      await sub.cancel();

      expect(errors.single, contains('Ghost Track'));
      expect(player.isPlaying.value, isFalse);
    });
  });
}
