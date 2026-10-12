import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_list_tile.dart';

class FoldersTabView extends StatefulWidget {
  final List<Song> songs;

  const FoldersTabView({
    super.key,
    required this.songs,
  });

  @override
  State<FoldersTabView> createState() => _FoldersTabViewState();
}

class _FoldersTabViewState extends State<FoldersTabView> {
  String? _selectedFolderPath;

  Future<void> _confirmHideFolder(FolderGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.spotifyCardElevated,
        title: Text('Hide "${group.folderName}"?', style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '${group.songs.length} tracks in\n${group.folderPath}\nwill be removed from your library and skipped by future scans. '
          'You can bring it back from Library folders.',
          style: const TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide', style: TextStyle(color: AppTheme.spotifyGreen)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LibraryService.instance.hideFolder(group.folderPath);
      if (mounted) setState(() => _selectedFolderPath = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Song>> folderMap = {};
    for (final song in widget.songs) {
      folderMap.putIfAbsent(song.folderPath, () => []).add(song);
    }

    final folderGroups = folderMap.entries.map((entry) {
      final name = p.basename(entry.key);
      return FolderGroup(
        folderPath: entry.key,
        folderName: name.isEmpty ? entry.value.first.folder : name,
        songs: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()));

    if (_selectedFolderPath != null && folderMap.containsKey(_selectedFolderPath)) {
      final group = folderGroups.firstWhere((g) => g.folderPath == _selectedFolderPath);
      return _buildFolderSongsView(group);
    }

    return ListView.builder(
      itemCount: folderGroups.length,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final group = folderGroups[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: AppTheme.softShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedFolderPath = group.folderPath;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderMedium),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.folder_rounded,
                          color: AppTheme.accentAmber,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.folderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.songs.length} tracks • ${_formatSize(group.totalSizeBytes)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.folderPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_off_outlined, color: AppTheme.textMuted, size: 22),
                      onPressed: () => _confirmHideFolder(group),
                      tooltip: 'Hide folder from library',
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accentAmber, size: 36),
                      onPressed: () {
                        AudioPlayerService.instance.playSong(group.songs.first, contextQueue: group.songs);
                      },
                      tooltip: 'Play folder',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderSongsView(FolderGroup group) {
    final player = AudioPlayerService.instance;
    final folderName = group.folderName;
    final folderSongs = group.songs;

    return Column(
      children: [
        // Back Button & Folder Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.bgSurface,
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => setState(() => _selectedFolderPath = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${folderSongs.length} tracks in folder',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_off_outlined, color: AppTheme.textMuted),
                onPressed: () => _confirmHideFolder(group),
                tooltip: 'Hide folder from library',
              ),
              ElevatedButton.icon(
                onPressed: () {
                  player.playSong(folderSongs.first, contextQueue: folderSongs);
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: const Color(0xFF1B1713),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Song list within this folder
        Expanded(
          child: ValueListenableBuilder<Song?>(
            valueListenable: player.currentSong,
            builder: (context, currentSong, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: player.isPlaying,
                builder: (context, isPlaying, _) {
                  return ListView.builder(
                    itemCount: folderSongs.length,
                    padding: const EdgeInsets.only(bottom: 90),
                    itemBuilder: (context, index) {
                      final song = folderSongs[index];
                      final isCurrent = currentSong?.id == song.id;

                      return TrackListTile(
                        song: song,
                        index: index + 1,
                        isCurrent: isCurrent,
                        isPlaying: isPlaying,
                        onTap: () => player.playSong(song, contextQueue: folderSongs),
                        onFavoriteToggle: () {
                          LibraryService.instance.toggleFavorite(song);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb > 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}
