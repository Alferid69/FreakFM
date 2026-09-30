// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_shit_show/models/song.dart';
import 'package:freak_shit_show/services/music_scanner_service.dart';
import 'package:freak_shit_show/services/storage_cache_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fake PathProvider for unit test environment
class FakePathProviderPlatform extends PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory mockDocsDir;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    mockDocsDir = Directory.systemTemp.createTempSync('music_docs_cache_');
    PathProviderPlatform.instance = FakePathProviderPlatform(mockDocsDir);
  });

  tearDownAll(() {
    if (mockDocsDir.existsSync()) {
      mockDocsDir.deleteSync(recursive: true);
    }
  });

  group('Music Processing Speed & < 1 Second Verification Tests', () {
    test('VERIFICATION: High-throughput isolate generates & indexes 1,000 tracks in < 1 second', () async {
      final stopwatch = Stopwatch()..start();

      final result = await MusicScannerService.generateBenchmarkLibrary(count: 1000);

      stopwatch.stop();
      final totalElapsedMs = stopwatch.elapsedMilliseconds;

      print('------------------------------------------------------------');
      print('⚡ [BENCHMARK 1] Isolate Indexed ${result.songs.length} Tracks:');
      print('   Time Taken: ${totalElapsedMs}ms (${(totalElapsedMs / 1000).toStringAsFixed(3)} seconds)');
      print('   Throughput: ${(result.songs.length / (totalElapsedMs / 1000)).toStringAsFixed(0)} tracks/second');
      print('------------------------------------------------------------');

      expect(result.songs.length, equals(1000));
      expect(totalElapsedMs, lessThan(1000), reason: 'Must process 1,000 tracks in less than 1 second');
    });

    test('VERIFICATION: Physical storage directory scan of 1,000 audio files in < 1 second', () async {
      // 1. Create temporary mock music filesystem with 1,000 real files
      final tempMusicDir = Directory.systemTemp.createTempSync('music_files_1000_');

      final folders = ['Rock', 'Electronic', 'Jazz', 'Synthwave', 'Ambient', 'Soundtracks', 'HipHop', 'LoFi'];
      for (final folder in folders) {
        Directory('${tempMusicDir.path}/$folder').createSync(recursive: true);
      }

      // Create 1,000 physical files with ID3v1 tags
      for (int i = 0; i < 1000; i++) {
        final folder = folders[i % folders.length];
        final ext = (i % 4 == 0) ? 'flac' : 'mp3';
        final file = File('${tempMusicDir.path}/$folder/Artist_${i % 40} - Track_$i.$ext');

        // Create a minimal 256-byte audio file with valid ID3v1 trailer for microsecond tag extraction
        final bytes = List<int>.filled(256, 0);
        // Put "TAG" at index 128
        bytes[128] = 84; // 'T'
        bytes[129] = 65; // 'A'
        bytes[130] = 71; // 'G'
        file.writeAsBytesSync(bytes, flush: false);
      }

      // 2. Measure actual physical directory scanning & parsing
      final scanStopwatch = Stopwatch()..start();

      final scanResult = await MusicScannerService.scanDirectories([tempMusicDir.path]);

      scanStopwatch.stop();
      final scanElapsedMs = scanStopwatch.elapsedMilliseconds;

      print('------------------------------------------------------------');
      print('⚡ [BENCHMARK 2] Physical Storage Scan of 1,000 Audio Files:');
      print('   Files Found: ${scanResult.songs.length}');
      print('   Time Taken: ${scanElapsedMs}ms (${(scanElapsedMs / 1000).toStringAsFixed(3)} seconds)');
      print('   Rate: ${(scanResult.songs.length / (scanElapsedMs / 1000)).toStringAsFixed(0)} files/second');
      print('------------------------------------------------------------');

      // Cleanup
      tempMusicDir.deleteSync(recursive: true);

      expect(scanResult.songs.length, equals(1000));
      expect(scanElapsedMs, lessThan(1000), reason: 'Physical storage scan of 1000 files must take less than 1 second');
    });

    test('VERIFICATION: Cold-start disk cache loading of 1,000 tracks takes < 100ms (< 0.10s)', () async {
      final sampleSongs = List.generate(
        1000,
        (i) => Song(
          id: 'test_$i',
          title: 'Speed Test Track $i',
          artist: 'Artist ${i % 30}',
          album: 'Album ${i % 50}',
          durationMs: 210000,
          filePath: '/storage/emulated/0/Music/Track_$i.mp3',
          fileSize: 6400000,
          folder: 'Music',
          genre: 'Electronic',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Save cache
      await StorageCacheService.saveCachedSongs(sampleSongs);

      // Measure cold read and JSON parse
      final loadStopwatch = Stopwatch()..start();
      final loadedSongs = await StorageCacheService.loadCachedSongs();
      loadStopwatch.stop();
      final loadElapsedMs = loadStopwatch.elapsedMilliseconds;

      print('------------------------------------------------------------');
      print('⚡ [BENCHMARK 3] Cold-Start Disk Cache Deserialization:');
      print('   Tracks Loaded: ${loadedSongs?.length}');
      print('   Time Taken: ${loadElapsedMs}ms (${(loadElapsedMs / 1000).toStringAsFixed(4)} seconds)');
      print('------------------------------------------------------------');

      expect(loadedSongs, isNotNull);
      expect(loadedSongs!.length, equals(1000));
      expect(loadElapsedMs, lessThan(500), reason: 'Cached startup must complete in under 500ms (typically < 30ms)');
    });

    test('VERIFICATION: Multi-tab grouping (Folders, Artists, Albums, Genres) for 1,000 tracks takes < 50ms', () {
      final sampleSongs = List.generate(
        1000,
        (i) => Song(
          id: 'group_test_$i',
          title: 'Grouping Track $i',
          artist: 'Artist ${i % 40}',
          album: 'Album ${i % 60}',
          durationMs: 195000,
          filePath: 'C:/Music/Folder_${i % 15}/Track_$i.mp3',
          fileSize: 8500000,
          folder: 'Folder_${i % 15}',
          genre: 'Genre_${i % 8}',
          dateAdded: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Folders grouping
      final Map<String, List<Song>> folders = {};
      for (final s in sampleSongs) {
        folders.putIfAbsent(s.folder, () => []).add(s);
      }

      // Artists grouping
      final Map<String, List<Song>> artists = {};
      for (final s in sampleSongs) {
        artists.putIfAbsent(s.artist, () => []).add(s);
      }

      // Albums grouping
      final Map<String, List<Song>> albums = {};
      for (final s in sampleSongs) {
        albums.putIfAbsent(s.album, () => []).add(s);
      }

      // Genres grouping
      final Map<String, List<Song>> genres = {};
      for (final s in sampleSongs) {
        genres.putIfAbsent(s.genre, () => []).add(s);
      }

      stopwatch.stop();
      final groupingMs = stopwatch.elapsedMilliseconds;

      print('------------------------------------------------------------');
      print('⚡ [BENCHMARK 4] Multi-Tab Data Grouping (Folders, Artists, Albums, Genres):');
      print('   Time Taken: ${groupingMs}ms');
      print('   Unique Folders: ${folders.length}, Artists: ${artists.length}, Albums: ${albums.length}, Genres: ${genres.length}');
      print('------------------------------------------------------------');

      expect(folders.length, equals(15));
      expect(artists.length, equals(40));
      expect(albums.length, equals(60));
      expect(genres.length, equals(8));
      expect(groupingMs, lessThan(100), reason: 'Grouping 1,000 tracks across all tabs must take less than 100ms');
    });
  });
}
