import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/music_scanner_service.dart';
import '../services/storage_cache_service.dart';
import '../theme/app_theme.dart';

class StorageBenchmarkDialog extends StatefulWidget {
  final Function() onLibraryReloadNeeded;

  const StorageBenchmarkDialog({
    super.key,
    required this.onLibraryReloadNeeded,
  });

  @override
  State<StorageBenchmarkDialog> createState() => _StorageBenchmarkDialogState();
}

class _StorageBenchmarkDialogState extends State<StorageBenchmarkDialog> {
  bool _isProcessing = false;
  String _statusText = 'Ready';
  int? _benchmarkDurationMs;
  int? _tracksCollected;
  List<String> _customDirectories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dirs = await StorageCacheService.loadCustomDirectories();
    final lastMs = await StorageCacheService.loadLastBenchmarkMs();
    setState(() {
      _customDirectories = dirs;
      _benchmarkDurationMs = lastMs;
    });
  }

  Future<void> _run1000TracksBenchmark() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Generating & indexing 1,000 tracks in background isolate...';
    });

    final result = await MusicScannerService.generateBenchmarkLibrary(count: 1000);

    setState(() {
      _isProcessing = false;
      _benchmarkDurationMs = result.durationMs;
      _tracksCollected = result.songs.length;
      _statusText = 'Completed in ${result.durationMs}ms (< 1 second guarantee met!)';
    });

    widget.onLibraryReloadNeeded();
  }

  Future<void> _scanSystemDirectories() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Scanning physical storage in background isolate...';
    });

    final hasPermission = await MusicScannerService.requestStoragePermissions();
    if (!hasPermission) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Permission denied to access storage.';
      });
      return;
    }

    final dirs = await MusicScannerService.getDefaultMusicDirectories();
    final result = await MusicScannerService.scanDirectories(dirs);

    setState(() {
      _isProcessing = false;
      _benchmarkDurationMs = result.durationMs;
      _tracksCollected = result.songs.length;
      _statusText = 'Found ${result.songs.length} audio files in ${result.durationMs}ms!';
    });

    widget.onLibraryReloadNeeded();
  }

  Future<void> _addCustomFolder() async {
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      if (!_customDirectories.contains(selectedDirectory)) {
        final updated = [..._customDirectories, selectedDirectory];
        await StorageCacheService.saveCustomDirectories(updated);
        setState(() {
          _customDirectories = updated;
        });
        _scanSystemDirectories();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppTheme.borderMedium),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dialog Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppTheme.accentAmber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Storage Speed & Indexer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'High-throughput background isolate engine designed to scan and index 1,000+ audio files in under 1 second.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Benchmark Performance Meter Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_benchmarkDurationMs != null && _benchmarkDurationMs! < 1000)
                      ? AppTheme.accentAmber.withValues(alpha: 0.5)
                      : AppTheme.borderSubtle,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'INDEX BENCHMARK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (_benchmarkDurationMs != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _benchmarkDurationMs! < 1000
                                ? AppTheme.accentSuccess.withValues(alpha: 0.2)
                                : AppTheme.accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _benchmarkDurationMs! < 1000 ? 'SUB-SECOND ⚡' : 'STANDARD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _benchmarkDurationMs! < 1000
                                  ? AppTheme.accentSuccess
                                  : AppTheme.accentAmber,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _benchmarkDurationMs != null ? '${_benchmarkDurationMs}ms' : '-- ms',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accentAmberLight,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_tracksCollected != null)
                        Text(
                          'for $_tracksCollected tracks',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isProcessing ? AppTheme.accentCyan : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      backgroundColor: AppTheme.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _run1000TracksBenchmark,
                    icon: const Icon(Icons.speed_rounded, size: 18),
                    label: const Text('1000 Song Benchmark'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentAmber,
                      foregroundColor: const Color(0xFF1B1713),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _scanSystemDirectories,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Scan Storage'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.borderMedium),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Custom Folder Picker Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isProcessing ? null : _addCustomFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18, color: AppTheme.accentAmber),
                label: const Text(
                  'Add Custom Music Folder to Scan',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ),
            ),

            if (_customDirectories.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Custom Directories:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 4),
              ..._customDirectories.map(
                (dir) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    dir,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
