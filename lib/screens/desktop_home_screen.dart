import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'desktop/desktop_sidebar.dart';
import 'tabs/chat_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/more_tab.dart';
import 'settings_screen.dart';
import '../widgets/settings_panel.dart';
import '../widgets/overlay_panel.dart';
import 'chat_screen.dart';
import 'story_view_screen.dart';
import '../widgets/vip_plus_gate.dart';
import 'select_contact_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';
import 'student_request_screen.dart';
import 'app_info_screen.dart';
class DesktopHomeScreen extends StatefulWidget {
  const DesktopHomeScreen({super.key});

  @override
  State<DesktopHomeScreen> createState() => _DesktopHomeScreenState();
}

enum MiddlePanelState {
  tabs,
  settings,
  profile,
  admin,
  suggest,
  info,
  chat,
  selectContact,
}

class _DesktopHomeScreenState extends State<DesktopHomeScreen> {
  int _currentIndex = 0;
  MiddlePanelState _middlePanelState = MiddlePanelState.tabs;
  final GlobalKey<NavigatorState> _moreTabNavKey = GlobalKey<NavigatorState>();
  // Removed _userProfile as it is no longer used for the avatar
  Map<String, dynamic>? _selectedBot;
  List<Map<String, dynamic>>? _selectedStories;
  int? _selectedStoryIndex;
  String? _defaultProvider;
  Widget? _middlePanelOverlay;

  String? _initialChatMessage;

  Widget? _currentSettingsPage;
  String? _currentSettingsTitle;

  Widget? _panel4Content;
  String? _panel4Title;
  bool _panel4Visible = false;

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
      _selectedStories = null;
      _selectedStoryIndex = null;
      _selectedBot = bot;
      _initialChatMessage = null;
      _panel4Visible = false;
      _panel4Content = null;
      _panel4Title = null;
    });
  }

  void _onStorySelected(List<Map<String, dynamic>> stories, int index) {
    setState(() {
      _selectedBot = null;
      _selectedStories = stories;
      _selectedStoryIndex = index;
    });
  }

  void _onStoryReply(Map<String, dynamic> bot, String message) {
    setState(() {
      _selectedStories = null;
      _selectedStoryIndex = null;
      _selectedBot = bot;
      _initialChatMessage = message;
    });
  }


  void _onOpenSettingsPage(Widget page, String title) {
    setState(() {
      _currentSettingsPage = page;
      _currentSettingsTitle = title;
    });
  }

  void _openPanel4(Widget child, String title) {
    setState(() {
      _panel4Content = null;
      _panel4Title = title;
      _panel4Content = child;
      _panel4Visible = true;
    });
  }

  void _closePanel4() {
    setState(() {
      _panel4Visible = false;
      _panel4Content = null;
      _panel4Title = null;
    });
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

  void _showSortOverlay(Widget content) {
    setState(() {
      _middlePanelOverlay = content;
    });
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
    final barColor = isDark
        ? theme.scaffoldBackgroundColor
        : AppTheme.momoLightTopBar;

    return Material(
      color: barColor,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: SvgPicture.asset(
                'assets/icon/HaloStory.svg',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'HaloStory',
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
                  color: isDark
                      ? theme.scaffoldBackgroundColor
                      : AppTheme.momoLightTopBar,
                  size: 14,
                  weight: 900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedStories != null && _selectedStoryIndex != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: StoryViewScreen(
          key: ValueKey('stories_$_selectedStoryIndex'),
          stories: _selectedStories!,
          initialIndex: _selectedStoryIndex!,
          onClose: () => setState(() {
            _selectedStories = null;
            _selectedStoryIndex = null;
          }),
          onReply: _onStoryReply,
        ),
      );
    }

    if (_selectedBot != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: VipPlusGate(
          child: ChatDetailScreen(
            key: ValueKey('${_selectedBot!['id']}_$_initialChatMessage'),
            bot: _selectedBot!,
            provider: _defaultProvider ?? 'gemini',
            isDesktopMode: true,
            initialMessage: _initialChatMessage,
            onChatDeleted: () {
              setState(() {
                _selectedBot = null;
              });
            },
            onOpenPanel4: _openPanel4,
            onClosePanel4: _closePanel4,
          ),
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
              'assets/icon/HaloStory.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'HaloStory Desktop',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a chat to start messaging',
            style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
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
          ?_middlePanelOverlay,
        ],
      ),
    );
  }

  Widget _buildMainMiddleContent(bool isDark, ColorScheme colorScheme) {
    switch (_middlePanelState) {
      case MiddlePanelState.settings:
        if (_currentSettingsPage != null) {
          return SettingsPanel(
            title: _currentSettingsTitle ?? '',
            onBack: () {
              setState(() {
                _currentSettingsPage = null;
              });
            },
            child: _currentSettingsPage!,
          );
        }
        return SettingsScreen(onNavigate: _onOpenSettingsPage);
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
      case MiddlePanelState.selectContact:
        return SelectContactScreen(
          onContactSelected: (chatData) {
            setState(() {
              _middlePanelState = MiddlePanelState.tabs;
            });
            _onChatSelected(chatData);
          },
          onCancel: () {
            setState(() {
              _middlePanelState = MiddlePanelState.tabs;
            });
          },
        );
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
                    onAddContact: () {
                      setState(() {
                        _middlePanelState = MiddlePanelState.selectContact;
                      });
                    },
                  ),
                  StoriesTab(onStorySelected: _onStorySelected),
                  const CalendarTab(),
                  Navigator(
                    key: _moreTabNavKey,
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute(
                        builder: (context) => const MoreTab(),
                      );
                    },
                  ),
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
      body: Stack(
        children: [
          Row(
            children: [
              DesktopSidebar(
                currentIndex: _currentIndex,
                onTabSelected: (index) {
                  setState(() {
                    _middlePanelOverlay = null;
                    _currentIndex = index;
                    _middlePanelState = MiddlePanelState.tabs;
                  });
                },
              ),
              Container(width: 1, color: cs.outlineVariant),

              SizedBox(width: 380, child: _buildMiddlePanel()),

              Container(width: 1, color: cs.outlineVariant),

              Expanded(
                child: Container(
                  color: cs.surfaceContainer,
                  child: _buildRightPanel(),
                ),
              ),
            ],
          ),

          // Panel 4 overlay (slide from right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            right: _panel4Visible ? 0 : -380.0,
            top: 0,
            bottom: 0,
            width: 380,
            child: Material(
              elevation: 8,
              color: theme.scaffoldBackgroundColor,
              child: _panel4Content != null
                  ? OverlayPanel(
                      title: _panel4Title ?? '',
                      onClose: _closePanel4,
                      child: _panel4Content!,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
