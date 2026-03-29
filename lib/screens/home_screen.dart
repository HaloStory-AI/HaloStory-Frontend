import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'admin_screen.dart';
import 'app_info_screen.dart';
import 'tabs/chat_tab.dart';
import 'tabs/create_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'student_request_screen.dart';
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
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadProfile();
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
        final isDark = theme.brightness == Brightness.dark;
        final bodyTextColor = theme.textTheme.bodyMedium?.color?.withValues(
          alpha: 0.85,
        );

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
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
                  backgroundColor: isDark
                      ? colorScheme.surfaceContainerHighest
                      : const Color(0xFFF0F5FF),
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

  Future<void> _loadProfile() async {
    final profile = await _authService.getUserProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  final List<Widget> _tabs = [
    const ChatTab(), // Index 0
    const CreateTab(), // Index 1
    const StoriesTab(), // Index 2
    const CalendarTab(), // Index 3
  ];

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tr('logout_confirm_title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          content: Text(tr('logout_confirm_content')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('logout_no'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(this.context);
                await _authService.logout();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(100, 40),
              ),
              child: Text(tr('logout_yes')),
            ),
          ],
        );
      },
    );
  }

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

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildFancyNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final bool selected = _currentIndex == index;
    final itemColor = selected ? selectedColor : unselectedColor;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                scale: selected ? 1.05 : 1,
                child: Icon(icon, size: 22, color: itemColor),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: itemColor,
                  fontSize: selected ? 11.8 : 11.4,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const blueTone = Color(0xFF8DC5FF);
    final navUnselectedColor = isDark
        ? const Color(0xFF4C5A6F)
        : const Color(0xFF4C5A6F);

    return Scaffold(
      backgroundColor: isDark
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF3F7F8),
      appBar: AppBar(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : blueTone,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Drawer icon white
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icon/momo_logo.svg',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              'BlueTalk',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _showDisclaimer,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
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
                  color: isDark
                      ? const Color(0xFFD5E4F7)
                      : const Color(0xFF5D7392),
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      // --- THE SIDEBAR (DRAWER) ---
      drawer: Drawer(
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest
                      : blueTone,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: isDark
                      ? theme.scaffoldBackgroundColor
                      : Colors.white,
                  child: Text(
                    (_userProfile?['name'] != null &&
                            _userProfile!['name'].isNotEmpty)
                        ? _userProfile!['name'][0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF135ACF),
                    ),
                  ),
                ),
                accountName: Text(
                  _userProfile?['name'] ?? 'Sensei',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                accountEmail: Text(
                  _userProfile?['email'] ?? 'sensei@kivotos.jp',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
            if (_userProfile?['role'] == 'admin')
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.amber,
                ),
                title: Text(
                  tr('sidebar_admin_panel'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminScreen(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.add_task_rounded,
                color: Color(0xFF135ACF),
              ),
              title: Text(tr('sidebar_suggest_student')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentRequestScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.favorite_rounded,
                color: Colors.pinkAccent,
              ),
              title: Text(tr('sidebar_donation')),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://trakteer.id/r8kstudio'));
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.people_outline_rounded,
                color: Color(0xFF135ACF),
              ),
              title: Text(tr('sidebar_contributor')),
              onTap: () {
                Navigator.pop(context);
                launchUrl(
                  Uri.parse(
                    'https://www.blog-rafiq8k.zone.id/2026/03/mencari-kontributor-r8kstudio.html',
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF135ACF),
              ),
              title: Text(tr('sidebar_settings')),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFF135ACF)),
              title: Text(tr('sidebar_help')),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF135ACF)),
              title: Text(tr('sidebar_info')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppInfoScreen(),
                  ),
                );
              },
            ),
            const Spacer(), // Pushes logout to bottom
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                tr('sidebar_logout'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                _showLogoutDialog(); // Then show confirm
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (index == _currentIndex) return;
          setState(() => _currentIndex = index);
        },
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Row(
              children: [
                _buildFancyNavItem(
                  index: 0,
                  icon: Icons.chat_bubble_rounded,
                  label: tr('tab_chat'),
                  selectedColor: blueTone,
                  unselectedColor: navUnselectedColor,
                ),
                _buildFancyNavItem(
                  index: 1,
                  icon: Icons.groups_rounded,
                  label: tr('tab_group_chat'),
                  selectedColor: blueTone,
                  unselectedColor: navUnselectedColor,
                ),
                _buildFancyNavItem(
                  index: 2,
                  icon: Icons.auto_stories_rounded,
                  label: tr('tab_stories'),
                  selectedColor: blueTone,
                  unselectedColor: navUnselectedColor,
                ),
                _buildFancyNavItem(
                  index: 3,
                  icon: Icons.calendar_month_rounded,
                  label: tr('tab_calendar'),
                  selectedColor: blueTone,
                  unselectedColor: navUnselectedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
