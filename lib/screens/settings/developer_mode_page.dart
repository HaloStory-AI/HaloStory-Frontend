import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';

class DeveloperModePage extends StatefulWidget {
  final bool isDesktop;

  const DeveloperModePage({super.key, this.isDesktop = false});

  @override
  State<DeveloperModePage> createState() => _DeveloperModePageState();
}

class _DeveloperModePageState extends State<DeveloperModePage> {
  bool _developerModeEnabled = false;
  bool _copyByokLogEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _developerModeEnabled = prefs.getBool('developer_mode_enabled') ?? false;
      _copyByokLogEnabled = prefs.getBool('dev_copy_byok_log') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final confirmed = await _showWarningDialog();
      if (confirmed == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('developer_mode_enabled', true);
        if (!mounted) return;
        setState(() => _developerModeEnabled = true);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('developer_mode_enabled', false);
      setState(() => _developerModeEnabled = false);
    }
  }

  Future<void> _toggleCopyByokLog(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_copy_byok_log', value);
    if (!mounted) return;
    setState(() => _copyByokLogEnabled = value);
  }

  Future<bool?> _showWarningDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool agreed = false;
        int countdown = 10;
        Timer? timer;

        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              if (timer == null && countdown > 0) {
                timer = Timer.periodic(const Duration(seconds: 1), (t) {
                  if (countdown <= 1) {
                    t.cancel();
                  }
                  setDialogState(() => countdown--);
                });
              }

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr('dev_mode_dialog_title')),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('dev_mode_warning'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('dev_mode_risks'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('dev_mode_disclaimer'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: agreed,
                        onChanged: (v) =>
                            setDialogState(() => agreed = v ?? false),
                        title: Text(tr('dev_mode_agree')),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      timer?.cancel();
                      Navigator.of(ctx).pop(false);
                    },
                    child: Text(tr('dev_mode_cancel')),
                  ),
                  ElevatedButton(
                    onPressed: (agreed && countdown <= 0)
                        ? () {
                            timer?.cancel();
                            Navigator.of(ctx).pop(true);
                          }
                        : null,
                    child: Text(
                      countdown > 0
                          ? '${tr('dev_mode_proceed')} ($countdown)'
                          : tr('dev_mode_proceed'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? colorScheme.surface
        : colorScheme.surfaceContainer;

    return Scaffold(
      appBar: widget.isDesktop
          ? null
          : AppBar(
              title: Text(
                tr('settings_tab_developer'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        tr('dev_mode_switch_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _developerModeEnabled
                            ? tr('dev_mode_switch_on_subtitle')
                            : tr('dev_mode_switch_off_subtitle'),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _developerModeEnabled,
                      activeThumbColor: colorScheme.primary,
                      onChanged: _toggle,
                    ),
                  ),
                  if (_developerModeEnabled) ...[
                    const SizedBox(height: 24),
                    Text(
                      tr('dev_mode_features_title'),
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
                          tr('dev_mode_copy_log_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          tr('dev_mode_copy_log'),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: _copyByokLogEnabled,
                        activeThumbColor: colorScheme.primary,
                        onChanged: _toggleCopyByokLog,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
