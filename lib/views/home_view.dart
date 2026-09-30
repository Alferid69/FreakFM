import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/music_scanner_service.dart';
import '../services/storage_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/top_tab_bar.dart';
import '../widgets/volume_controller.dart';
import 'albums_tab_view.dart';
import 'artists_tab_view.dart';
import 'favorites_tab_view.dart';
import 'folders_tab_view.dart';
import 'genres_tab_view.dart';
import 'tracks_tab_view.dart';

enum SortOption { title, artist, duration, dateAdded, fileSize }

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  bool _isLoading = true;
  SortOption _currentSort = SortOption.title;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadInitialLibrary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Loads real user music from local cache or scans device storage directly.
  /// Never generates synthetic/test audios.
  Future<void> _loadInitialLibrary() async {
    final cached = await StorageCacheService.loadCachedSongs();

    if (cached != null && cached.isNotEmpty) {
      final realSongs = cached.where((s) => !s.isSample).toList();
      if (realSongs.isNotEmpty) {
        setState(() {
          _allSongs = realSongs;
          _isLoading = false;
        });
        _applySortAndFilter();
        return;
      }
    }

    // Scan real device storage across CrossDevice, Documents, Downloads, Music, MediaStore, etc.
    await _scanDeviceStorage();
  }

  Future<void> _scanDeviceStorage() async {
    setState(() {
      _isLoading = true;
    });

    final hasPermission = await MusicScannerService.requestStoragePermissions();
    if (hasPermission) {
      final dirs = await MusicScannerService.getDefaultMusicDirectories();
      final result = await MusicScannerService.scanDirectories(dirs);
      setState(() {
        _allSongs = result.songs;
        _isLoading = false;
      });
      _applySortAndFilter();
      return;
    } else {
      if (mounted && (Platform.isAndroid || Platform.isIOS)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Music / Storage permission is required to find your audio files.'),
            action: SnackBarAction(
              label: 'Settings',
              textColor: AppTheme.accentAmber,
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }

    setState(() {
      _allSongs = [];
      _isLoading = false;
    });
    _applySortAndFilter();
  }

  void _onSearchChanged() {
    _applySortAndFilter();
  }

  void _applySortAndFilter() {
    final query = _searchController.text.trim().toLowerCase();
    List<Song> list = List.from(_allSongs);

    if (query.isNotEmpty) {
      list = list.where((song) {
        return song.title.toLowerCase().contains(query) ||
            song.artist.toLowerCase().contains(query) ||
            song.album.toLowerCase().contains(query) ||
            song.folder.toLowerCase().contains(query) ||
            song.genre.toLowerCase().contains(query);
      }).toList();
    }

    switch (_currentSort) {
      case SortOption.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortOption.duration:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
      case SortOption.dateAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SortOption.fileSize:
        list.sort((a, b) => b.fileSize.compareTo(a.fileSize));
        break;
    }

    setState(() {
      _filteredSongs = list;
    });
  }

  void _onShuffleAll() {
    if (_filteredSongs.isEmpty) return;
    final shuffled = List<Song>.from(_filteredSongs)..shuffle();
    AudioPlayerService.instance.playSong(shuffled.first, contextQueue: shuffled);
  }

  Future<void> _addCustomFolderFromUI() async {
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      final existing = await StorageCacheService.loadCustomDirectories();
      if (!existing.contains(selectedDirectory)) {
        await StorageCacheService.saveCustomDirectories([...existing, selectedDirectory]);
      }
      await _scanDeviceStorage();
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.spotifyCardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Sort Tracks By',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.spotifyWhite,
                  ),
                ),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              _buildSortOption(SortOption.title, 'Track Title (A - Z)', Icons.sort_by_alpha_rounded),
              _buildSortOption(SortOption.artist, 'Artist Name', Icons.person_rounded),
              _buildSortOption(SortOption.duration, 'Track Duration', Icons.timer_rounded),
              _buildSortOption(SortOption.dateAdded, 'Date Added (Recent First)', Icons.calendar_today_rounded),
              _buildSortOption(SortOption.fileSize, 'Audio File Size', Icons.data_usage_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(SortOption option, String title, IconData icon) {
    final isSelected = _currentSort == option;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.spotifyGreen : AppTheme.spotifyLightGrey),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.spotifyWhite : AppTheme.spotifyLightGrey,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppTheme.spotifyGreen)
          : null,
      onTap: () {
        setState(() {
          _currentSort = option;
        });
        _applySortAndFilter();
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersCount = _filteredSongs.map((s) => s.folder).toSet().length;
    final artistsCount = _filteredSongs.map((s) => s.artist).toSet().length;
    final albumsCount = _filteredSongs.map((s) => s.album).toSet().length;
    final genresCount = _filteredSongs.map((s) => s.genre).toSet().length;
    final favoritesCount = _filteredSongs.where((s) => s.isFavorite).length;

    final tabs = [
      TabItemData(label: 'Songs', icon: Icons.music_note_rounded, badgeCount: _filteredSongs.length),
      TabItemData(label: 'Folders', icon: Icons.folder_rounded, badgeCount: foldersCount),
      TabItemData(label: 'Artists', icon: Icons.person_rounded, badgeCount: artistsCount),
      TabItemData(label: 'Albums', icon: Icons.album_rounded, badgeCount: albumsCount),
      TabItemData(label: 'Genres', icon: Icons.waves_rounded, badgeCount: genresCount),
      TabItemData(label: 'Favorites', icon: Icons.favorite_rounded, badgeCount: favoritesCount),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Icon Badge with Spotify Green Rim
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.spotifyGreen.withValues(alpha: 0.5), width: 1.2),
                image: const DecorationImage(
                  image: AssetImage('assets/icon/app_icon.png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: AppTheme.softShadow,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'FREAK PLAYER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.spotifyWhite,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Master Volume Quick Control
          const VolumeControllerWidget(
            mode: VolumeDisplayMode.popup,
          ),

          // Rescan Storage
          IconButton(
            iconSize: 20,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.spotifyWhite),
            onPressed: () async {
              await StorageCacheService.clearCache();
              await _scanDeviceStorage();
            },
            tooltip: 'Rescan storage',
          ),

          // Search Toggle
          IconButton(
            iconSize: 20,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: Icon(
              _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
              color: AppTheme.spotifyWhite,
            ),
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                }
              });
            },
            tooltip: 'Search library',
          ),

          // Sort Menu
          IconButton(
            iconSize: 20,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.sort_rounded, color: AppTheme.spotifyWhite),
            onPressed: _showSortDialog,
            tooltip: 'Sort tracks',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isSearchOpen ? 116 : 56),
          child: Column(
            children: [
              // Search Input Field when expanded
              if (_isSearchOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.spotifyWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Filter by song, artist, album, folder...',
                      hintStyle: const TextStyle(color: AppTheme.spotifyLightGrey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.spotifyGreen, size: 20),
                      filled: true,
                      fillColor: AppTheme.spotifyCardElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.spotifyGreen),
                      ),
                    ),
                  ),
                ),

              // TOP TABS (NOT BOTTOM NAVIGATION)
              TopTabBar(
                controller: _tabController,
                tabs: tabs,
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Tab Views Content
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    TracksTabView(
                      songs: _filteredSongs,
                      onSongsChanged: () {
                        setState(() {});
                        StorageCacheService.saveCachedSongs(_allSongs);
                      },
                      onShuffleAll: _onShuffleAll,
                      onScanStorage: _scanDeviceStorage,
                      onAddFolder: _addCustomFolderFromUI,
                    ),
                    FoldersTabView(
                      songs: _filteredSongs,
                      onSongsChanged: () {
                        setState(() {});
                        StorageCacheService.saveCachedSongs(_allSongs);
                      },
                    ),
                    ArtistsTabView(
                      songs: _filteredSongs,
                      onSongsChanged: () {
                        setState(() {});
                        StorageCacheService.saveCachedSongs(_allSongs);
                      },
                    ),
                    AlbumsTabView(
                      songs: _filteredSongs,
                      onSongsChanged: () {
                        setState(() {});
                        StorageCacheService.saveCachedSongs(_allSongs);
                      },
                    ),
                    GenresTabView(
                      songs: _filteredSongs,
                      onSongsChanged: () {
                        setState(() {});
                        StorageCacheService.saveCachedSongs(_allSongs);
                      },
                    ),
                    FavoritesTabView(
                      songs: _filteredSongs,
                      onSongsChanged: () {
                        setState(() {});
                        StorageCacheService.saveCachedSongs(_allSongs);
                      },
                    ),
                  ],
                ),

          // Floating Persistent Mini Player Dock at bottom
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }
}
