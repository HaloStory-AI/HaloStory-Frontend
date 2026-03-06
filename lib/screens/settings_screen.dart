import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _providers = ['System', 'BYOK', 'BYOM'];

  String _selectedProvider = 'System';
  
  // BYOK Controllers
  final TextEditingController _byokApiKeyController = TextEditingController();
  final TextEditingController _byokModelController = TextEditingController();
  final TextEditingController _byokBaseUrlController = TextEditingController();
  
  // BYOM Controllers
  final TextEditingController _byomEndpointController = TextEditingController();
  final TextEditingController _byomModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _byokApiKeyController.dispose();
    _byokModelController.dispose();
    _byokBaseUrlController.dispose();
    _byomEndpointController.dispose();
    _byomModelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvider = prefs.getString('default_provider') ?? 'System';
      
      _byokApiKeyController.text = prefs.getString('byok_api_key') ?? '';
      _byokModelController.text = prefs.getString('byok_model') ?? 'gpt-3.5-turbo';
      _byokBaseUrlController.text = prefs.getString('byok_base_url') ?? 'https://api.openai.com/v1/chat/completions';
      
      _byomEndpointController.text = prefs.getString('byom_endpoint') ?? 'http://localhost:11434/v1/chat/completions';
      _byomModelController.text = prefs.getString('byom_model') ?? 'llama3';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_provider', _selectedProvider);
    
    await prefs.setString('byok_api_key', _byokApiKeyController.text);
    await prefs.setString('byok_model', _byokModelController.text);
    await prefs.setString('byok_base_url', _byokBaseUrlController.text);
    
    await prefs.setString('byom_endpoint', _byomEndpointController.text);
    await prefs.setString('byom_model', _byomModelController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan berhasil disimpan!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF135ACF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF135ACF),
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'Umum'),
            Tab(icon: Icon(Icons.api), text: 'Mesin AI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildProvidersTab(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveSettings,
          child: const Text('Simpan Semua Perubahan'),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Mesin AI Aktif',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
        ),
        const SizedBox(height: 8),
        const Text('Pilih mode yang ingin digunakan untuk percakapan AI.'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedProvider,
              items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedProvider = v!),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Tentang Mode AI',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildModeInfo('System', 'Menggunakan model yang sudah dikonfigurasi otomatis dengan fallback. Disarankan untuk kemudahan.'),
        _buildModeInfo('BYOK', 'Gunakan API Key sendiri. Mendukung API OpenAI (OpenAI, Groq, OpenRouter, dll).'),
        _buildModeInfo('BYOM', 'Gunakan model lokal. Hubungkan ke mesin lokal seperti Ollama, LM Studio, atau LocalAI.'),
      ],
    );
  }

  Widget _buildModeInfo(String title, String desc) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 12),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
           Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
         ],
       ),
     );
  }

  Widget _buildProvidersTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Konfigurasi Mesin',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
        ),
        const SizedBox(height: 20),
        
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _providers.map((p) {
              final isSelected = _selectedProvider == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedProvider = p);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 30),
        
        if (_selectedProvider == 'BYOK') ...[
          const Text('Konfigurasi BYOK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _byokApiKeyController,
            label: 'API Key',
            hint: 'sk-xxxx...',
            obscure: true,
            icon: Icons.vpn_key,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byokModelController,
            label: 'Nama Model',
            hint: 'cth: gpt-4o, llama-3-70b',
            icon: Icons.model_training,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byokBaseUrlController,
            label: 'URL Dasar',
            hint: 'https://api.openai.com/v1/chat/completions',
            icon: Icons.link,
          ),
        ] else if (_selectedProvider == 'BYOM') ...[
          const Text('Konfigurasi BYOM (Lokal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _byomEndpointController,
            label: 'Endpoint Lokal',
            hint: 'http://localhost:11434/v1/chat/completions',
            icon: Icons.computer,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byomModelController,
            label: 'Nama Model Lokal',
            hint: 'cth: llama3, mistral',
            icon: Icons.model_training,
          ),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Mode System menggunakan model yang dioptimalkan dengan fallback otomatis. Tidak perlu konfigurasi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
