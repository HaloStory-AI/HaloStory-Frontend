import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _providers = [
    'Groq (System)',
    'Groq (Self)',
    'OpenAI',
    'Open Router',
    'Gemini',
    'Anthropic',
    'xAI',
  ];

  String _selectedProvider = 'Groq (System)';
  final Map<String, TextEditingController> _apiKeyControllers = {};
  final Map<String, TextEditingController> _modelControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (var provider in _providers) {
      _apiKeyControllers[provider] = TextEditingController();
      _modelControllers[provider] = TextEditingController();
    }
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var c in _apiKeyControllers.values) {
      c.dispose();
    }
    for (var c in _modelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvider = prefs.getString('default_provider') ?? 'Groq (System)';
      for (var provider in _providers) {
        _apiKeyControllers[provider]!.text = prefs.getString('api_key_$provider') ?? '';
        _modelControllers[provider]!.text = prefs.getString('model_$provider') ?? '';
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_provider', _selectedProvider);
    for (var provider in _providers) {
      await prefs.setString('api_key_$provider', _apiKeyControllers[provider]!.text);
      await prefs.setString('model_$provider', _modelControllers[provider]!.text);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
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
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF135ACF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF135ACF),
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'General'),
            Tab(icon: Icon(Icons.api), text: 'Providers'),
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
          child: const Text('Save All Settings'),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Active AI Engine',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
        ),
        const SizedBox(height: 8),
        const Text('Select which provider to use as default.'),
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
      ],
    );
  }

  Widget _buildProvidersTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Manage API Keys & Models',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
        ),
        const SizedBox(height: 8),
        const Text('Select a provider to configure its API key and specific model.'),
        const SizedBox(height: 20),
        
        // Tab-like buttons for each provider to make it cleaner
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
        
        if (_selectedProvider != 'Groq (System)') ...[
          Text(
            'Configuring: $_selectedProvider',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _apiKeyControllers[_selectedProvider]!,
            label: 'API Key',
            hint: 'Paste your key here',
            obscure: true,
            icon: Icons.vpn_key,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _modelControllers[_selectedProvider]!,
            label: 'Default Model',
            hint: 'e.g. gpt-4, llama-3, etc.',
            icon: Icons.model_training,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              // Placeholder for future fetch model logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fetching models for $_selectedProvider...')),
              );
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Fetch Available Models'),
          ),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Groq (System) uses pre-configured settings. No API key required.',
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
