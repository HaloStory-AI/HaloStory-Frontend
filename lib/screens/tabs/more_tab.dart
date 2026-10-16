import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/localization_service.dart';
import '../../services/local_user_service.dart';
import '../profile_screen.dart';
import '../settings_screen.dart';
import '../app_info_screen.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  String _name = LocalUserService.defaultName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final n = LocalUserService.getLocalUserNameSync(prefs);
    if (mounted) {
      setState(() {
        _name = n;
        _isLoading = false;
      });
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? colorScheme.surface
        : colorScheme.surfaceContainer;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Profile Card ──
        Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              if (!mounted) return;
              _loadName();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: const AssetImage('assets/icon/avatar.png'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('profile_full_name'),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Community Section ──
        _sectionHeader(tr('sidebar_contributor')),
        Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                leading: Icon(
                  Icons.people_outline_rounded,
                  color: colorScheme.primary,
                ),
                title: Text(tr('sidebar_contributor')),
                trailing: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://github.com/HaloStory-AI'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
        ),

        // ── Support Section ──
        _sectionHeader(tr('sidebar_help')),
        Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                leading: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.pinkAccent,
                ),
                title: Text(tr('sidebar_donation')),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  launchUrl(
                    Uri.parse('https://trakteer.id/r8kstudio'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outlineVariant,
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: Icon(
                  Icons.help_outline,
                  color: colorScheme.primary,
                ),
                title: Text(tr('sidebar_help')),
                trailing: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
                },
              ),
            ],
          ),
        ),

        // ── App Section ──
        _sectionHeader(tr('sidebar_settings')),
        Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                tileColor: Colors.transparent,
                leading: Icon(
                  Icons.settings_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(tr('sidebar_settings')),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outlineVariant,
              ),
              ListTile(
                tileColor: Colors.transparent,
                leading: Icon(
                  Icons.info_outline,
                  color: colorScheme.primary,
                ),
                title: Text(tr('sidebar_info')),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppInfoScreen(),
                    ),
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
