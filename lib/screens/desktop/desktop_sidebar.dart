import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';

class DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final bool isSettingsSelected;
  final Function(int) onTabSelected;
  final VoidCallback onSettingsPressed;
  final VoidCallback onLogoutPressed;
  final Function(String) onMoreOptionSelected;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.isSettingsSelected,
    required this.onTabSelected,
    required this.onSettingsPressed,
    required this.onLogoutPressed,
    required this.onMoreOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final railBg = isDark ? cs.surface : AppTheme.momoRailBackground;
    final selectedBg = isDark
        ? cs.surfaceContainerHighest
        : AppTheme.momoRailSelected;
    final iconSelected = isDark ? cs.onSurface : Colors.white;
    final iconUnselected = isDark
        ? cs.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.7);
    final labelSelected = iconSelected;
    final labelUnselected = iconUnselected;
    final menuIconColor = isDark
        ? cs.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      width: 80,
      color: railBg,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildSvgNavItem(
            iconAsset: 'assets/icon/sidebar_chat.svg',
            label: tr('tab_chat'),
            isSelected: currentIndex == 0 && !isSettingsSelected,
            selectedBg: selectedBg,
            iconSelected: iconSelected,
            iconUnselected: iconUnselected,
            labelSelected: labelSelected,
            labelUnselected: labelUnselected,
            onTap: () => onTabSelected(0),
          ),

          const SizedBox(height: 16),
          _buildSvgNavItem(
            iconAsset: 'assets/icon/sidebar_stories.svg',
            label: tr('tab_stories'),
            isSelected: currentIndex == 1 && !isSettingsSelected,
            selectedBg: selectedBg,
            iconSelected: iconSelected,
            iconUnselected: iconUnselected,
            labelSelected: labelSelected,
            labelUnselected: labelUnselected,
            onTap: () => onTabSelected(1),
          ),

          const SizedBox(height: 16),
          _buildSvgNavItem(
            iconAsset: 'assets/icon/sidebar_calendar.svg',
            label: tr('tab_calendar'),
            isSelected: currentIndex == 2 && !isSettingsSelected,
            selectedBg: selectedBg,
            iconSelected: iconSelected,
            iconUnselected: iconUnselected,
            labelSelected: labelSelected,
            labelUnselected: labelUnselected,
            onTap: () => onTabSelected(1),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: menuIconColor,
              size: 28,
            ),
            offset: const Offset(60, -120),
            color: cs.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            onSelected: onMoreOptionSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'suggest',
                child: Row(
                  children: [
                    Icon(Icons.add_task_rounded, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('sidebar_suggest_student'),
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'donation',
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.pinkAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('sidebar_donation'),
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'contributor',
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('sidebar_contributor'),
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('sidebar_help'),
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('sidebar_info'),
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildIconNavItem(
            icon: Icons.settings_outlined,
            label: tr('sidebar_settings'),
            isSelected: isSettingsSelected,
            selectedBg: selectedBg,
            iconSelected: iconSelected,
            iconUnselected: iconUnselected,
            labelSelected: labelSelected,
            labelUnselected: labelUnselected,
            onTap: onSettingsPressed,
          ),
          const SizedBox(height: 16),
          _buildIconNavItem(
            icon: Icons.logout,
            label: tr('sidebar_logout'),
            isSelected: false,
            selectedBg: selectedBg,
            iconSelected: Colors.redAccent,
            iconUnselected: Colors.redAccent.withValues(alpha: 0.8),
            labelSelected: Colors.redAccent,
            labelUnselected: Colors.redAccent.withValues(alpha: 0.8),
            onTap: onLogoutPressed,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSvgNavItem({
    required String iconAsset,
    required String label,
    required bool isSelected,
    required Color selectedBg,
    required Color iconSelected,
    required Color iconUnselected,
    required Color labelSelected,
    required Color labelUnselected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? iconSelected : iconUnselected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? labelSelected : labelUnselected,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color selectedBg,
    required Color iconSelected,
    required Color iconUnselected,
    required Color labelSelected,
    required Color labelUnselected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? iconSelected : iconUnselected,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? labelSelected : labelUnselected,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
