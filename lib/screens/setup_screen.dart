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
  String _selectedProvider = 'System';
  int _currentStep = 0;

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();

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
    {'name': 'Indonesian', 'code': 'id'},
    {'name': 'English', 'code': 'en'},
    {'name': 'Chinese', 'code': 'zh'},
    {'name': 'Japanese', 'code': 'ja'},
  ];

  final List<String> _providers = ['System', 'BYOK', 'BYOM'];

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _selectedLanguage);
    await prefs.setString('default_provider', _selectedProvider);
    
    if (_selectedProvider == 'BYOK') {
      await prefs.setString('byok_api_key', _apiKeyController.text);
      await prefs.setString('byok_model', _modelController.text.isEmpty ? 'gpt-3.5-turbo' : _modelController.text);
      await prefs.setString('byok_base_url', _baseUrlController.text.isEmpty ? 'https://api.openai.com/v1/chat/completions' : _baseUrlController.text);
    } else if (_selectedProvider == 'BYOM') {
      await prefs.setString('byom_endpoint', _baseUrlController.text.isEmpty ? 'http://localhost:11434/v1/chat/completions' : _baseUrlController.text);
      await prefs.setString('byom_model', _modelController.text.isEmpty ? 'llama3' : _modelController.text);
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
        title: const Text('Konfirmasi Pengaturan'),
        content: const Text(
          'Pengaturan default mungkin tidak selalu cocok untuk semua orang. Yakin ingin lanjut dengan pengaturan ini?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
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
            child: const Text('Ya, Lanjut'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Pilih Bahasa';
    String subTitle = 'Pilih bahasa yang kamu sukai untuk tampilan dan respon AI.';
    
    if (_currentStep == 1) {
      title = 'Pilih Mesin AI';
      subTitle = 'Pilih cara kamu terhubung ke AI. Mode System adalah yang termudah.';
    } else if (_currentStep == 2) {
      title = 'Izin Aplikasi';
      subTitle = 'Berikan izin yang diperlukan untuk pengalaman yang lebih baik.';
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
                      child: const Text('KEMBALI', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    const SizedBox.shrink(),
                  
                  if (_currentStep < 2)
                    ElevatedButton(
                      onPressed: () => setState(() => _currentStep++),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(120, 50),
                      ),
                      child: const Text('LANJUT'),
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: _showSkipConfirmation,
                          child: const Text(
                            'LEWATI',
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _completeSetup,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 50),
                          ),
                          child: const Text('SELESAI'),
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
          title: 'Notifikasi',
          desc: 'Untuk mengingatkanmu tentang ulang tahun murid dan pesan baru.',
        ),
        const SizedBox(height: 16),
        _buildPermissionItem(
          icon: Icons.photo_library_outlined,
          title: 'Penyimpanan & Foto',
          desc: 'Diperlukan untuk menyimpan gambar status ke galeri kamu.',
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _requestPermissions,
          icon: const Icon(Icons.security),
          label: const Text('BERIKAN IZIN'),
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
                  'Disarankan: Matikan optimasi baterai untuk BlueTalk agar notifikasi tidak telat.',
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
    return Column(
      children: _languages.map((lang) {
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
      }).toList(),
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      children: [
        ..._providers.map((p) {
          final isSelected = _selectedProvider == p;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selectedProvider = p),
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
                      p,
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
        }),
        if (_selectedProvider != 'System')
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                if (_selectedProvider == 'BYOK')
                  _buildSetupField(
                    controller: _apiKeyController,
                    hint: 'Masukkan API Key',
                    icon: Icons.vpn_key_outlined,
                    obscure: true,
                  ),
                const SizedBox(height: 12),
                _buildSetupField(
                  controller: _modelController,
                  hint: _selectedProvider == 'BYOK' ? 'Model (cth: gpt-4o)' : 'Model Lokal (cth: llama3)',
                  icon: Icons.model_training_outlined,
                ),
                const SizedBox(height: 12),
                _buildSetupField(
                  controller: _baseUrlController,
                  hint: _selectedProvider == 'BYOK' ? 'URL Dasar (Opsional)' : 'URL Endpoint Lokal',
                  icon: Icons.link_outlined,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSetupField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
