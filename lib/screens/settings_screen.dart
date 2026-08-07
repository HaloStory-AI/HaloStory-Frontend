import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'settings/general_settings_page.dart';
import 'settings/appearance_settings_page.dart';
import 'settings/ai_engine_settings_page.dart';
import 'settings/backup_settings_page.dart';
import 'settings/developer_mode_page.dart';
import 'settings/privacy_settings_page.dart';

class SettingsScreen extends StatelessWidget {
  final Function(Widget page, String title)? onNavigate;

  const SettingsScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : theme.colorScheme.surfaceContainer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('settings_title'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCard(
              context: context,
              icon: Icons.tune,
              title: tr('settings_tab_general'),
              subtitle: 'Language, Theme, AI Engine',
              surfaceColor: surface,
              page: const GeneralSettingsPage(),
            ),
            const SizedBox(height: 1),
            _buildCard(
              context: context,
              icon: Icons.palette,
              title: tr('settings_tab_appearance'),
              subtitle: 'Theme, Display, Language',
              surfaceColor: surface,
              page: const AppearanceSettingsPage(),
            ),
            const SizedBox(height: 1),
            _buildCard(
              context: context,
              icon: Icons.api,
              title: tr('settings_tab_ai'),
              subtitle: 'BYOK Config, Gen Parameters',
              surfaceColor: surface,
              page: const AIEngineSettingsPage(),
            ),
            const SizedBox(height: 1),
            _buildCard(
              context: context,
              icon: Icons.cloud_sync,
              title: tr('settings_tab_backup'),
              subtitle: 'P2P QR, Cloud Backup',
              surfaceColor: surface,
              page: const BackupSettingsPage(),
            ),
            const SizedBox(height: 1),
            _buildCard(
              context: context,
              icon: Icons.privacy_tip,
              title: tr('settings_tab_privacy'),
              subtitle: 'Data, Permissions, Policy',
              surfaceColor: surface,
              page: const PrivacySettingsPage(),
            ),
            const SizedBox(height: 1),
            _buildCard(
              context: context,
              icon: Icons.developer_mode,
              title: tr('settings_tab_developer'),
              subtitle: 'Debug, Logs, Config',
              surfaceColor: surface,
              page: const DeveloperModePage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color surfaceColor,
    required Widget page,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SettingsCard(
        icon: icon,
        title: title,
        subtitle: subtitle,
        surfaceColor: surfaceColor,
        onTap: () {
          if (onNavigate != null) {
            onNavigate!(page, title);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            );
          }
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
