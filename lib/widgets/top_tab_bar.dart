import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Horizontally scrolling pill tabs. The selected pill is always scrolled
/// into view (also when the page is changed by swiping), and the edges fade
/// to hint that more tabs are off-screen.
class TopTabBar extends StatefulWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<TabItemData> tabs;

  const TopTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  State<TopTabBar> createState() => _TopTabBarState();
}

class _TopTabBarState extends State<TopTabBar> {
  final ScrollController _scroll = ScrollController();
  late List<GlobalKey> _keys;
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.tabs.length, (_) => GlobalKey());
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant TopTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
    }
    if (_keys.length != widget.tabs.length) {
      _keys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final index = widget.controller.index;
    if (index == _lastIndex) return;
    _lastIndex = index;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[index].currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.controller.index;

    return Container(
      height: 50,
      color: AppTheme.spotifyDeepBlack,
      child: ShaderMask(
        // Fade the right edge so partially hidden pills read as "scroll for more".
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.9, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 6, 32, 6),
          child: Row(
            children: [
              for (var index = 0; index < widget.tabs.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                _buildPill(index, widget.tabs[index], index == selectedIndex),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(int index, TabItemData tab, bool isSelected) {
    final fg = isSelected ? Colors.black : AppTheme.textPrimary;
    return Semantics(
      key: _keys[index],
      selected: isSelected,
      button: true,
      label: tab.badgeCount != null ? '${tab.label}, ${tab.badgeCount}' : tab.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? AppTheme.spotifyGreen : AppTheme.spotifyCardHighlight,
        shape: const StadiumBorder(),
        child: InkWell(
          key: ValueKey('tab_${tab.label}'),
          customBorder: const StadiumBorder(),
          onTap: () => widget.controller.animateTo(index),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Text(
                  tab.label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg, letterSpacing: -0.2),
                ),
                if (tab.badgeCount != null && tab.badgeCount! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0x33000000) : const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tab.badgeCount}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.black : AppTheme.spotifyLightGrey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TabItemData {
  final String label;
  final IconData icon;
  final int? badgeCount;

  const TabItemData({
    required this.label,
    required this.icon,
    this.badgeCount,
  });
}
