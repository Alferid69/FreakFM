import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_player_service.dart';
import '../services/collections.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/mini_player.dart';
import 'collection_page.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';
import 'settings_page.dart';

/// App frame, Spotify style: Home / Search / Your Library tabs (each with its
/// own navigation stack), a floating mini player above a fading bottom bar.
/// Also owns library loading, rescans and playback error messages.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  /// Lets the full-screen player open album/artist pages in the current tab.
  static final GlobalKey<RootShellState> globalKey = GlobalKey<RootShellState>();

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  final LibraryService _library = LibraryService.instance;
  final List<GlobalKey<NavigatorState>> _navigators = List.generate(3, (_) => GlobalKey<NavigatorState>());
  late final List<_StackObserver> _observers = List.generate(3, (_) => _StackObserver(_onStackChanged));
  final FocusNode _searchFocus = FocusNode();
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<String>? _errorSub;
  int _tab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _errorSub = AudioPlayerService.instance.errors.listen(_toast);
    // Persist pending like/play-count changes before the OS can kill us.
    _lifecycle = AppLifecycleListener(onPause: _library.flush, onDetach: _library.flush, onHide: _library.flush);
    _loadLibrary();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _errorSub?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final hasCache = await _library.loadFromCache();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!hasCache) {
      await rescan();
    } else if (await _library.isScanOutdated() && mounted) {
      // Libraries built by older scanning rules refresh once in the background.
      await rescan();
    }
  }

  Future<void> rescan() async {
    final outcome = await _library.rescan();
    if (!mounted) return;
    switch (outcome) {
      case ScanOutcome.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Allow access to music to find your songs.'),
            action: SnackBarAction(label: 'Settings', onPressed: () => openAppSettings()),
            duration: const Duration(seconds: 6),
          ),
        );
      case ScanOutcome.failed:
        _toast('Scanning failed. Your library was kept as it was.');
      case ScanOutcome.success:
        _toast('Library updated • ${plural(_library.songs.value.length, 'song')}');
    }
  }

  Future<void> addFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null || dir.isEmpty) return;
    await _library.addFolder(dir);
    await rescan();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  NavigatorState? get _currentNavigator => _navigators[_tab].currentState;

  /// Opens [ref] in the visible tab (used by the full-screen player).
  void openCollection(CollectionRef ref) {
    _currentNavigator?.push(MaterialPageRoute<void>(builder: (_) => CollectionPage(collectionRef: ref)));
  }

  void openSettings() {
    _currentNavigator?.push(
      MaterialPageRoute<void>(builder: (_) => SettingsPage(onAddFolder: addFolder, onRescan: rescan)),
    );
  }

  void selectTab(int index) {
    if (index == _tab) {
      // Re-tapping a tab returns to its first page, like Spotify.
      _currentNavigator?.popUntil((r) => r.isFirst);
      if (index == 1) _searchFocus.requestFocus();
      return;
    }
    setState(() => _tab = index);
  }

  void _onStackChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _rootPage(int index) => switch (index) {
        0 => HomeTab(onOpenSettings: openSettings),
        1 => SearchTab(focusNode: _searchFocus),
        _ => LibraryTab(
            onOpenSearch: () => selectTab(1),
            onOpenSettings: openSettings,
            onAddFolder: addFolder,
            onRescan: rescan,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final nestedCanPop = _navigators[_tab].currentState?.canPop() ?? false;

    return PopScope(
      // Back: pop inside the tab first, then return to Home, then leave.
      canPop: _tab == 0 && !nestedCanPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _currentNavigator;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              IndexedStack(
                index: _tab,
                children: [
                  for (var i = 0; i < 3; i++)
                    HeroControllerScope.none(
                      child: Navigator(
                        key: _navigators[i],
                        observers: [_observers[i]],
                        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _rootPage(i)),
                      ),
                    ),
                ],
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  _BottomNav(index: _tab, onSelect: selectTab),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackObserver extends NavigatorObserver {
  final VoidCallback onChange;
  _StackObserver(this.onChange);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => onChange();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => onChange();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => onChange();
}

/// Spotify's bottom bar: icons + small labels over a fade to black.
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _BottomNav({required this.index, required this.onSelect});

  static const _items = [
    ('Home', Icons.home_outlined, Icons.home_filled, 'nav_home'),
    ('Search', Icons.search_rounded, Icons.manage_search_rounded, 'nav_search'),
    ('Your Library', Icons.library_music_outlined, Icons.library_music_rounded, 'nav_library'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(top: 14, bottom: bottom + 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xE6000000), Color(0xFF000000)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkResponse(
                key: ValueKey(_items[i].$4),
                onTap: () => onSelect(i),
                radius: 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      i == index ? _items[i].$3 : _items[i].$2,
                      size: 27,
                      color: i == index ? Colors.white : AppTheme.spotifyLightGrey,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _items[i].$1,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                        color: i == index ? Colors.white : AppTheme.spotifyLightGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
