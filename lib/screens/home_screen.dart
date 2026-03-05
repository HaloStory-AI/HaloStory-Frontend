import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'admin_screen.dart';
import 'tabs/chat_tab.dart';
import 'tabs/create_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'student_request_screen.dart';
import '../services/story_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool _hasShownDonationPopup = false;
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  final StoryService _storyService = StoryService();
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    
    // Show donation popup on first entry
    if (!_hasShownDonationPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDonationPopup();
        _hasShownDonationPopup = true;
      });
    }
  }

  void _showDonationPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Halo Sensei!',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "BlueTalk tidak akan ada tanpa dukungan kalian. Makasih ya... \n\n"
              "Btw kalau kalian ingin donasi agar BlueTalk bisa berkembang, boleh kok, tuh klik aja tombol itu!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://trakteer.id/r8kstudio')),
              icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
              label: const Text('Donasi di Trakteer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0F5FF),
                foregroundColor: const Color(0xFF135ACF),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Deh', style: TextStyle(color: Colors.grey)),
          ),
        ],
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
    const ChatTab(),       // Index 0
    const CreateTab(),     // Index 1
    const StoriesTab(),    // Index 2
    const CalendarTab(),   // Index 3
  ];

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Confirm Logout',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
          ),
          content: const Text('Are you sure you want to sign out from BlueTalk?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No, Stay', style: TextStyle(color: Colors.grey)),
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
              child: const Text('Yes, Logout'),
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
        title: const Text('Disclaimer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'BlueTalk is not affiliated, associated, authorized, endorsed by, or in any way officially connected with Blue Archive, Nexon Games, or any of their subsidiaries or affiliates.\n\n'
            'All names, characters, trademarks, and related assets referenced remain the property of their respective copyright and trademark holders.\n\n'
            'BlueTalk is an independent, non-commercial project created solely for educational and personal development purposes.\n\n'
            'This application is developed by Rafiq8K, Founder of R8KStudio.\n\n'
            'Contact: r8kstudio@gmail.com',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('I Understand')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8D8F8),
        iconTheme: const IconThemeData(color: Colors.white), // Drawer icon white
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
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFFB8D8F8),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    (_userProfile?['name'] != null && _userProfile!['name'].isNotEmpty)
                        ? _userProfile!['name'][0].toUpperCase()
                        : 'S',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
                  ),
                ),
                accountName: Text(
                  _userProfile?['name'] ?? 'Sensei',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
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
                leading: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminScreen()),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.add_task_rounded, color: Color(0xFF135ACF)),
              title: const Text('Saranin Murid'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudentRequestScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
              title: const Text('Donasi (Trakteer)'),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://trakteer.id/r8kstudio'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Color(0xFF135ACF)),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFF135ACF)),
              title: const Text('Help & Support'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF135ACF)),
              title: const Text('About App'),
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(), // Pushes logout to bottom
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                _showLogoutDialog();    // Then show confirm
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
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
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF135ACF),
          unselectedItemColor: Colors.grey.withOpacity(0.6),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.style_outlined),
              activeIcon: Icon(Icons.style),
              label: 'Stories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
          ],
        ),
      ),
    );
  }
}
