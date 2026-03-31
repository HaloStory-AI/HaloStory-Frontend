import 'package:flutter/material.dart';
import 'tabs/chat_tab.dart';
import 'tabs/create_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'app_info_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/localization_service.dart';

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

  final List<Widget> _tabs = [
    const ChatTab(),
    const CreateTab(),
    const StoriesTab(),
    const CalendarTab(),
  ];

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const lightTopBar = Color(0xFF8DC5FF);
    const lightSidebarBg = Color(0xFF4C5B72);
    const lightSidebarSelectedBg = Color(0xFF627089);

    final appBarBg = isDark ? theme.scaffoldBackgroundColor : lightTopBar;
    final sidebarBg = isDark ? colorScheme.surface : lightSidebarBg;
    final sidebarSelectedBg = isDark
        ? colorScheme.surfaceContainerHighest
        : lightSidebarSelectedBg;
    final sidebarIconColor = isDark
        ? colorScheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.7);
    final sidebarIconSelectedColor = isDark
        ? colorScheme.onSurface
        : Colors.white;
    final sidebarSplashColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.2);
    final sidebarHighlightColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.15);

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
                  color: isDark ? theme.scaffoldBackgroundColor : lightTopBar,
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
                InkWell(
                  onTap: () =>
                      launchUrl(Uri.parse('https://s.my-bini.my.id/discord')),
                  splashColor: sidebarSplashColor,
                  highlightColor: sidebarHighlightColor,
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.help_outline,
                      color: sidebarIconColor,
                      size: 24,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showAppInfoDialog();
                  },
                  splashColor: sidebarSplashColor,
                  highlightColor: sidebarHighlightColor,
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.info_outline,
                      color: sidebarIconColor,
                      size: 24,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showSettingsDialog();
                  },
                  splashColor: sidebarSplashColor,
                  highlightColor: sidebarHighlightColor,
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.settings_outlined,
                      color: sidebarIconColor,
                      size: 24,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 40,
                    child: Divider(
                      color: isDark
                          ? colorScheme.outline
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showLogoutDialog();
                  },
                  splashColor: Colors.redAccent.withValues(alpha: 0.2),
                  highlightColor: Colors.redAccent.withValues(alpha: 0.15),
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.logout,
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      size: 24,
                    ),
                  ),
                ),
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
