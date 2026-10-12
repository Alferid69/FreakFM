import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../services/library_service.dart';
import '../services/music_scanner_service.dart';
import '../services/storage_cache_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/detail_back_handler.dart';
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
  static const _tabNames = ['songs', 'folders', 'artists', 'albums', 'genres', 'favorites'];

  final LibraryService _library = LibraryService.instance;
  late TabController _tabController;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<String>? _errorSub;
  Timer? _searchDebounce;

  List<Song> _filteredSongs = [];
  String _activeQuery = '';
  bool _isLoading = true;
  SortOption _currentSort = SortOption.title;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this)
      // Rebuild so the Back-button behaviour tracks the current tab.
      ..addListener(() {
        if (!_tabController.indexIsChanging && mounted) setState(() {});
      });
    _searchController.addListener(_onSearchChanged);
    _library.songs.addListener(_applySortAndFilter);
    _library.revision.addListener(_onLibraryRevision);
    DetailBackHandler.open.addListener(_onLibraryRevision);
    _errorSub = AudioPlayerService.instance.errors.listen(_showPlaybackError);
    // Persist pending favourite/play-count changes before the OS can kill us.
    _lifecycle = AppLifecycleListener(onPause: _library.flush, onDetach: _library.flush, onHide: _library.flush);
    _loadInitialLibrary();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _errorSub?.cancel();
    _searchDebounce?.cancel();
    _library.songs.removeListener(_applySortAndFilter);
    _library.revision.removeListener(_onLibraryRevision);
    DetailBackHandler.open.removeListener(_onLibraryRevision);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialLibrary() async {
    final hasCache = await _library.loadFromCache();
    if (!mounted) return;
    if (hasCache) {
      setState(() => _isLoading = false);
      _applySortAndFilter();
      // Libraries built by older scanning rules refresh once, in the
      // background, keeping likes and play counts.
      if (await _library.isScanOutdated() && mounted) await _scanDeviceStorage();
      return;
    }
    await _scanDeviceStorage();
  }

  Future<void> _scanDeviceStorage() async {
    if (_library.songs.value.isEmpty) setState(() => _isLoading = true);

    final outcome = await _library.rescan();
    if (!mounted) return;
    setState(() => _isLoading = false);
    _applySortAndFilter();

    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case ScanOutcome.permissionDenied:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Music permission is required to find your audio files.'),
            action: SnackBarAction(
              label: 'Settings',
              textColor: AppTheme.accentAmber,
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      case ScanOutcome.failed:
        messenger.showSnackBar(const SnackBar(content: Text('Scanning failed. Your existing library was kept.')));
      case ScanOutcome.success:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Library updated • ${plural(_library.songs.value.length, 'song')}'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  void _showPlaybackError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  void _onLibraryRevision() {
    // Favourite/play-count changes only need a repaint, not a re-sort.
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), _applySortAndFilter);
  }

  void _applySortAndFilter() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    List<Song> list = List.of(_library.songs.value);

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
      case SortOption.artist:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
      case SortOption.duration:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
      case SortOption.dateAdded:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case SortOption.fileSize:
        list.sort((a, b) => b.fileSize.compareTo(a.fileSize));
    }

    setState(() {
      _filteredSongs = list;
      _activeQuery = query;
    });
  }

  void _onShuffleAll() {
    if (_filteredSongs.isEmpty) return;
    final player = AudioPlayerService.instance;
    player.setShuffle(true);
    final start = _filteredSongs[Random().nextInt(_filteredSongs.length)];
    player.playSong(start, contextQueue: _filteredSongs, source: 'All songs');
  }

  Future<void> _addCustomFolderFromUI() async {
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      await _library.addFolder(selectedDirectory);
      await _scanDeviceStorage();
    }
  }

  Future<void> _showLibraryFolders() async {
    final defaults = await MusicScannerService.defaultLibraryRoots();
    final custom = await StorageCacheService.loadCustomDirectories();
    final hidden = await StorageCacheService.loadExcludedDirectories();
    if (!mounted) return;

    var changed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.spotifyCardElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget header(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.spotifyLightGrey,
                ),
              ),
            );

            Widget folderTile(String path, {Widget? trailing}) => ListTile(
              dense: true,
              leading: const Icon(Icons.folder_rounded, color: AppTheme.accentAmber),
              title: Text(path, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
              trailing: trailing,
            );

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    const Text(
                      'Library folders',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.spotifyWhite),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'All music on your device is found automatically, plus anything in these folders. '
                      "Hide a folder (Folders tab or a song's ⋮ menu) to keep it out of your library.",
                      style: TextStyle(fontSize: 12.5, color: AppTheme.spotifyLightGrey),
                    ),
                    header('DEFAULT'),
                    if (defaults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('None found', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ),
                    for (final d in defaults) folderTile(d),
                    header('ADDED BY YOU'),
                    for (final d in custom)
                      folderTile(
                        d,
                        trailing: IconButton(
                          tooltip: 'Remove folder',
                          icon: const Icon(Icons.close_rounded, color: AppTheme.spotifyLightGrey),
                          onPressed: () async {
                            await _library.removeFolder(d);
                            changed = true;
                            setSheetState(() => custom.remove(d));
                          },
                        ),
                      ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.create_new_folder_outlined, color: AppTheme.spotifyGreen),
                      title: const Text('Add folder', style: TextStyle(color: AppTheme.spotifyGreen)),
                      onTap: () {
                        Navigator.pop(context);
                        _addCustomFolderFromUI();
                      },
                    ),
                    if (hidden.isNotEmpty) ...[
                      header('HIDDEN'),
                      for (final d in hidden)
                        folderTile(
                          d,
                          trailing: TextButton(
                            onPressed: () async {
                              await _library.unhideFolder(d);
                              changed = true;
                              setSheetState(() => hidden.remove(d));
                            },
                            child: const Text('Unhide'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (changed && mounted) await _scanDeviceStorage();
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.spotifyCardElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.spotifyWhite),
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
      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppTheme.spotifyGreen) : null,
      onTap: () {
        _currentSort = option;
        _applySortAndFilter();
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final foldersCount = _filteredSongs.map((s) => s.folderPath).toSet().length;
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

    final currentTab = _tabNames[_tabController.index];
    final canPop = !_isSearchOpen &&
        _tabController.index == 0 &&
        !DetailBackHandler.open.value.containsKey(currentTab);
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back closes an open album/artist/genre/folder first, then search,
        // then returns to the Songs tab before leaving the app.
        if (DetailBackHandler.closeIn(currentTab)) return;
        if (_isSearchOpen) {
          setState(() {
            _isSearchOpen = false;
            _searchController.clear();
          });
        } else if (_tabController.index != 0) {
          _tabController.animateTo(0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 12,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.spotifyGreen.withValues(alpha: 0.5), width: 1.2),
                  image: const DecorationImage(image: AssetImage('assets/icon/app_icon.png'), fit: BoxFit.cover),
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
            if (isDesktopPlatform) const VolumeControllerWidget(mode: VolumeDisplayMode.popup),
            ValueListenableBuilder<bool>(
              valueListenable: _library.isScanning,
              builder: (context, scanning, _) => scanning
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.spotifyGreen),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            IconButton(
              key: const ValueKey('search_button'),
              iconSize: 20,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              icon: Icon(_isSearchOpen ? Icons.close_rounded : Icons.search_rounded, color: AppTheme.spotifyWhite),
              onPressed: () {
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) _searchController.clear();
                });
              },
              tooltip: 'Search library',
            ),
            PopupMenuButton<String>(
              key: const ValueKey('library_menu'),
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.spotifyWhite, size: 20),
              color: AppTheme.spotifyCardElevated,
              onSelected: (value) {
                switch (value) {
                  case 'sort':
                    _showSortDialog();
                  case 'rescan':
                    _scanDeviceStorage();
                  case 'folders':
                    _showLibraryFolders();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'sort',
                  child: ListTile(leading: Icon(Icons.sort_rounded), title: Text('Sort songs'), dense: true),
                ),
                PopupMenuItem(
                  value: 'rescan',
                  child: ListTile(leading: Icon(Icons.refresh_rounded), title: Text('Rescan library'), dense: true),
                ),
                PopupMenuItem(
                  value: 'folders',
                  child: ListTile(
                    leading: Icon(Icons.folder_open_rounded),
                    title: Text('Library folders'),
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_isSearchOpen ? 116 : 56),
            child: Column(
              children: [
                if (_isSearchOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TextField(
                      key: const ValueKey('search_field'),
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
                TopTabBar(controller: _tabController, tabs: tabs),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber)),
                  )
                : TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      TracksTabView(
                        songs: _filteredSongs,
                        searchQuery: _activeQuery,
                        onShuffleAll: _onShuffleAll,
                        onScanStorage: _scanDeviceStorage,
                        onAddFolder: Platform.isAndroid || Platform.isWindows || Platform.isLinux || Platform.isMacOS
                            ? _addCustomFolderFromUI
                            : null,
                      ),
                      FoldersTabView(songs: _filteredSongs),
                      ArtistsTabView(songs: _filteredSongs),
                      AlbumsTabView(songs: _filteredSongs),
                      GenresTabView(songs: _filteredSongs),
                      FavoritesTabView(songs: _filteredSongs),
                    ],
                  ),
            const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
          ],
        ),
      ),
    );
  }
}
