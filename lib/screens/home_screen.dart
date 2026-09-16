import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import '../services/ai_service.dart';
import 'chat_screen.dart';
import 'desktop_home_screen.dart';
import 'donation_screen.dart';
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DonationScreen(),
                    ),
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
    setState(() => _currentIndex = index);
  }

  void _onBottomNavTap(int index) {
    if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('coming_soon')),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
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
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
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
                  backgroundColor: colorScheme.surface,
                  selectedItemColor: colorScheme.primary,
                  unselectedItemColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  selectedFontSize: 10,
                  unselectedFontSize: 10,
                  elevation: 0,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_rounded),
                      label: tr('tab_home'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: tr('tab_chat'),
                    ),
                    BottomNavigationBarItem(
                      icon: Container(
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
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: tr('tab_calendar'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_rounded),
                      label: tr('tab_profile'),
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
