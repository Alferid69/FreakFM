import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import 'song_artwork_widget.dart';

/// Per-song actions (Play next, Add to queue, Like, Hide folder, Info),
/// opened from a track's ⋮ button or by long-pressing it.
Future<void> showSongOptions(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.spotifyCardElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _SongOptionsSheet(song: song, hostContext: context),
  );
}

class _SongOptionsSheet extends StatelessWidget {
  final Song song;
  final BuildContext hostContext;

  const _SongOptionsSheet({required this.song, required this.hostContext});

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(hostContext);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    final library = LibraryService.instance;

    Widget action(IconData icon, String label, VoidCallback onTap, {Key? key, Color? color}) => ListTile(
          key: key,
          leading: Icon(icon, color: color ?? AppTheme.spotifyLightGrey),
          title: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.spotifySubdued, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Row(
                children: [
                  SongArtworkWidget(song: song, size: 52, borderRadius: 6, showPlayingBadge: false),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${song.artist} • ${song.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppTheme.spotifyLightGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF333333), height: 1),
            action(Icons.playlist_play_rounded, 'Play next', key: const ValueKey('option_play_next'), () {
              player.playNext(song);
              _toast('"${song.title}" will play next');
            }),
            action(Icons.queue_music_rounded, 'Add to queue', key: const ValueKey('option_add_queue'), () {
              player.addToQueue(song);
              _toast('Added "${song.title}" to the queue');
            }),
            action(
              song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              song.isFavorite ? 'Remove from Liked Songs' : 'Add to Liked Songs',
              color: song.isFavorite ? AppTheme.spotifyGreen : null,
              () => library.toggleFavorite(song),
            ),
            action(Icons.info_outline_rounded, 'Song info', () => _showInfo(hostContext, song)),
            if (!song.filePath.startsWith('content://'))
              action(Icons.visibility_off_outlined, 'Hide this folder', () => _confirmHide(hostContext, song)),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmHide(BuildContext context, Song song) async {
    final folder = song.folderPath;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.spotifyCardElevated,
        title: const Text('Hide this folder?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Everything in\n$folder\nwill be removed from your library and skipped by future scans. '
          'You can bring it back from Library folders.',
          style: const TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hide')),
        ],
      ),
    );
    if (ok == true) await LibraryService.instance.hideFolder(folder);
  }

  static void _showInfo(BuildContext context, Song song) {
    final added = DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.dateAdded));
    final rows = <(String, String)>[
      ('Title', song.title),
      ('Artist', song.artist),
      ('Album', song.album),
      if (song.year != null) ('Year', '${song.year}'),
      ('Genre', song.genre),
      ('Duration', song.formattedDuration),
      ('Format', song.qualityBadge),
      ('Size', song.formattedFileSize),
      ('Plays', '${song.playCount}'),
      ('Added', added),
      ('Location', song.filePath),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.spotifyCardElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Song info', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.spotifySubdued)),
                      ),
                      Expanded(
                        child: SelectableText(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
