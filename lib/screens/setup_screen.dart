import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _selectedLanguage = 'Indonesian';
  String _selectedProvider = 'Groq (System)';
  int _currentStep = 0;

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    final status = await [
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
    super.dispose();
  }

  final List<Map<String, String>> _languages = [
    {'name': 'Indonesian', 'code': 'id'},
    {'name': 'English', 'code': 'en'},
    {'name': 'Chinese', 'code': 'zh'},
    {'name': 'Japanese', 'code': 'ja'},
  ];

  final List<String> _providers = [
    'Groq (System)',
    'Groq (Self)',
    'OpenAI',
    'Open Router',
    'Gemini',
    'Anthropic',
    'xAI',
  ];

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _selectedLanguage);
    await prefs.setString('default_provider', _selectedProvider);
    
    // Save API key and Model if provided
    if (_selectedProvider != 'Groq (System)') {
      if (_apiKeyController.text.isNotEmpty) {
        await prefs.setString('api_key_$_selectedProvider', _apiKeyController.text);
      }
      if (_modelController.text.isNotEmpty) {
        await prefs.setString('model_$_selectedProvider', _modelController.text);
      }
    }

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
        title: const Text('Confirm Navigation'),
        content: const Text(
          'System defaults might not always be perfectly accurate for all use cases. Are you sure you want to continue with current settings?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
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
            child: const Text('Yes, Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Select Language';
    String subTitle = 'Choose your preferred language for the interface and AI responses.';
    
    if (_currentStep == 1) {
      title = 'Select Provider';
      subTitle = 'Select your AI engine provider. You can configure API keys later.';
    } else if (_currentStep == 2) {
      title = 'Permissions';
      subTitle = 'Grant permissions and optimize for a better experience.';
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
              const SizedBox(height: 48),
              Expanded(
                child: _buildCurrentStepView(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('BACK', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    const SizedBox.shrink(),
                  
                  if (_currentStep < 2)
                    ElevatedButton(
                      onPressed: () => setState(() => _currentStep++),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 50),
                      ),
                      child: const Text('NEXT'),
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: _showSkipConfirmation,
                          child: const Text(
                            'SKIP',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _completeSetup,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 50),
                          ),
                          child: const Text('FINISH'),
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
      case 0: return _buildLanguageSelection();
      case 1: return _buildProviderSelection();
      case 2: return _buildPermissionsView();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildPermissionsView() {
    return Column(
      children: [
        _buildPermissionItem(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
          desc: 'To remind you about student birthdays and messages.',
        ),
        const SizedBox(height: 16),
        _buildPermissionItem(
          icon: Icons.photo_library_outlined,
          title: 'Storage & Photos',
          desc: 'Necessary for saving story images to your gallery.',
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _requestPermissions,
          icon: const Icon(Icons.security),
          label: const Text('GRANT PERMISSIONS'),
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
          child: const Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Recommended: Please disable battery optimization for BlueTalk to ensure notifications arrive on time.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return ListView.builder(
      itemCount: _languages.length,
      itemBuilder: (context, index) {
        final lang = _languages[index];
        final isSelected = _selectedLanguage == lang['name'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => _selectedLanguage = lang['name']!),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF135ACF).withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF135ACF) : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang['name']!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF135ACF) : Colors.black87,
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
      },
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _providers.length,
            itemBuilder: (context, index) {
              final provider = _providers[index];
              final isSelected = _selectedProvider == provider;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedProvider = provider),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF135ACF).withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF135ACF) : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF135ACF) : Colors.black87,
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
            },
          ),
        ),
        if (_selectedProvider != 'Groq (System)')
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter API Key for $_selectedProvider',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    hintText: 'Enter specific model (Optional)',
                    prefixIcon: const Icon(Icons.model_training_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
