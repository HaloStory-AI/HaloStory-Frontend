import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import '../services/ai_service.dart';
import 'chat_screen.dart';
import 'desktop_home_screen.dart';
import 'select_contact_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/chat_tab.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/profile_tab.dart';

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
      const _KeepAliveWrapper(child: HomeTab()),
      _KeepAliveWrapper(child: ChatTab(key: _chatTabKey, onChatSelected: _onChatSelected)),
      const _KeepAliveWrapper(child: SizedBox.shrink()),
      const _KeepAliveWrapper(child: CalendarTab()),
      const _KeepAliveWrapper(child: ProfileTab()),
    ];
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
    setState(() => _currentIndex = index);
  }

  void _onBottomNavTap(int index) {
    if (index == 2) {
      _showCreateSheet();
      return;
    }
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  void _showCreateSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final sheetCs = Theme.of(sheetCtx).colorScheme;
        Widget tile({
          required IconData icon,
          required String title,
          String? subtitle,
          required VoidCallback onTap,
        }) {
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sheetCs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: sheetCs.onSecondaryContainer),
            ),
            title: Text(title, style: TextStyle(color: sheetCs.onSurface, fontWeight: FontWeight.w600)),
            subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: sheetCs.onSurfaceVariant, fontSize: 12)) : null,
            onTap: onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        }

        void snackSoon() {
          Navigator.pop(sheetCtx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('coming_soon')), behavior: SnackBarBehavior.floating),
          );
        }

        void openSingle() {
          Navigator.pop(sheetCtx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SelectContactScreen(
                mode: SelectContactMode.singleChat,
                onContactSelected: (chatData) => _onChatSelected(chatData),
                onCancel: () => Navigator.pop(context),
              ),
            ),
          );
        }

        void openGroup() {
          Navigator.pop(sheetCtx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SelectContactScreen(
                mode: SelectContactMode.newChat,
                onContactSelected: (chatData) => _onChatSelected(chatData),
                onCancel: () => Navigator.pop(context),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: sheetCs.outlineVariant, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                tile(icon: Icons.person_add_rounded, title: 'Buat Chat sendiri', subtitle: tr('tab_chat_single_chat'), onTap: openSingle),
                tile(icon: Icons.group_add_rounded, title: 'Buat Chat Group', subtitle: tr('tab_chat_group_chat'), onTap: openGroup),
                tile(icon: Icons.auto_awesome_rounded, title: 'Buat Karakter', subtitle: tr('coming_soon'), onTap: snackSoon),
                tile(icon: Icons.add_task_rounded, title: 'Minta Karakter', subtitle: tr('coming_soon'), onTap: snackSoon),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Image.asset(
                'assets/icon/mikazuki/mikazuki_192.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Mikazuki AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onBottomNavTap,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        height: 72,
        elevation: 0,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: tr('tab_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: const Icon(Icons.chat_bubble_rounded),
            label: tr('tab_chat'),
          ),
          NavigationDestination(
            icon: Container(
              width: 56,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_rounded, color: colorScheme.onPrimary, size: 22),
            ),
            selectedIcon: Container(
              width: 56,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_rounded, color: colorScheme.onPrimary, size: 22),
            ),
            label: '',
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: tr('tab_calendar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: tr('tab_profile'),
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
