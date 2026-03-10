import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../services/localization_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _selectedLanguageCode = 'id';
  int _currentStep = 0;

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = LocalizationService().currentLocale;
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    await [
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ].request();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
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
    final prefs = await SharedPreferences.getInstance();
    // app_language is already saved by LocalizationService().load()
    await prefs.setString(
      'default_provider',
      'System',
    ); // Always default to System

    await prefs.setBool('is_setup_completed', true);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showSkipConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('setup_confirm_title')),
        content: Text(tr('setup_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('setup_confirm_no')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeSetup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135ACF),
              minimumSize: const Size(80, 40),
            ),
            child: Text(tr('setup_confirm_yes')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = tr('setup_title_language');
    String subTitle = tr('setup_subtitle_language');

    if (_currentStep == 1) {
      title = tr('setup_title_permissions');
      subTitle = tr('setup_subtitle_permissions');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF135ACF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subTitle,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(child: _buildCurrentStepView()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: Text(
                        tr('btn_back'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  if (_currentStep < 1)
                    ElevatedButton(
                      onPressed: () => setState(() => _currentStep++),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 50),
                      ),
                      child: Text(tr('btn_next')),
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: _showSkipConfirmation,
                          child: Text(
                            tr('btn_skip'),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildLanguageSelection();
      case 1:
        return _buildPermissionsView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPermissionsView() {
    return Column(
      children: [
        _buildPermissionItem(
          icon: Icons.notifications_active_outlined,
          title: tr('setup_permission_notification'),
          desc: tr('setup_permission_notification_desc'),
        ),
        const SizedBox(height: 16),
        _buildPermissionItem(
          icon: Icons.photo_library_outlined,
          title: tr('setup_permission_storage'),
          desc: tr('setup_permission_storage_desc'),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _requestPermissions,
          icon: const Icon(Icons.security),
          label: Text(tr('setup_grant_btn')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF135ACF).withOpacity(0.1),
            foregroundColor: const Color(0xFF135ACF),
            elevation: 0,
            side: const BorderSide(color: Color(0xFF135ACF)),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.battery_alert, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('setup_battery_tip'),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF135ACF).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFF135ACF)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelection() {
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
                    ? const Color(0xFF135ACF).withOpacity(0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF135ACF)
                      : Colors.transparent,
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
                          ? const Color(0xFF135ACF)
                          : Colors.black87,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFF135ACF))
                  else
                    const Icon(Icons.circle_outlined, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
