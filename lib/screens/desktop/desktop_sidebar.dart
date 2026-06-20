import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';

class DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
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

    return Container(
      width: 80,
      color: railBg,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildSvgNavItem(
            iconAsset: 'assets/icon/sidebar_chat.svg',
            label: tr('tab_chat'),
            isSelected: currentIndex == 0,
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
            isSelected: currentIndex == 1,
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
            isSelected: currentIndex == 2,
            selectedBg: selectedBg,
            iconSelected: iconSelected,
            iconUnselected: iconUnselected,
            labelSelected: labelSelected,
            labelUnselected: labelUnselected,
            onTap: () => onTabSelected(2),
          ),

          const SizedBox(height: 16),
          _buildIconNavItem(
            icon: Icons.grid_view_rounded,
            label: tr('tab_more'),
            isSelected: currentIndex == 3,
            selectedBg: selectedBg,
            iconSelected: iconSelected,
            iconUnselected: iconUnselected,
            labelSelected: labelSelected,
            labelUnselected: labelUnselected,
            onTap: () => onTabSelected(3),
          ),

          const Spacer(),
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
