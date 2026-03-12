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
import '../services/story_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/localization_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final StoryService _storyService = StoryService();
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkDonation();
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF135ACF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('donation_content'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A5568),
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
                backgroundColor: const Color(0xFFF0F5FF),
                foregroundColor: const Color(0xFF135ACF),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('donation_later'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF135ACF),
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
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                }
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
          style: const TextStyle(fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8D8F8),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/icon.jpg',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BlueTalk',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _showDisclaimer,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.question_mark_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      // --- THE SIDEBAR (DRAWER) ---
      drawer: Drawer(
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
                decoration: const BoxDecoration(
                  color: Color(0xFFB8D8F8),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
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
                launchUrl(Uri.parse('https://trakteer.id/r8kstudio'));
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
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF135ACF),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_rounded),
              label: tr('tab_chat'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_rounded),
              label: tr('tab_create'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_stories_rounded),
              label: tr('tab_stories'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_rounded),
              label: tr('tab_calendar'),
            ),
          ],
        ),
      ),
    );
  }
}
