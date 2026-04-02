import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/ai_service.dart';
import 'desktop/desktop_sidebar.dart';
import 'tabs/chat_tab.dart';
import 'tabs/create_tab.dart'; // this is actually the group tab? Group Tab has label "Group Chat" but uses CreateTab?
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';
import 'student_request_screen.dart';
import 'app_info_screen.dart';

class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

enum MiddlePanelState { tabs, settings, profile, admin, suggest, info }

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  int _currentIndex = 0;
  MiddlePanelState _middlePanelState = MiddlePanelState.tabs;
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _selectedBot;
  String? _defaultProvider;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProvider();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getUserProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  Future<void> _loadProvider() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultProvider = AIService.normalizeProvider(
        prefs.getString('default_provider'),
      );
    });
  }

  void _onChatSelected(Map<String, dynamic> bot) {
    setState(() {
      _selectedBot = bot;
    });
  }

  void _openSettings() {
    setState(() {
      _middlePanelState = MiddlePanelState.settings;
    });
  }

  void _handleMoreOptions(String option) {
    switch (option) {
      case 'admin':
        setState(() => _middlePanelState = MiddlePanelState.admin);
        break;
      case 'suggest':
        setState(() => _middlePanelState = MiddlePanelState.suggest);
        break;
      case 'donation':
        launchUrl(Uri.parse('https://trakteer.id/r8kstudio'));
        break;
      case 'contributor':
        launchUrl(Uri.parse('https://www.blog-rafiq8k.zone.id/2026/03/mencari-kontributor-r8kstudio.html'));
        break;
      case 'help':
        launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
        break;
      case 'info':
        setState(() => _middlePanelState = MiddlePanelState.info);
        break;
    }
  }

  void _openProfile() {
    setState(() {
      _middlePanelState = MiddlePanelState.profile;
    });
  }

  Widget _buildRightPanel() {
    if (_selectedBot != null) {
      // Return chat detail screen but possibly hide its back button if we update the ChatDetailScreen
      // For now, we can wrap it in a ClipRRect if we want rounded corners or just directly display it.
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: ChatDetailScreen(
          key: ValueKey(_selectedBot!['id']), // force rebuild when bot changes
          bot: _selectedBot!,
          provider: _defaultProvider ?? 'gemini',
          isDesktopMode: true, // we will add this parameter to ChatDetailScreen
        ),
      );
    }

    // Empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icon/icon.jpg',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'BlueTalk Desktop',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135ACF),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a chat to start messaging',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddlePanel() {
    switch (_middlePanelState) {
      case MiddlePanelState.settings:
        return const SettingsScreen();
      case MiddlePanelState.profile:
        return const ProfileScreen();
      case MiddlePanelState.admin:
        return const AdminScreen();
      case MiddlePanelState.suggest:
        return const StudentRequestScreen();
      case MiddlePanelState.info:
        return const AppInfoScreen();
      case MiddlePanelState.tabs:
        return IndexedStack(
          index: _currentIndex,
          children: [
            ChatTab(onChatSelected: _onChatSelected),
            const CreateTab(), // "Group" based on old mobile UI
            const StoriesTab(),
            const CalendarTab(),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: Row(
        children: [
          // Left Sidebar
          DesktopSidebar(
            currentIndex: _currentIndex,
            isSettingsSelected: _middlePanelState == MiddlePanelState.settings,
            onTabSelected: (index) {
              setState(() {
                _currentIndex = index;
                _middlePanelState = MiddlePanelState.tabs;
                // Calendar (3) and Stories (2) leave chat open. 
                // Group (1) is different and closes the chat screen.
                if (index == 1) {
                  _selectedBot = null;
                }
              });
            },
            onSettingsPressed: _openSettings,
            onMoreOptionSelected: _handleMoreOptions,
            profileAvatar: InkWell(
              onTap: _openProfile,
              child: CircleAvatar(
                backgroundColor: const Color(0xFFB8D8F8),
                radius: 24,
                child: Text(
                  (_userProfile?['name'] != null &&
                          _userProfile!['name'].isNotEmpty)
                      ? _userProfile!['name'][0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF135ACF),
                  ),
                ),
              ),
            ),
          ),
          // Vertical Divider
          Container(width: 1, color: Colors.grey.shade300),

          // Middle List Panel (Chats, Stories, Calendar)
          SizedBox(
            width: 380, // Fixed width for the list panel
            child: _buildMiddlePanel(),
          ),

          // Vertical Divider
          Container(width: 1, color: Colors.grey.shade300),

          // Right Chat/Detail Panel
          Expanded(
            child: Container(
              color: Colors.white,
              child: _buildRightPanel(),
            ),
          ),
        ],
      ),
    );
  }
}
