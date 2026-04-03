import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../services/localization_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/security_service.dart';
import 'splash_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _selectedLanguageCode = 'id';
  bool _isCheckingBackup = false;

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = LocalizationService().currentLocale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCloudBackup();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _languages = [
    {'name': 'Bahasa Indonesia', 'code': 'id'},
    {'name': 'English', 'code': 'en'},
    {'name': 'Chinese', 'code': 'zh'},
    {'name': 'Japanese', 'code': 'ja'},
    {'name': '한국어', 'code': 'ko'},
  ];

  Future<void> _completeSetup() async {
    if (!kIsWeb) {
      await [
        Permission.photos,
        Permission.storage,
        Permission.notification,
        if (Platform.isAndroid) Permission.manageExternalStorage,
      ].request();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'default_provider',
      'System',
    );

    await prefs.setBool('is_setup_completed', true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _checkCloudBackup() async {
    setState(() => _isCheckingBackup = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        setState(() => _isCheckingBackup = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/user/restore'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final backupDate = DateTime.parse(data['data']['updated_at']);
          final formattedDate = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(backupDate.toLocal());

          if (mounted) {
            _showRestorePrompt(formattedDate, data['data']['payload']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking cloud backup: $e');
    } finally {
      if (mounted) setState(() => _isCheckingBackup = false);
    }
  }

  void _showRestorePrompt(String date, String encryptedPayload) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_download, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('setup_backup_found'))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('setup_backup_date').replaceFirst('{date}', date)),
              const SizedBox(height: 12),
              Text(
                tr('setup_backup_question'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('setup_btn_skip'),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _restoreFromCloud(encryptedPayload);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                tr('setup_btn_restore'),
                style: TextStyle(color: colorScheme.onPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restoreFromCloud(String encryptedPayload) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final decryptedData = SecurityService.decryptData(encryptedPayload);
      final data = json.decode(decryptedData);

      final prefs = await SharedPreferences.getInstance();

      if (data['settings'] != null) {
        final settings = data['settings'] as Map<String, dynamic>;
        settings.forEach((key, value) {
          if (value is String) prefs.setString(key, value);
          if (value is bool) prefs.setBool(key, value);
          if (value is int) prefs.setInt(key, value);
          if (value is double) prefs.setDouble(key, value);
        });
      }

      if (data['chats'] != null) {
        final chats = data['chats'] as Map<String, dynamic>;
        chats.forEach((key, value) {
          prefs.setString(key, json.encode(value));
        });
      }

      await prefs.setBool('is_setup_completed', true);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('settings_restore_success'))));
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SplashScreen()),
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('settings_restore_fail'))));
      }
      debugPrint('Restore error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = tr('setup_title_language');
    String subTitle = tr('setup_subtitle_language');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(child: _buildCurrentStepView()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _completeSetup,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 50),
                    ),
                    child: Text(tr('btn_finish')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    return _buildLanguageSelection();
  }

  Widget _buildLanguageSelection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: _languages.map((lang) {
        final isSelected = _selectedLanguageCode == lang['code'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() => _selectedLanguageCode = lang['code']!);
              LocalizationService().load(lang['code']!);
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang['name']!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: colorScheme.primary)
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
