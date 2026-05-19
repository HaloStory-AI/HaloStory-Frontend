import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'settings/general_settings_page.dart';
import 'settings/appearance_settings_page.dart';
import 'settings/ai_engine_settings_page.dart';
import 'settings/backup_settings_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            _SettingsCard(
              icon: Icons.tune,
              title: tr('settings_tab_general'),
              subtitle: 'Language, Theme, AI Engine',
              surfaceColor: surface,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GeneralSettingsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.palette,
              title: tr('settings_tab_appearance'),
              subtitle: 'Theme, Display, Language',
              surfaceColor: surface,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppearanceSettingsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.api,
              title: tr('settings_tab_ai'),
              subtitle: 'BYOK Config, Gen Parameters',
              surfaceColor: surface,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIEngineSettingsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              icon: Icons.cloud_sync,
              title: tr('settings_tab_backup'),
              subtitle: 'P2P QR, Cloud Backup',
              surfaceColor: surface,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupSettingsPage()),
              ),
            ),
          ],
        ),
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
