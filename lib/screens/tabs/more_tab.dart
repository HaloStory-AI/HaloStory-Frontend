import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../profile_screen.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
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
      ],
    );
  }
}
