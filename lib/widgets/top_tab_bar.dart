import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TopTabBar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.spotifyDeepBlack,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tabs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final isSelected = controller.index == index;

              return InkWell(
                onTap: () => controller.animateTo(index),
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.spotifyGreen
                        : AppTheme.spotifyCardHighlight,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSelected ? AppTheme.softShadow : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 15,
                        color: isSelected
                            ? const Color(0xFF000000)
                            : AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF000000)
                              : AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (tab.badgeCount != null && tab.badgeCount! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0x33000000)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${tab.badgeCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? const Color(0xFF000000)
                                  : AppTheme.spotifyLightGrey,
                            ),
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
