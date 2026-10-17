import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../services/music_scanner_service.dart';
import '../services/storage_cache_service.dart';
import '../theme/app_theme.dart';
import '../services/media_store_channel.dart';
import '../widgets/equalizer_dialog.dart';

/// Settings: library folders (added / hidden), rescan and playback options.
class SettingsPage extends StatefulWidget {
  final VoidCallback onAddFolder;
  final Future<void> Function() onRescan;

  const SettingsPage({super.key, required this.onAddFolder, required this.onRescan});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final library = LibraryService.instance;
  List<String> _defaults = const [];
  List<String> _custom = const [];
  List<String> _hidden = const [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final defaults = await MusicScannerService.defaultLibraryRoots();
    final custom = await StorageCacheService.loadCustomDirectories();
    final hidden = await StorageCacheService.loadExcludedDirectories();
    if (!mounted) return;
    setState(() {
      _defaults = defaults;
      _custom = custom;
      _hidden = hidden;
    });
  }

  @override
  void dispose() {
    // Folder changes take effect with a rescan when leaving the page.
    if (_changed) widget.onRescan();
    super.dispose();
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );

  Widget _folder(String path, {Widget? trailing}) => ListTile(
        leading: const Icon(Icons.folder_rounded, color: AppTheme.spotifyLightGrey),
        title: Text(path, style: const TextStyle(fontSize: 14)),
        trailing: trailing,
      );

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<bool>(
        valueListenable: library.isScanning,
        builder: (context, scanning, _) => ListView(
          padding: const EdgeInsets.only(bottom: 160),
          children: [
            _section('Library'),
            ListTile(
              key: const ValueKey('settings_rescan'),
              leading: scanning
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              title: const Text('Rescan library'),
              subtitle: Text(
                scanning ? 'Scanning…' : 'Finds new songs; keeps your likes and play counts',
                style: const TextStyle(color: AppTheme.spotifyLightGrey),
              ),
              onTap: scanning ? null : widget.onRescan,
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Add a folder'),
              subtitle: const Text(
                'For songs Android\'s media library misses',
                style: TextStyle(color: AppTheme.spotifyLightGrey),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onAddFolder();
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'All music on your device is found automatically. Hide a folder from its page or a song\'s ⋮ menu '
                'to keep it out of your library.',
                style: TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey, height: 1.4),
              ),
            ),
            if (_custom.isNotEmpty) ...[
              _section('Folders you added'),
              for (final d in _custom)
                _folder(
                  d,
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () async {
                      await library.removeFolder(d);
                      _changed = true;
                      setState(() => _custom = List.of(_custom)..remove(d));
                    },
                  ),
                ),
            ],
            if (_hidden.isNotEmpty) ...[
              _section('Hidden folders'),
              for (final d in _hidden)
                _folder(
                  d,
                  trailing: TextButton(
                    onPressed: () async {
                      await library.unhideFolder(d);
                      _changed = true;
                      setState(() => _hidden = List.of(_hidden)..remove(d));
                    },
                    child: const Text('Unhide', style: TextStyle(color: AppTheme.spotifyGreen)),
                  ),
                ),
            ],
            if (_defaults.isNotEmpty) ...[
              _section('Also scanned'),
              for (final d in _defaults) _folder(d),
            ],
            _section('Playback'),
            FutureBuilder<bool>(
              future: MediaStoreChannel.isIgnoringBatteryOptimizations(),
              builder: (context, snap) {
                final ok = snap.data ?? true;
                return ListTile(
                  key: const ValueKey('settings_battery'),
                  leading: Icon(ok ? Icons.battery_charging_full_rounded : Icons.battery_alert_rounded,
                      color: ok ? AppTheme.spotifyGreen : Colors.amber),
                  title: const Text('Keep playing with the screen off'),
                  subtitle: Text(
                    ok
                        ? 'Battery optimization is off for FreakFM'
                        : 'Tap, find FreakFM and choose "Don\'t optimize" so Android doesn\'t stop your music',
                    style: const TextStyle(color: AppTheme.spotifyLightGrey),
                  ),
                  onTap: ok ? null : () async {
                    await MediaStoreChannel.openBatterySettings();
                  },
                );
              },
            ),
            if (player.equalizerSupported) ...[
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Equalizer'),
                onTap: () => showDialog(context: context, builder: (_) => const EqualizerDialog()),
              ),
            ],
            _section('About'),
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('FreakFM'),
              subtitle: Text('Offline music player • lyrics from LRCLIB & Lyrics.ovh',
                  style: TextStyle(color: AppTheme.spotifyLightGrey)),
            ),
          ],
        ),
      ),
    );
  }
}
