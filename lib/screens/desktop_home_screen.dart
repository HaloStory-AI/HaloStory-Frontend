import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
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
import 'story_view_screen.dart';

class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

enum MiddlePanelState { tabs, settings, profile, admin, suggest, info, chat }

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  int _currentIndex = 0;
  MiddlePanelState _middlePanelState = MiddlePanelState.tabs;
  // Removed _userProfile as it is no longer used for the avatar
  Map<String, dynamic>? _selectedBot;
  String? _defaultProvider;
  List<Map<String, dynamic>>? _selectedStoryBots;
  Widget? _middlePanelOverlay;

  int _selectedStoryIndex = 0;
  String? _initialChatMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProvider();
  }

  Future<void> _loadProfile() async {
    // Left empty as _userProfile is no longer used for the sidebar avatar
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
      _selectedStoryBots = null;
      _initialChatMessage = null;
    });
  }

  void _onStorySelected(List<Map<String, dynamic>> botStories, int initialIndex) {
    setState(() {
      _selectedStoryBots = botStories;
      _selectedStoryIndex = initialIndex;
      _selectedBot = null;
    });
  }

  void _openSettings() {
    setState(() {
      _middlePanelOverlay = null; // Close any overlay
      _middlePanelState = MiddlePanelState.settings;
    });
  }

  void _handleMoreOptions(String option) {
    if (option == 'disclaimer') _showDisclaimerOverlay();
    if (option == 'donation') _showDonationOverlay();
    if (option == 'contributor' || option == 'suggest' || option == 'help') {
      launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
    }
    if (option == 'info') {
      _showInfoOverlay();
    }
    switch (option) {
      case 'admin':
        setState(() {
          _middlePanelOverlay = null;
          _middlePanelState = MiddlePanelState.admin;
        });
        break;
    }
  }

  void _openProfile() {
    setState(() {
      _middlePanelState = MiddlePanelState.profile;
    });
  }

  void _showDisclaimerOverlay() {
    setState(() {
      _middlePanelOverlay = _buildLocalOverlay(
        title: tr('disclaimer_title'),
        content: SingleChildScrollView(child: Text(tr('disclaimer_content'))),
      );
    });
  }

  void _showDonationOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    setState(() {
      _middlePanelOverlay = _buildLocalOverlay(
        title: tr('donation_title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('donation_content'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => launchUrl(Uri.parse('https://trakteer.id/rafiq8k')),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr('donation_button')),
            ),
          ],
        ),
      );
    });
  }

  void _showInfoOverlay() {
    setState(() {
      _middlePanelOverlay = _buildLocalOverlay(
        title: tr('sidebar_info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/icon/icon.png'),
            ),
            const SizedBox(height: 16),
            Text(tr('app_name'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('${tr('app_info_version')} 0.7.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Text(tr('welcome_made_by'), textAlign: TextAlign.center),
          ],
        ),
      );
    });
  }

  void _showSortOverlay(Widget content) {
    setState(() {
      _middlePanelOverlay = content;
    });
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
              // Implementation of actual logout usually goes here
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

  Widget _buildLocalOverlay({required String title, required Widget content}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _middlePanelOverlay = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatColumnHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor =
        isDark ? theme.scaffoldBackgroundColor : AppTheme.momoLightTopBar;

    return Material(
      color: barColor,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
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
                fontSize: 22,
              ),
            ),
            const SizedBox(width: 6),
            // Disclaimer Icon
            InkWell(
              onTap: _showDisclaimerOverlay,
              borderRadius: BorderRadius.circular(5),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.question_mark_rounded,
                  color: isDark ? theme.scaffoldBackgroundColor : AppTheme.momoLightTopBar,
                  size: 14,
                  weight: 900,
                ),
              ),
            ),
            const Spacer(),
            // Profile Avatar
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: _openProfile,
                borderRadius: BorderRadius.circular(12),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  backgroundImage: const AssetImage('assets/icon/avatar.png'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedStoryBots != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: StoryViewScreen(
          key: ValueKey('story_${_selectedStoryBots!.first['bot_id']}'), 
          stories: _selectedStoryBots!,
          initialIndex: _selectedStoryIndex,
          onClose: () {
            setState(() {
              _selectedStoryBots = null;
            });
          },
          onReply: (bot, message) {
            setState(() {
              _selectedStoryBots = null;
              _selectedBot = bot;
              _initialChatMessage = message;
            });
          },
        ),
      );
    }

    if (_selectedBot != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: ChatDetailScreen(
          key: ValueKey('${_selectedBot!['id']}_$_initialChatMessage'),
          bot: _selectedBot!,
          provider: _defaultProvider ?? 'gemini',
          isDesktopMode: true,
          initialMessage: _initialChatMessage,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
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
          Text(
            'BlueTalk Desktop',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a chat to start messaging',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddlePanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 380,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: isDark ? colorScheme.outlineVariant : Colors.grey.shade200,
          ),
        ),
      ),
      child: Stack(
        children: [
          _buildMainMiddleContent(isDark, colorScheme),
          if (_middlePanelOverlay != null) _middlePanelOverlay!,
        ],
      ),
    );
  }

  Widget _buildMainMiddleContent(bool isDark, ColorScheme colorScheme) {
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
      case MiddlePanelState.chat:
        return const Center(child: Text("Chat View"));
      case MiddlePanelState.tabs:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChatColumnHeader(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  ChatTab(
                    onChatSelected: _onChatSelected,
                    onShowSort: _showSortOverlay,
                  ),
                  const CreateTab(),
                  StoriesTab(onStorySelected: _onStorySelected),
                  const CalendarTab(),
                ],
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          DesktopSidebar(
            currentIndex: _currentIndex,
            isSettingsSelected: _middlePanelState == MiddlePanelState.settings,
            onTabSelected: (index) {
              Navigator.maybePop(context);
              setState(() {
                _middlePanelOverlay = null; // Clear overlay on tab switch
                _currentIndex = index;
                _middlePanelState = MiddlePanelState.tabs;
                // Calendar (3) and Stories (2) leave chat open. 
                // Group (1) is different and closes the chat screen.
                if (index == 1) {
                  _selectedBot = null;
                  _selectedStoryBots = null;
                }
              });
            },
            onSettingsPressed: _openSettings,
            onLogoutPressed: _showLogoutDialog,
            onMoreOptionSelected: _handleMoreOptions,
          ),
          Container(width: 1, color: cs.outlineVariant),

          SizedBox(
            width: 380,
            child: _buildMiddlePanel(),
          ),

          Container(width: 1, color: cs.outlineVariant),

          Expanded(
            child: Container(
              color: cs.surfaceContainer,
              child: _buildRightPanel(),
            ),
          ),
        ],
      ),
    );
  }
}
