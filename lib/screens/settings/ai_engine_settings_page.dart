import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants.dart';
import '../../services/localization_service.dart';
import '../../services/auth_service.dart';

class AIEngineSettingsPage extends StatefulWidget {
  final bool isDesktop;

  const AIEngineSettingsPage({super.key, this.isDesktop = false});

  @override
  State<AIEngineSettingsPage> createState() => _AIEngineSettingsPageState();
}

class _AIEngineSettingsPageState extends State<AIEngineSettingsPage> {
  String _byokProvider = 'gemini';

  final Map<String, String> _byokProvidersList = {
    'gemini': 'Google Gemini',
    'claude': 'Anthropic Claude',
    'deepseek': 'DeepSeek',
    'mistral': 'Mistral AI',
    'openrouter': 'OpenRouter',
    'zai': 'Z.ai',
    'openai-compatible': 'Custom OpenAI Compatible',
  };

  final TextEditingController _byokApiKeyController = TextEditingController();
  final TextEditingController _byokModelController = TextEditingController();
  final TextEditingController _byokBaseUrlController = TextEditingController();
  final TextEditingController _aiTempController = TextEditingController();
  final TextEditingController _aiResponseLengthController =
      TextEditingController();
  final TextEditingController _aiMaxTokenController = TextEditingController();
  final TextEditingController _aiTopPController = TextEditingController();
  final TextEditingController _aiTopAController = TextEditingController();
  final TextEditingController _aiTopKController = TextEditingController();
  final TextEditingController _aiRepPenaltyController = TextEditingController();
  final TextEditingController _aiContextLimitController =
      TextEditingController();
  final TextEditingController _aiLtmBudgetController = TextEditingController();
  final TextEditingController _aiEmbedBudgetController =
      TextEditingController();
  final TextEditingController _aiHistoryDepthController =
      TextEditingController();
  bool _streamEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _byokApiKeyController.dispose();
    _byokModelController.dispose();
    _byokBaseUrlController.dispose();
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
    if (!mounted) return;
    setState(() {
      _byokProvider = prefs.getString('byok_provider') ?? 'openrouter';

      _byokApiKeyController.text = prefs.getString('byok_api_key') ?? '';
      _byokModelController.text = prefs.getString('byok_model') ?? '';
      _byokBaseUrlController.text = prefs.getString('byok_base_url') ?? '';

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
      _streamEnabled = prefs.getBool('ai_stream_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('byok_provider', _byokProvider);
    await prefs.setString('byok_api_key', _byokApiKeyController.text);
    await prefs.setString('byok_model', _byokModelController.text);
    await prefs.setString('byok_base_url', _byokBaseUrlController.text);
    await prefs.setBool('ai_stream_enabled', _streamEnabled);

    final syncPayload = {
      'ai_temp': double.tryParse(_aiTempController.text) ?? 0.7,
      'ai_response_length':
          int.tryParse(_aiResponseLengthController.text) ?? 1024,
      'ai_max_token': int.tryParse(_aiMaxTokenController.text) ?? 1024,
      'ai_top_p': double.tryParse(_aiTopPController.text) ?? 0.9,
      'ai_top_a': double.tryParse(_aiTopAController.text) ?? 0.0,
      'ai_top_k': int.tryParse(_aiTopKController.text) ?? 40,
      'ai_rep_penalty': double.tryParse(_aiRepPenaltyController.text) ?? 1.1,
      'ai_context_limit':
          int.tryParse(_aiContextLimitController.text) ?? 1500,
      'ai_ltm_budget': int.tryParse(_aiLtmBudgetController.text) ?? 300,
      'ai_embed_budget': int.tryParse(_aiEmbedBudgetController.text) ?? 200,
      'ai_history_depth':
          int.tryParse(_aiHistoryDepthController.text) ?? 5,
    };

    for (var entry in syncPayload.entries) {
      final k = entry.key;
      final v = entry.value;
      if (v is double) {
        await prefs.setDouble(k, v);
      } else if (v is int) {
        await prefs.setInt(k, v);
      }
    }

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

    return Scaffold(
      appBar: widget.isDesktop
          ? null
          : AppBar(
              title: Text(
                tr('settings_tab_ai'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Engine Config Title ──
            Text(
              tr('settings_engine_config'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildHelpLink(),
            const SizedBox(height: 12),
            // ── Response Mode (Stream vs Polling) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.outline
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.stream, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('settings_stream_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          tr('settings_stream_desc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _streamEnabled,
                    onChanged: (v) => setState(() => _streamEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._buildBYOKFields(),
            const SizedBox(height: 30),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 10),

            // ── Advanced Parameters ──
            ExpansionTile(
              title: Text(
                tr('settings_advanced_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: Icon(Icons.settings_suggest, color: colorScheme.primary),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        tr('settings_gen_params'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNumericField(
                        _aiTempController, tr('settings_temp'), '0.7'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiResponseLengthController, tr('settings_response_length'), '1024'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiMaxTokenController, tr('settings_max_token'), '1024'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiTopPController, tr('settings_top_p'), '0.9'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiTopAController, tr('settings_top_a'), '0.0'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiTopKController, tr('settings_top_k'), '40'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiRepPenaltyController, tr('settings_rep_penalty'), '1.1'),
                      const SizedBox(height: 24),
                      Text(
                        tr('settings_memory_params'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNumericField(
                        _aiContextLimitController, tr('settings_context_limit'), '1500'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiLtmBudgetController, tr('settings_ltm_budget'), '300'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiEmbedBudgetController, tr('settings_embed_budget'), '200'),
                      const SizedBox(height: 12),
                      _buildNumericField(
                        _aiHistoryDepthController, tr('settings_history_depth'), '5'),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
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

  List<Widget> _buildBYOKFields() {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      Text(
        'BYOK Provider Platform',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.outline
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _byokProvider,
            items: _byokProvidersList.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _byokProvider = v);
            },
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _byokApiKeyController,
        label: tr('settings_api_key'),
        hint: 'sk-xxxx...',
        obscure: true,
        icon: Icons.vpn_key,
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _buildTextField(
              controller: _byokModelController,
              label: tr('settings_model_name'),
              hint: tr('settings_model_name_hint'),
              icon: Icons.model_training,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _showModelSearchBottomSheet,
              icon: const Icon(Icons.cloud_download, size: 18),
              label: const Text('Fetch'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 52),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      if (_byokProvider == 'openai-compatible') ...[
        const SizedBox(height: 16),
        _buildTextField(
          controller: _byokBaseUrlController,
          label: tr('settings_base_url'),
          hint: 'https://api.example.com/v1',
          icon: Icons.link,
        ),
      ],
    ];
  }

  Future<void> _showModelSearchBottomSheet() async {
    final apiKey = _byokApiKeyController.text;
    final prov = _byokProvider;
    final baseUrl = _byokBaseUrlController.text;

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key required to fetch models for this provider'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authService = AuthService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        bool isFetching = true;
        List<String> fetched = [];
        String errorMessage = '';

        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter setModalState) {
            if (isFetching && fetched.isEmpty && errorMessage.isEmpty) {
              final requestBody = {
                'api_key': apiKey.isEmpty ? 'guest' : apiKey,
                'provider': prov,
                if (prov == 'openai-compatible')
                  'base_url': baseUrl,
              };

              authService.getToken().then((token) {
                http
                    .post(
                      Uri.parse('${AppConstants.apiUrl}/byok/models'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                        if (token != null) 'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode(requestBody),
                    )
                    .then((res) {
                      if (res.statusCode == 200) {
                        final data = jsonDecode(res.body);
                        List<dynamic> modelList = [];
                        if (data is List) {
                          modelList = data;
                        } else if (data is Map &&
                            data.containsKey('models')) {
                          modelList = data['models'];
                        }

                        setModalState(() {
                          fetched = modelList
                              .map((e) => e['id'].toString())
                              .toList();
                          isFetching = false;
                        });
                      } else {
                        setModalState(() {
                          errorMessage = 'Failed to fetch: ${res.body}';
                          isFetching = false;
                        });
                      }
                    })
                    .catchError((e) {
                      setModalState(() {
                        errorMessage = 'Error: $e';
                        isFetching = false;
                      });
                    });
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(modalContext).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Models ($prov)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isFetching)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (errorMessage.isNotEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else if (fetched.isEmpty)
                      const Expanded(
                        child: Center(child: Text('No models found.')),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: fetched.length,
                          itemBuilder: (context, index) {
                            final model = fetched[index];
                            return ListTile(
                              title: Text(model),
                              trailing: const Icon(Icons.copy, size: 16),
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: model));
                                setState(() {
                                  _byokModelController.text = model;
                                });
                                Navigator.pop(modalContext);
                                ScaffoldMessenger.of(this.context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Model "$model" tersalin ke clipboard!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHelpLink() {
    final colorScheme = Theme.of(context).colorScheme;
    const String helpUrl = 'https://s.my-bini.my.id/byok';

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () =>
            launchUrl(Uri.parse(helpUrl), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.help_outline, size: 18),
        label: Text(
          tr('settings_help_docs'),
          style: const TextStyle(
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildNumericField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: isDark
                    ? colorScheme.surface
                    : colorScheme.surfaceContainer,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark
                ? colorScheme.surface
                : colorScheme.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
