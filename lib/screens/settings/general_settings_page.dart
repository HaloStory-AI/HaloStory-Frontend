import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';
import '../../services/ai_service.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  String _selectedProvider = 'System';
  bool _aiReasoningEnabled = false;
  final List<String> _providers = ['System', 'BYOK'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedProvider = AIService.normalizeProvider(
        prefs.getString('default_provider'),
      );
      if (_selectedProvider == 'BYOM') {
        _selectedProvider = 'System';
        prefs.setString('default_provider', 'System');
      }
      _aiReasoningEnabled = prefs.getBool('ai_reasoning_enabled') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_provider', _selectedProvider);
    await prefs.setBool('ai_reasoning_enabled', _aiReasoningEnabled);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('settings_saved_success')),
        backgroundColor: Colors.green,
      ),
    );
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
          tr('settings_tab_general'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Section: Active AI Engine ──
            Text(
              tr('settings_ai_active'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('settings_ai_active_desc'),
              style: TextStyle(color: textColor.withValues(alpha: 0.8)),
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
                  value: _selectedProvider,
                  items: _providers
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedProvider = v!),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ── Section: AI Reasoning ──
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text(
                  tr('settings_ai_reasoning_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  tr('settings_ai_reasoning_desc'),
                  style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                ),
                value: _aiReasoningEnabled,
                activeThumbColor: colorScheme.primary,
                onChanged: (bool value) {
                  setState(() => _aiReasoningEnabled = value);
                },
              ),
            ),
            const SizedBox(height: 24),

            // ── Section: About Modes ──
            Text(
              tr('settings_about_mode'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            _buildModeInfo('System', tr('settings_mode_system_desc')),
            _buildModeInfo('BYOK', tr('settings_mode_byok_desc')),
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

  Widget _buildModeInfo(String title, String desc) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            desc,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
