import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../profile_screen.dart';
import '../admin_screen.dart';
import '../student_request_screen.dart';
import '../settings_screen.dart';
import '../app_info_screen.dart';
import '../../services/ban_service.dart';
import '../splash_screen.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _auth.getUserProfile();
    if (mounted) {
      setState(() {
        _user = profile;
        _isLoading = false;
      });
    }
  }

  String _maskEmail(String? email) {
    if (email == null || email.length <= 6) return email ?? '';
    return '${email.substring(0, 3)}...@...${email.substring(email.length - 3)}';
  }

  Color _roleBgColor(String? role) {
    return switch (role) {
      'admin' => Colors.amber,
      'vip' => const Color(0xFFFFD700),
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  IconData _roleIcon(String? role) {
    return switch (role) {
      'admin' => Icons.shield_rounded,
      'vip' => Icons.star_rounded,
      _ => Icons.person_rounded,
    };
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sidebar_logout')),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _auth.logout();
              BanService.clearBan();
              if (!mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
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
    final cardColor = colorScheme.surface;

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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
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
                          _user?['name'] ?? 'Sensei',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _maskEmail(_user?['email']),
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _roleBgColor(_user?['role']).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _roleBgColor(_user?['role']).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _roleIcon(_user?['role']),
                              size: 14,
                              color: _roleBgColor(_user?['role']),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _user?['role']?.toString().toUpperCase() ?? 'USER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _roleBgColor(_user?['role']),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_user?['role'] == 'vip' &&
                          _user?['vip_expires_at'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Exp: ${_user!['vip_expires_at'].toString().substring(0, 10)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Admin Section ──
        if (_user?['role'] == 'admin') ...[
          _sectionHeader('Admin'),
          Card(
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              tileColor: Colors.transparent,
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.amber,
              ),
              title: Text(
                tr('sidebar_admin_panel'),
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminScreen(),
                  ),
                );
              },
            ),
          ),
        ],

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
                  Icons.add_task_rounded,
                  color: colorScheme.primary,
                ),
                title: Text(tr('sidebar_suggest_student')),
                trailing: Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentRequestScreen(),
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
                  launchUrl(Uri.parse('https://s.my-bini.my.id/discord'));
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

        // ── Account Section ──
        _sectionHeader(tr('sidebar_logout')),
        Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            tileColor: Colors.transparent,
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text(
              tr('sidebar_logout'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: _showLogoutDialog,
          ),
        ),
      ],
    );
  }
}
