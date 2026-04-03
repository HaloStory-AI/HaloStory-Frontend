import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'admin_screen.dart';
import 'student_request_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'app_info_screen.dart';
import 'desktop_home_screen.dart';
import 'tabs/chat_tab.dart';
import 'tabs/create_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _checkDonation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkDonation() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDonationPopup();
    });
  }

  void _showDonationPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final bodyTextColor = theme.textTheme.bodyMedium?.color?.withValues(
          alpha: 0.85,
        );

        return Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/image/notice_image.png',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('donation_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('donation_content'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: bodyTextColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    launchUrl(Uri.parse('https://trakteer.id/r8kstudio')),
                icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                label: Text(tr('donation_button')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(
                  tr('donation_later'),
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.75,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  List<Widget> get _tabs => [
        ChatTab(onChatSelected: _onChatSelected),
        const CreateTab(),
        const StoriesTab(),
        const CalendarTab(),
      ];

  void _onChatSelected(Map<String, dynamic> bot) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((p) {
      final provider = AIService.normalizeProvider(p.getString('default_provider'));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(bot: bot, provider: provider),
        ),
      ).then((_) {
        // Trigger a refresh if needed
      });
    });
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AlertDialog(
            title: Text(
              tr('disclaimer_title'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            content: SingleChildScrollView(child: Text(tr('disclaimer_content'))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('disclaimer_understand')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppInfoDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppInfoScreen()),
    );
  }

  void _showSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Navigator.maybePop(context);
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= 800) {
      return const DesktopHomeScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appBarBg =
        isDark ? theme.scaffoldBackgroundColor : AppTheme.momoLightTopBar;
    final sidebarBg =
        isDark ? colorScheme.surface : AppTheme.momoRailBackground;
    final sidebarSelectedBg = isDark
        ? colorScheme.surfaceContainerHighest
        : AppTheme.momoRailSelected;
    final sidebarIconColor = isDark
        ? colorScheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.7);
    final sidebarIconSelectedColor = isDark
        ? colorScheme.onSurface
        : Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: SvgPicture.asset(
                'assets/icon/momo_logo.svg',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'BlueTalk',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _showDisclaimer,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: isDark
                      ? const []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 0,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Icon(
                  Icons.question_mark_rounded,
                  color: isDark ? theme.scaffoldBackgroundColor : AppTheme.momoLightTopBar,
                  size: 16,
                  weight: 900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                backgroundImage: const AssetImage('assets/icon/avatar.png'),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 55,
            color: sidebarBg,
            child: Column(
              children: [
                _buildSidebarNavItem(
                  iconAsset: 'assets/icon/sidebar_chat.svg',
                  iconSize: 20,
                  index: 0,
                  isSelected: _currentIndex == 0,
                  selectedBackgroundColor: sidebarSelectedBg,
                  selectedColor: sidebarIconSelectedColor,
                  unselectedColor: sidebarIconColor,
                ),
                _buildSidebarNavItem(
                  iconAsset: 'assets/icon/sidebar_groups.svg',
                  index: 1,
                  isSelected: _currentIndex == 1,
                  selectedBackgroundColor: sidebarSelectedBg,
                  selectedColor: sidebarIconSelectedColor,
                  unselectedColor: sidebarIconColor,
                ),
                _buildSidebarNavItem(
                  iconAsset: 'assets/icon/sidebar_stories.svg',
                  index: 2,
                  isSelected: _currentIndex == 2,
                  selectedBackgroundColor: sidebarSelectedBg,
                  selectedColor: sidebarIconSelectedColor,
                  unselectedColor: sidebarIconColor,
                ),
                _buildSidebarNavItem(
                  iconAsset: 'assets/icon/sidebar_calendar.svg',
                  index: 3,
                  isSelected: _currentIndex == 3,
                  selectedBackgroundColor: sidebarSelectedBg,
                  selectedColor: sidebarIconSelectedColor,
                  unselectedColor: sidebarIconColor,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz_rounded, color: sidebarIconColor, size: 28),
                  offset: const Offset(50, -120),
                  color: isDark ? colorScheme.surfaceContainer : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'admin':
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
                        break;
                      case 'suggest':
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentRequestScreen()));
                        break;
                      case 'donation':
                        launchUrl(Uri.parse('https://trakteer.id/rafiq8k'));
                        break;
                      case 'contributor':
                        launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
                        break;
                      case 'help':
                        launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
                        break;
                      case 'info':
                        _showAppInfoDialog();
                        break;
                    }
                  },
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
                          Icon(Icons.add_task_rounded, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(tr('sidebar_suggest_student'), style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'donation',
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(tr('sidebar_donation'), style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'contributor',
                      child: Row(
                        children: [
                          Icon(Icons.people_outline_rounded, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(tr('sidebar_contributor'), style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'help',
                      child: Row(
                        children: [
                          Icon(Icons.help_outline, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(tr('sidebar_help'), style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(tr('sidebar_info'), style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _showSettingsDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_outlined, color: sidebarIconColor, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        tr('sidebar_settings'),
                        style: TextStyle(
                          color: sidebarIconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _showLogoutDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent.withOpacity(0.8), size: 24),
                      const SizedBox(height: 4),
                      Text(
                        tr('sidebar_logout'),
                        style: TextStyle(
                          color: Colors.redAccent.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (index == _currentIndex) return;
                setState(() => _currentIndex = index);
              },
              children: _tabs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required String iconAsset,
    double iconSize = 24,
    required int index,
    required bool isSelected,
    required Color selectedBackgroundColor,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final itemColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        height: 60,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedBackgroundColor : Colors.transparent,
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          scale: isSelected ? 1.03 : 1.0,
          child: SvgPicture.asset(
            iconAsset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(itemColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
