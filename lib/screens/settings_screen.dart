import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'splash_screen.dart';
import '../services/localization_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _providers = ['System', 'BYOK', 'BYOM'];

  String _selectedProvider = 'System';
  String _currentLanguage = 'id';
  bool _isLanguageChanged = false;

  // BYOK Controllers
  final TextEditingController _byokApiKeyController = TextEditingController();
  final TextEditingController _byokModelController = TextEditingController();
  final TextEditingController _byokBaseUrlController = TextEditingController();

  // BYOM Controllers
  final TextEditingController _byomEndpointController = TextEditingController();
  final TextEditingController _byomModelController = TextEditingController();
  final TextEditingController _byomApiKeyController = TextEditingController();

  // Advanced AI Controllers
  final TextEditingController _aiTempController = TextEditingController();
  final TextEditingController _aiResponseLengthController =
      TextEditingController();
  final TextEditingController _aiMaxTokenController = TextEditingController();
  final TextEditingController _aiTopPController = TextEditingController();
  final TextEditingController _aiTopAController = TextEditingController();
  final TextEditingController _aiTopKController = TextEditingController();
  final TextEditingController _aiRepPenaltyController =
      TextEditingController();
  final TextEditingController _aiContextLimitController =
      TextEditingController();
  final TextEditingController _aiLtmBudgetController = TextEditingController();
  final TextEditingController _aiEmbedBudgetController =
      TextEditingController();
  final TextEditingController _aiHistoryDepthController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentLanguage = LocalizationService().currentLocale;
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
    _byomApiKeyController.dispose();
    _aiTempController.dispose();
    _aiResponseLengthController.dispose();
    _aiMaxTokenController.dispose();
    _aiTopPController.dispose();
    _aiTopAController.dispose();
    _aiTopKController.dispose();
    _aiRepPenaltyController.dispose();
    _aiContextLimitController.dispose();
    _aiLtmBudgetController.dispose();
    _aiEmbedBudgetController.dispose();
    _aiHistoryDepthController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvider = prefs.getString('default_provider') ?? 'System';

      _byokApiKeyController.text = prefs.getString('byok_api_key') ?? '';
      _byokModelController.text = prefs.getString('byok_model') ?? '';
      _byokBaseUrlController.text = prefs.getString('byok_base_url') ?? '';

      _byomEndpointController.text = prefs.getString('byom_endpoint') ?? '';
      _byomModelController.text = prefs.getString('byom_model') ?? '';
      _byomApiKeyController.text = prefs.getString('byom_api_key') ?? '';

      _aiTempController.text = (prefs.getDouble('ai_temp') ?? 0.7).toString();
      _aiResponseLengthController.text =
          (prefs.getInt('ai_response_length') ?? 1024).toString();
      _aiMaxTokenController.text =
          (prefs.getInt('ai_max_token') ?? 1024).toString();
      _aiTopPController.text = (prefs.getDouble('ai_top_p') ?? 0.9).toString();
      _aiTopAController.text = (prefs.getDouble('ai_top_a') ?? 0.0).toString();
      _aiTopKController.text = (prefs.getInt('ai_top_k') ?? 40).toString();
      _aiRepPenaltyController.text =
          (prefs.getDouble('ai_rep_penalty') ?? 1.1).toString();
      _aiContextLimitController.text =
          (prefs.getInt('ai_context_limit') ?? 1500).toString();
      _aiLtmBudgetController.text =
          (prefs.getInt('ai_ltm_budget') ?? 300).toString();
      _aiEmbedBudgetController.text =
          (prefs.getInt('ai_embed_budget') ?? 200).toString();
      _aiHistoryDepthController.text =
          (prefs.getInt('ai_history_depth') ?? 5).toString();
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
    await prefs.setString('byom_api_key', _byomApiKeyController.text);

    await prefs.setDouble(
      'ai_temp',
      double.tryParse(_aiTempController.text) ?? 0.7,
    );
    await prefs.setInt(
      'ai_response_length',
      int.tryParse(_aiResponseLengthController.text) ?? 1024,
    );
    await prefs.setInt(
      'ai_max_token',
      int.tryParse(_aiMaxTokenController.text) ?? 1024,
    );
    await prefs.setDouble(
      'ai_top_p',
      double.tryParse(_aiTopPController.text) ?? 0.9,
    );
    await prefs.setDouble(
      'ai_top_a',
      double.tryParse(_aiTopAController.text) ?? 0.0,
    );
    await prefs.setInt(
      'ai_top_k',
      int.tryParse(_aiTopKController.text) ?? 40,
    );
    await prefs.setDouble(
      'ai_rep_penalty',
      double.tryParse(_aiRepPenaltyController.text) ?? 1.1,
    );
    await prefs.setInt(
      'ai_context_limit',
      int.tryParse(_aiContextLimitController.text) ?? 1500,
    );
    await prefs.setInt(
      'ai_ltm_budget',
      int.tryParse(_aiLtmBudgetController.text) ?? 300,
    );
    await prefs.setInt(
      'ai_embed_budget',
      int.tryParse(_aiEmbedBudgetController.text) ?? 200,
    );
    await prefs.setInt(
      'ai_history_depth',
      int.tryParse(_aiHistoryDepthController.text) ?? 5,
    );

    if (mounted) {
      if (_isLanguageChanged) {
        // Force restart to apply language change everywhere
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings_saved_success')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings_title')),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF135ACF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF135ACF),
          tabs: [
            Tab(icon: const Icon(Icons.tune), text: tr('settings_tab_general')),
            Tab(icon: const Icon(Icons.api), text: tr('settings_tab_ai')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGeneralTab(), _buildProvidersTab()],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveSettings,
          child: Text(tr('settings_save_btn')),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('settings_language'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF135ACF),
          ),
        ),
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
        const SizedBox(height: 30),
        Text(
          tr('settings_ai_active'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF135ACF),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('settings_ai_active_desc')),
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
              items: _providers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedProvider = v!),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          tr('settings_about_mode'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildModeInfo('System', tr('settings_mode_system_desc')),
        _buildModeInfo('BYOK', tr('settings_mode_byok_desc')),
        _buildModeInfo('BYOM', tr('settings_mode_byom_desc')),
      ],
    );
  }

  Widget _buildModeInfo(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProvidersTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('settings_engine_config'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF135ACF),
          ),
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
          _buildTextField(
            controller: _byokApiKeyController,
            label: tr('settings_api_key'),
            hint: 'sk-xxxx...',
            obscure: true,
            icon: Icons.vpn_key,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byokModelController,
            label: tr('settings_model_name'),
            hint: tr('settings_model_name_hint'),
            icon: Icons.model_training,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byokBaseUrlController,
            label: tr('settings_base_url'),
            hint: 'https://api.openai.com/v1/chat/completions',
            icon: Icons.link,
          ),
        ] else if (_selectedProvider == 'BYOM') ...[
          _buildTextField(
            controller: _byomEndpointController,
            label: tr('settings_local_endpoint'),
            hint: 'http://localhost:11434/v1/chat/completions',
            icon: Icons.computer,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byomModelController,
            label: tr('settings_local_model_name'),
            hint: tr('settings_local_model_name_hint'),
            icon: Icons.model_training,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _byomApiKeyController,
            label: tr('settings_api_key_optional'),
            hint: 'cth: sk-xxxx...',
            obscure: true,
            icon: Icons.vpn_key,
          ),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                tr('settings_system_mode_info'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),

        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 10),

        ExpansionTile(
          title: Text(
            tr('settings_advanced_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: const Icon(Icons.settings_suggest, color: Color(0xFF135ACF)),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    tr('settings_gen_params'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNumericField(_aiTempController, tr('settings_temp'), '0.7'),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiResponseLengthController,
                    tr('settings_response_length'),
                    '1024',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiMaxTokenController,
                    tr('settings_max_token'),
                    '1024',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(_aiTopPController, tr('settings_top_p'), '0.9'),
                  const SizedBox(height: 12),
                  _buildNumericField(_aiTopAController, tr('settings_top_a'), '0.0'),
                  const SizedBox(height: 12),
                  _buildNumericField(_aiTopKController, tr('settings_top_k'), '40'),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiRepPenaltyController,
                    tr('settings_rep_penalty'),
                    '1.1',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('settings_memory_params'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNumericField(
                    _aiContextLimitController,
                    tr('settings_context_limit'),
                    '1500',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiLtmBudgetController,
                    tr('settings_ltm_budget'),
                    '300',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiEmbedBudgetController,
                    tr('settings_embed_budget'),
                    '200',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiHistoryDepthController,
                    tr('settings_history_depth'),
                    '5',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildHelpLink(),
      ],
    );
  }

  Widget _buildNumericField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
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
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpLink() {
    return Center(
      child: TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(
            'http://docs.my-bini.my.id/books/bluetalk-advance/page/set-up-byok-and-byom',
          ),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.help_outline, size: 18),
        label: Text(
          tr('settings_help_docs'),
          style: const TextStyle(
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF135ACF)),
      ),
    );
  }
}
