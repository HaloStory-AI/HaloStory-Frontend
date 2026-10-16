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
import 'settings_screen.dart';

import 'app_info_screen.dart';
import 'desktop_home_screen.dart';
import 'tabs/chat_tab.dart';
import 'tabs/stories_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/more_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  final GlobalKey<ChatTabState> _chatTabKey = GlobalKey<ChatTabState>();

  @override
  void initState() {
    super.initState();
    _tabs = [
      _KeepAliveWrapper(child: ChatTab(key: _chatTabKey, onChatSelected: _onChatSelected)),
      const _KeepAliveWrapper(child: StoriesTab()),
      const _KeepAliveWrapper(child: CalendarTab()),
      const _KeepAliveWrapper(child: MoreTab()),
    ];
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
                onPressed: () {
                  Navigator.pop(sheetContext);
                  launchUrl(
                    Uri.parse('https://trakteer.id/r8kstudio'),
                    mode: LaunchMode.externalApplication,
                  );
                },
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



  Future<void> _onChatSelected(Map<String, dynamic> bot) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final provider = AIService.normalizeProvider(
      prefs.getString('default_provider'),
    );
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(bot: bot, provider: provider),
      ),
    );
    if (!mounted) return;
    if (result != null && result['type'] == 'group_info_updated') {
      _chatTabKey.currentState?.initData();
    }
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
            content: SingleChildScrollView(
              child: Text(tr('disclaimer_content')),
            ),
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

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    Navigator.maybePop(context);
    setState(() => _currentIndex = index);
  }

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return;

    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 800;

    if (isDesktop) {
      return const DesktopHomeScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appBarBg = isDark
        ? theme.scaffoldBackgroundColor
        : AppTheme.momoLightTopBar;
    final sidebarBg = isDark
        ? colorScheme.surface
        : AppTheme.momoRailBackground;
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
                fontSize: 24,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _showDisclaimer,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
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
                      ? theme.scaffoldBackgroundColor
                      : AppTheme.momoLightTopBar,
                  size: 18,
                  weight: 900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
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
                    iconAsset: 'assets/icon/sidebar_stories.svg',
                    index: 1,
                    isSelected: _currentIndex == 1,
                    selectedBackgroundColor: sidebarSelectedBg,
                    selectedColor: sidebarIconSelectedColor,
                    unselectedColor: sidebarIconColor,
                  ),
                  _buildSidebarNavItem(
                    iconAsset: 'assets/icon/sidebar_calendar.svg',
                    index: 2,
                    isSelected: _currentIndex == 2,
                    selectedBackgroundColor: sidebarSelectedBg,
                    selectedColor: sidebarIconSelectedColor,
                    unselectedColor: sidebarIconColor,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: sidebarIconColor,
                      size: 28,
                    ),
                    offset: const Offset(50, -120),
                    color: isDark ? colorScheme.surfaceContainer : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'admin':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminScreen(),
                            ),
                          );
                          break;
                        case 'donation':
                          launchUrl(
                            Uri.parse('https://trakteer.id/r8kstudio'),
                            mode: LaunchMode.externalApplication,
                          );
                          break;
                        case 'contributor':
                          launchUrl(
                            Uri.parse('https://github.com/HaloStory-AI'),
                            mode: LaunchMode.externalApplication,
                          );
                          break;
                        case 'help':
                          launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
                          break;
                        case 'info':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AppInfoScreen(),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'admin',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('sidebar_admin_panel'),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'donation',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Colors.pinkAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('sidebar_donation'),
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'contributor',
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('sidebar_contributor'),
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'help',
                        child: Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('sidebar_help'),
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('sidebar_info'),
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: sidebarIconColor,
                          size: 28,
                        ),
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
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('sidebar_logout'),
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.8),
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
            child: SafeArea(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onBottomNavTap,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: isDark ? colorScheme.surface : Colors.white,
                  selectedItemColor: colorScheme.primary,
                  unselectedItemColor: isDark
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : Colors.grey,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  elevation: 0,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: tr('tab_chat'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.auto_stories),
                      label: tr('tab_stories'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: tr('tab_calendar'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.grid_view_rounded),
                      label: 'More',
                    ),
                  ],
                ),
              ),
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
