import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'splash_screen.dart';
import '../constants.dart';
import '../services/localization_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/local_chat_service.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  final List<String> _providers = ['System', 'BYOK', 'BYOM'];

  final Map<String, String> _byokProvidersList = {
    'gemini': 'Google Gemini',
    'claude': 'Anthropic Claude',
    'deepseek': 'DeepSeek',
    'groq': 'Groq',
    'mistral': 'Mistral AI',
    'openrouter': 'OpenRouter',
    'arli': 'Arli AI',
    'mancer': 'Mancer',
    'featherless': 'Featherless AI',
    'chutes': 'Chutes AI',
    'nanogpt': 'NanoGPT',
    'venus': 'Venus AI',
    'zai': 'Z.ai',
    'novel': 'NovelAI',
    'horde': 'AI Horde',
    'openai-compatible': 'Custom OpenAI Compatible',
  };

  String _selectedProvider = 'System';
  String _byokProvider = 'openrouter';
  String _currentLanguage = 'id';
  bool _isLanguageChanged = false;
  bool _aiReasoningEnabled = false;
  bool _amoledDarkEnabled = false;

  final TextEditingController _byokApiKeyController = TextEditingController();
  final TextEditingController _byokModelController = TextEditingController();
  final TextEditingController _byokBaseUrlController = TextEditingController();

  final TextEditingController _byomEndpointController = TextEditingController();
  final TextEditingController _byomModelController = TextEditingController();
  final TextEditingController _byomApiKeyController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentLanguage = LocalizationService().currentLocale;
    _amoledDarkEnabled = ThemeService().isAmoledDark;
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
      _selectedProvider = AIService.normalizeProvider(
        prefs.getString('default_provider'),
      );
      _byokProvider = prefs.getString('byok_provider') ?? 'openrouter';
      _aiReasoningEnabled = prefs.getBool('ai_reasoning_enabled') ?? false;
      _amoledDarkEnabled = ThemeService().isAmoledDark;

      _byokApiKeyController.text = prefs.getString('byok_api_key') ?? '';
      _byokModelController.text = prefs.getString('byok_model') ?? '';
      _byokBaseUrlController.text = prefs.getString('byok_base_url') ?? '';

      _byomEndpointController.text = prefs.getString('byom_endpoint') ?? '';
      _byomModelController.text = prefs.getString('byom_model') ?? '';
      _byomApiKeyController.text = prefs.getString('byom_api_key') ?? '';

      _aiTempController.text = (prefs.getDouble('ai_temp') ?? 0.7).toString();
      _aiResponseLengthController.text =
          (prefs.getInt('ai_response_length') ?? 1024).toString();
      _aiMaxTokenController.text = (prefs.getInt('ai_max_token') ?? 1024)
          .toString();
      _aiTopPController.text = (prefs.getDouble('ai_top_p') ?? 0.9).toString();
      _aiTopAController.text = (prefs.getDouble('ai_top_a') ?? 0.0).toString();
      _aiTopKController.text = (prefs.getInt('ai_top_k') ?? 40).toString();
      _aiRepPenaltyController.text = (prefs.getDouble('ai_rep_penalty') ?? 1.1)
          .toString();
      _aiContextLimitController.text =
          (prefs.getInt('ai_context_limit') ?? 1500).toString();
      _aiLtmBudgetController.text = (prefs.getInt('ai_ltm_budget') ?? 300)
          .toString();
      _aiEmbedBudgetController.text = (prefs.getInt('ai_embed_budget') ?? 200)
          .toString();
      _aiHistoryDepthController.text = (prefs.getInt('ai_history_depth') ?? 5)
          .toString();
    });
  }

  Future<void> _backupData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('settings_backup_title')),
        content: Text(tr('settings_backup_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Backup'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> settingsData = {};

    for (String key in allKeys) {
      if (key.startsWith('ai_') ||
          key.startsWith('byok_') ||
          key.startsWith('byom_') ||
          key == 'default_provider' ||
          key == 'app_language' ||
          key == 'app_theme_mode') {
        settingsData[key] = prefs.get(key);
      }
    }

    final Map<String, dynamic> chatData = {};
    final Map<String, dynamic> summaryData = {};
    final chatService = LocalChatService();
    final metadata = await chatService.getAllChatMetadata();
    for (var meta in metadata) {
      final id = meta['id'].toString();
      final messages = await chatService.loadChat(id);
      final summaries = await chatService.loadSummaries(id);

      chatData[id] = messages;
      summaryData[id] = summaries.map((k, v) => MapEntry(k.toString(), v));
    }

    final Map<String, dynamic> fullPayload = {
      'settings': settingsData,
      'chats': chatData,
      'summaries': summaryData,
      'exported_at': DateTime.now().toIso8601String(),
    };

    final String plainJson = jsonEncode(fullPayload);
    final String encryptedJson = SecurityService.encryptData(plainJson);

    final token = await _authService.getToken();
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiUrl}/user/backup'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': encryptedJson}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings_backup_success')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _restoreData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('settings_backup_title')),
        content: Text(tr('settings_restore_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final token = await _authService.getToken();
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/user/restore'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        if (responseBody['success'] == true && responseBody['data'] != null) {
          final String encryptedData = responseBody['data'];

          final String plainJson = SecurityService.decryptData(encryptedData);
          final Map<String, dynamic> fullPayload = jsonDecode(plainJson);

          if (fullPayload.containsKey('settings')) {
            final Map<String, dynamic> settings = fullPayload['settings'];
            final prefs = await SharedPreferences.getInstance();
            for (var entry in settings.entries) {
              final k = entry.key;
              final v = entry.value;
              if (v is double) {
                await prefs.setDouble(k, v);
              } else if (v is int) {
                await prefs.setInt(k, v);
              } else if (v is String) {
                await prefs.setString(k, v);
              } else if (v is bool) {
                await prefs.setBool(k, v);
              }
            }
          }

          if (fullPayload.containsKey('chats')) {
            final Map<String, dynamic> chats = fullPayload['chats'];
            final chatService = LocalChatService();
            for (var entry in chats.entries) {
              final id = entry.key;
              final messages = List<Map<String, dynamic>>.from(entry.value);
              await chatService.saveChat(id, messages);
            }
          }

          if (fullPayload.containsKey('summaries')) {
            final Map<String, dynamic> summaries = fullPayload['summaries'];
            final chatService = LocalChatService();
            for (var entry in summaries.entries) {
              final id = entry.key;
              final summaryMap = Map<String, dynamic>.from(entry.value);
              final properSummaries = summaryMap.map(
                (k, v) => MapEntry(int.parse(k), v.toString()),
              );
              await chatService.saveSummaries(id, properSummaries);
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('settings_restore_success')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SplashScreen()),
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings_restore_fail')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showModelSearchBottomSheet() {
    final apiKey = _byokApiKeyController.text;
    final prov = _byokProvider;
    final baseUrl = _byokBaseUrlController.text;

    if (apiKey.isEmpty &&
        prov != 'horde' &&
        prov != 'arli' &&
        prov != 'mancer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key required to fetch models for this provider'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                if (prov == 'chutes' || prov == 'openai-compatible')
                  'base_url': baseUrl,
              };

              _authService.getToken().then((token) {
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
                        } else if (data is Map && data.containsKey('models')) {
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
                                Clipboard.setData(ClipboardData(text: model));
                                setState(() {
                                  _byokModelController.text = model;
                                });
                                Navigator.pop(modalContext);
                                ScaffoldMessenger.of(this.context).showSnackBar(
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

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await ThemeService().setAmoledDark(_amoledDarkEnabled);
    await prefs.setString('default_provider', _selectedProvider);
    await prefs.setString('byok_provider', _byokProvider);
    await prefs.setBool('ai_reasoning_enabled', _aiReasoningEnabled);

    await prefs.setString('byok_api_key', _byokApiKeyController.text);
    await prefs.setString('byok_model', _byokModelController.text);
    await prefs.setString('byok_base_url', _byokBaseUrlController.text);

    await prefs.setString('byom_endpoint', _byomEndpointController.text);
    await prefs.setString('byom_model', _byomModelController.text);
    await prefs.setString('byom_api_key', _byomApiKeyController.text);

    final syncPayload = {
      'default_provider': _selectedProvider,
      'byok_provider': _byokProvider,
      'ai_reasoning_enabled': _aiReasoningEnabled,
      'ai_temp': double.tryParse(_aiTempController.text) ?? 0.7,
      'ai_response_length':
          int.tryParse(_aiResponseLengthController.text) ?? 1024,
      'ai_max_token': int.tryParse(_aiMaxTokenController.text) ?? 1024,
      'ai_top_p': double.tryParse(_aiTopPController.text) ?? 0.9,
      'ai_top_a': double.tryParse(_aiTopAController.text) ?? 0.0,
      'ai_top_k': int.tryParse(_aiTopKController.text) ?? 40,
      'ai_rep_penalty': double.tryParse(_aiRepPenaltyController.text) ?? 1.1,
      'ai_context_limit': int.tryParse(_aiContextLimitController.text) ?? 1500,
      'ai_ltm_budget': int.tryParse(_aiLtmBudgetController.text) ?? 300,
      'ai_embed_budget': int.tryParse(_aiEmbedBudgetController.text) ?? 200,
      'ai_history_depth': int.tryParse(_aiHistoryDepthController.text) ?? 5,
    };

    for (var entry in syncPayload.entries) {
      final k = entry.key;
      final v = entry.value;
      if (v is double) {
        await prefs.setDouble(k, v);
      } else if (v is int) {
        await prefs.setInt(k, v);
      } else if (v is String) {
        await prefs.setString(k, v);
      } else if (v is bool) {
        await prefs.setBool(k, v);
      }
    }

    if (!mounted) return;

    if (_isLanguageChanged) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const lightBlueTone = Color(0xFF8DC5FF);
    final accentColor = isDark ? colorScheme.primary : lightBlueTone;
    final appBarBackground = isDark
        ? theme.scaffoldBackgroundColor
        : lightBlueTone;
    final tabLabelColor = isDark ? colorScheme.primary : Colors.white;
    final tabUnselectedLabelColor = isDark
        ? colorScheme.onSurfaceVariant
        : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? colorScheme.onSurface : Colors.white,
        ),
        title: Text(
          tr('settings_title'),
          style: TextStyle(
            color: isDark ? colorScheme.onSurface : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: tabLabelColor,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelColor: tabUnselectedLabelColor,
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: tabLabelColor,
          indicatorWeight: 3,
          tabs: [
            Tab(icon: const Icon(Icons.tune), text: tr('settings_tab_general')),
            Tab(icon: const Icon(Icons.api), text: tr('settings_tab_ai')),
            Tab(
              icon: const Icon(Icons.cloud_sync),
              text: tr('settings_tab_backup'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGeneralTab(), _buildProvidersTab(), _buildBackupTab()],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
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

  Widget _buildGeneralTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardLikeColor = isDark
        ? colorScheme.surface
        : colorScheme.surfaceContainer;
    final Color textColor = colorScheme.onSurface;
    final List<BoxShadow> cardShadow = isDark
        ? const []
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
            ),
          ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('settings_language'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cardLikeColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: cardShadow,
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
        const SizedBox(height: 24),
        Text(
          tr('settings_theme'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardLikeColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: cardShadow,
          ),
          child: SwitchListTile(
            title: Text(
              tr('settings_theme_amoled_title'),
              style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
            ),
            subtitle: Text(
              tr('settings_theme_amoled_desc'),
              style: TextStyle(color: textColor.withValues(alpha: 0.7)),
            ),
            value: _amoledDarkEnabled,
            activeThumbColor: colorScheme.primary,
            onChanged: (bool value) {
              setState(() {
                _amoledDarkEnabled = value;
              });
              ThemeService().setAmoledDark(value);
            },
          ),
        ),
        const SizedBox(height: 30),
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
            color: cardLikeColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: cardShadow,
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
        SwitchListTile(
          title: Text(
            'Enable AI Reasoning',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          subtitle: Text(
            'Allow the AI to use extended thinking/reasoning blocks before replying (Requires supported models like Claude 3.7 or DeepSeek-R1).',
            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          ),
          value: _aiReasoningEnabled,
          activeThumbColor: colorScheme.primary,
          onChanged: (bool value) {
            setState(() {
              _aiReasoningEnabled = value;
            });
          },
        ),
        const SizedBox(height: 10),
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
        _buildModeInfo('BYOM', tr('settings_mode_byom_desc')),
      ],
    );
  }

  Widget _buildBackupTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          tr('settings_backup_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('settings_backup_desc'),
          style: TextStyle(color: textColor.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: isDark
              ? colorScheme.surface
              : colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _backupData,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(tr('settings_btn_backup')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _restoreData,
                    icon: const Icon(Icons.cloud_download),
                    label: Text(tr('settings_btn_restore')),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.primary),
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  Widget _buildProvidersTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr('settings_engine_config'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
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
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainer,
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
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
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.outline
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _byokProvider,
                items: _byokProvidersList.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
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
                    minimumSize: const Size(
                      100,
                      52,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_byokProvider == 'openai-compatible' ||
              _byokProvider == 'chutes') ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _byokBaseUrlController,
              label: tr('settings_base_url'),
              hint: 'https://api.example.com/v1',
              icon: Icons.link,
            ),
          ],
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
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),

        const SizedBox(height: 30),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 10),

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
                    _aiTempController,
                    tr('settings_temp'),
                    '0.7',
                  ),
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
                  _buildNumericField(
                    _aiTopPController,
                    tr('settings_top_p'),
                    '0.9',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiTopAController,
                    tr('settings_top_a'),
                    '0.0',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiTopKController,
                    tr('settings_top_k'),
                    '40',
                  ),
                  const SizedBox(height: 12),
                  _buildNumericField(
                    _aiRepPenaltyController,
                    tr('settings_rep_penalty'),
                    '1.1',
                  ),
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

  Widget _buildHelpLink() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse(
            'https://docs.my-bini.my.id/books/bluetalk/page/model-configuration',
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
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
    );
  }
}
