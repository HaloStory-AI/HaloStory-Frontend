import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

class DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final bool isSettingsSelected;
  final Function(int) onTabSelected;
  final VoidCallback onSettingsPressed;
  final Function(String) onMoreOptionSelected;
  final Widget? profileAvatar;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.isSettingsSelected,
    required this.onTabSelected,
    required this.onSettingsPressed,
    required this.onMoreOptionSelected,
    this.profileAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 24),
          // User Profile
          if (profileAvatar != null) profileAvatar!,
          const SizedBox(height: 32),

          // Main Tabs
          _buildNavItem(
            icon: Icons.chat_bubble_rounded,
            label: tr('tab_chat'),
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            icon: Icons.groups_rounded,
            label: tr('tab_group_chat'),
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            icon: Icons.auto_stories_rounded,
            label: tr('tab_stories'),
            isSelected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
          const SizedBox(height: 16),
          _buildNavItem(
            icon: Icons.calendar_month_rounded,
            label: tr('tab_calendar'),
            isSelected: currentIndex == 3,
            onTap: () => onTabSelected(3),
          ),

          const Spacer(),

          // More Options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey, size: 28),
            offset: const Offset(60, -120),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: onMoreOptionSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('sidebar_admin_panel'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'suggest',
                child: Row(
                  children: [
                    const Icon(Icons.add_task_rounded, color: Color(0xFF135ACF), size: 20),
                    const SizedBox(width: 8),
                    Text(tr('sidebar_suggest_student')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'donation',
                child: Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('sidebar_donation')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'contributor',
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, color: Color(0xFF135ACF), size: 20),
                    const SizedBox(width: 8),
                    Text(tr('sidebar_contributor')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    const Icon(Icons.help_outline, color: Color(0xFF135ACF), size: 20),
                    const SizedBox(width: 8),
                    Text(tr('sidebar_help')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF135ACF), size: 20),
                    const SizedBox(width: 8),
                    Text(tr('sidebar_info')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Settings
          _buildNavItem(
            icon: Icons.settings_rounded,
            label: tr('sidebar_settings'),
            isSelected: isSettingsSelected,
            onTap: onSettingsPressed,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F5FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF135ACF) : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF135ACF) : Colors.grey,
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
