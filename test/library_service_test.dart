import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/audio_player_service.dart';
import 'package:freak_shit_show/services/library_service.dart';
import 'package:freak_shit_show/services/storage_cache_service.dart';
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

Song _song(String id, String path) => Song(
      id: id,
      title: id,
      artist: 'Artist',
      album: 'Album',
      durationMs: 0,
      filePath: path,
      fileSize: 1,
      folder: 'Music',
      genre: 'Music',
      dateAdded: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('freak_lib_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('favourites and play counts survive a save/load round trip', () async {
    final lib = LibraryService.instance;
    final a = _song('a', '/m/a.mp3');
    final b = _song('b', '/m/b.mp3');
    await lib.setSongs([a, b]);

    lib.toggleFavorite(a);
    lib.recordPlay(b);
    lib.recordPlay(b);
    lib.updateDuration(b, const Duration(minutes: 3));
    await lib.flush();

    final reloaded = await StorageCacheService.loadCachedSongs();
    expect(reloaded, isNotNull);
    final byId = {for (final s in reloaded!) s.id: s};
    expect(byId['a']!.isFavorite, isTrue);
    expect(byId['b']!.playCount, 2);
    expect(byId['b']!.durationMs, 180000);
  });

  test('changes to a different object for the same track reach the library', () async {
    final lib = LibraryService.instance;
    final libraryCopy = _song('x', '/m/x.mp3');
    await lib.setSongs([libraryCopy]);

    final playerCopy = _song('x', '/m/x.mp3'); // e.g. held by the player after a rescan
    lib.toggleFavorite(playerCopy);

    expect(lib.songs.value.single.isFavorite, isTrue);
    expect(playerCopy.isFavorite, isTrue);
  });

  test('hiding a folder removes its songs and remembers the exclusion', () async {
    final lib = LibraryService.instance;
    await lib.setSongs([
      _song('keep', '/storage/emulated/0/Music/keep.mp3'),
      _song('hide', '/storage/emulated/0/Music/Recitations/001.mp3'),
    ]);

    await lib.hideFolder('/storage/emulated/0/Music/Recitations');

    expect(lib.songs.value.map((s) => s.id), ['keep']);
    expect(await StorageCacheService.loadExcludedDirectories(), ['/storage/emulated/0/Music/Recitations']);

    await lib.unhideFolder('/storage/emulated/0/Music/Recitations');
    expect(await StorageCacheService.loadExcludedDirectories(), isEmpty);
  });

  test('a corrupt-free write leaves no temp file behind', () async {
    await StorageCacheService.saveCachedSongs([_song('a', '/m/a.mp3')]);
    final leftovers = tempDir.listSync().where((e) => e.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });

  test('libraries from older scanner rules are flagged for one rescan', () async {
    expect(await LibraryService.instance.isScanOutdated(), isTrue);
    await StorageCacheService.saveScannerVersion(LibraryService.scannerVersion);
    expect(await LibraryService.instance.isScanOutdated(), isFalse);
  });

  test('equalizer presets interpolate on a log-frequency scale', () {
    final curve = AudioPlayerService.equalizerPresets['Bass Boost']!;
    expect(AudioPlayerService.presetGainAt(curve, 30), curve.first);
    expect(AudioPlayerService.presetGainAt(curve, 60), curve[0]);
    expect(AudioPlayerService.presetGainAt(curve, 20000), curve.last);
    final mid = AudioPlayerService.presetGainAt(curve, 117.5); // ~geometric mean of 60 and 230
    expect(mid, closeTo((curve[0] + curve[1]) / 2, 0.05));
  });
}
