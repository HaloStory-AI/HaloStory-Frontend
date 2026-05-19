import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';
import '../../services/theme_service.dart';
import '../splash_screen.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  String _currentLanguage = 'id';
  bool _isLanguageChanged = false;
  bool _amoledDarkEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _currentLanguage = LocalizationService().currentLocale;
      _amoledDarkEnabled = ThemeService().isAmoledDark;
    });
  }

  Future<void> _saveSettings() async {
    await ThemeService().setAmoledDark(_amoledDarkEnabled);

    if (!mounted) return;
    if (_isLanguageChanged) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_saved_success')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardColor = isDark
        ? colorScheme.surface
        : colorScheme.surfaceContainer;
    final Color textColor = colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('settings_tab_appearance'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Section: Language ──
            Text(
              tr('settings_language'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _currentLanguage,
                  items: [
                    DropdownMenuItem(
                      value: 'id',
                      child: Text(tr('settings_language_id')),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(tr('settings_language_en')),
                    ),
                    DropdownMenuItem(
                      value: 'zh',
                      child: Text(tr('settings_language_zh')),
                    ),
                    DropdownMenuItem(
                      value: 'ja',
                      child: Text(tr('settings_language_ja')),
                    ),
                    DropdownMenuItem(
                      value: 'ko',
                      child: Text(tr('settings_language_ko')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _currentLanguage = v;
                        _isLanguageChanged = true;
                      });
                      LocalizationService().load(v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Section: Theme ──
            Text(
              tr('settings_theme'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text(
                  tr('settings_theme_amoled_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  tr('settings_theme_amoled_desc'),
                  style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                ),
                value: _amoledDarkEnabled,
                activeThumbColor: colorScheme.primary,
                onChanged: (bool value) {
                  setState(() => _amoledDarkEnabled = value);
                  ThemeService().setAmoledDark(value);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              tr('settings_save_btn'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
