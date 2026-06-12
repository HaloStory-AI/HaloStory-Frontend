import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'localization_service.dart';
import 'config_service.dart';

class AIService {
  static String normalizeProvider(String? p) {
    if (p == null) return 'System';
    if (p == 'System' || p == 'BYOK' || p == 'BYOM') return p;
    // Legacy mapping (Gemini, Groq, etc were once types of System AI in older versions)
    if (p.contains('Groq') || p == 'OpenAI' || p == 'Gemini') return 'System';
    // Any other specific platforms should be treated as BYOK if not found in category list
    return 'BYOK';
  }

  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> sendMessage({
    required String provider, // 'System', 'BYOK', 'BYOM'
    required List<Map<String, String>> messages,
    String? botId,
    List<String>? botIds,
    String? language,
    String? summary,
    bool bondDisabled = false,
    bool isGroup = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final actualLanguage =
        language ?? LocalizationService().currentLanguageName;
    final prefs = await SharedPreferences.getInstance();

    // Normalize provider for legacy support if needed
    final mode = normalizeProvider(provider);

    // Load Advanced Params
    final double temp = prefs.getDouble('ai_temp') ?? _getDefault(mode, 'temp');
    final int responseLength =
        prefs.getInt('ai_response_length') ?? _getDefault(mode, 'max_token');
    final int maxTokens =
        prefs.getInt('ai_max_token') ?? _getDefault(mode, 'max_token');
    final double topP =
        prefs.getDouble('ai_top_p') ?? _getDefault(mode, 'top_p');
    final double topA =
        prefs.getDouble('ai_top_a') ?? _getDefault(mode, 'top_a');
    final int topK = prefs.getInt('ai_top_k') ?? _getDefault(mode, 'top_k');
    final double repPenalty =
        prefs.getDouble('ai_rep_penalty') ?? _getDefault(mode, 'rep_penalty');

    final int contextLimit =
        prefs.getInt('ai_context_limit') ?? _getDefault(mode, 'context_limit');
    final int ltmBudget =
        prefs.getInt('ai_ltm_budget') ?? _getDefault(mode, 'ltm_budget');
    final int embedBudget =
        prefs.getInt('ai_embed_budget') ?? _getDefault(mode, 'embed_budget');
    final int historyDepth =
        prefs.getInt('ai_history_depth') ?? _getDefault(mode, 'history_depth');
    final bool reasoningEnabled =
        prefs.getBool('ai_reasoning_enabled') ?? false;

    final Map<String, dynamic> advancedParams = {
      'temperature': temp,
      'response_length': responseLength,
      'max_tokens': maxTokens,
      'top_p': topP,
      'top_a': topA,
      'top_k': topK,
      'repetition_penalty': repPenalty,
      'context_limit': contextLimit,
      'ltm_budget': ltmBudget,
      'embedding_budget': embedBudget,
      'history_depth': historyDepth,
      'reasoning': {'enabled': reasoningEnabled},
      'reasoning_enabled':
          reasoningEnabled, // Send as flat property for generic controllers
    };

    try {
      if (mode == 'System') {
        return await _sendSystemMessage(
          token,
          messages,
          botId,
          botIds,
          actualLanguage,
          advancedParams,
          summary,
          bondDisabled,
          isGroup,
        );
      } else if (mode == 'BYOK') {
        final apiKey = prefs.getString('byok_api_key') ?? '';
        final model = prefs.getString('byok_model') ?? 'openai/gpt-3.5-turbo';
        final byokProvider = prefs.getString('byok_provider') ?? 'openrouter';
        final baseUrl = prefs.getString('byok_base_url') ?? '';

        return await _sendByokMessage(
          token,
          messages,
          botId,
          botIds,
          actualLanguage,
          apiKey,
          model,
          byokProvider,
          baseUrl,
          advancedParams,
          summary,
          bondDisabled,
          isGroup,
        );
      } else if (mode == 'BYOM') {
        final endpoint =
            prefs.getString('byom_endpoint') ??
            'http://localhost:11434/v1/chat/completions';
        final model = prefs.getString('byom_model') ?? 'llama3';
        final apiKey = prefs.getString('byom_api_key') ?? '';
        return await _sendByomMessage(
          token,
          messages,
          botId,
          actualLanguage,
          endpoint,
          model,
          apiKey,
          advancedParams,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: AIService Error: $e');
      }
    }
    return null;
  }

  dynamic _getDefault(String mode, String param) {
    if (mode == 'System') {
      switch (param) {
        case 'temp':
          return 0.7;
        case 'max_token':
          return 1024;
        case 'top_p':
          return 0.9;
        case 'top_a':
          return 0.0;
        case 'top_k':
          return 40;
        case 'rep_penalty':
          return 1.1;
        case 'context_limit':
          return 1500;
        case 'ltm_budget':
          return 300;
        case 'embed_budget':
          return 200;
        case 'history_depth':
          return 5;
      }
    } else if (mode == 'BYOK') {
      switch (param) {
        case 'temp':
          return 0.7;
        case 'max_token':
          return 4096;
        case 'top_p':
          return 1.0;
        case 'top_a':
          return 0.0;
        case 'top_k':
          return 50;
        case 'rep_penalty':
          return 1.0;
        case 'context_limit':
          return 3000;
        case 'ltm_budget':
          return 1000;
        case 'embed_budget':
          return 500;
        case 'history_depth':
          return 15;
      }
    } else {
      // BYOM - Higher or No limit in UI, but we need defaults here
      switch (param) {
        case 'temp':
          return 0.7;
        case 'max_token':
          return 8192;
        case 'top_p':
          return 1.0;
        case 'top_a':
          return 0.0;
        case 'top_k':
          return 100;
        case 'rep_penalty':
          return 1.0;
        case 'context_limit':
          return 16000;
        case 'ltm_budget':
          return 4000;
        case 'embed_budget':
          return 2000;
        case 'history_depth':
          return 30;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _sendSystemMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    List<String>? botIds,
    String? language,
    Map<String, dynamic> advancedParams,
    String? summary,
    bool bondDisabled,
    bool isGroup,
  ) async {
    final response = await http.post(
      Uri.parse(AppConstants.chatSystemUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'messages': messages,
        'bot_id': botId,
        'bot_ids': botIds,
        'language': language,
        'summary': summary,
        if (bondDisabled) 'isdisabledbond': true,
        if (isGroup) 'is_group': true,
        ...advancedParams,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 503) {
      ConfigService.enterMaintenance();
    }

    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(response.body);
    } catch (_) {}

    return {
      'error': true,
      'status_code': response.statusCode,
      'raw_error': parsedBody ?? response.body,
      'message': 'Server returned ${response.statusCode}',
    };
  }

  Future<Map<String, dynamic>?> _sendByokMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    List<String>? botIds,
    String? language,
    String apiKey,
    String model,
    String byokProvider,
    String baseUrl,
    Map<String, dynamic> advancedParams,
    String? summary,
    bool bondDisabled,
    bool isGroup,
  ) async {
    // Dynamic endpoint for BYOK
    final endpoint = '${AppConstants.apiUrl}/byok/$byokProvider/chat';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'messages': messages,
        'bot_id': botId,
        'bot_ids': botIds,
        'language': language,
        'api_key': apiKey,
        'model': model,
        'base_url': baseUrl,
        'summary': summary,
        if (bondDisabled) 'isdisabledbond': true,
        if (isGroup) 'is_group': true,
        ...advancedParams,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 503) {
      ConfigService.enterMaintenance();
    }

    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(response.body);
    } catch (_) {}

    return {
      'error': true,
      'status_code': response.statusCode,
      'raw_error': parsedBody ?? response.body,
      'message': 'Server returned ${response.statusCode}',
    };
  }

  Future<Map<String, dynamic>?> _sendByomMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    String? language,
    String endpoint,
    String model,
    String apiKey,
    Map<String, dynamic> advancedParams,
  ) async {
    // 1. Fetch system prompt from backend
    final promptResponse = await http.get(
      Uri.parse('${AppConstants.byomPromptUrl}/$botId?language=$language'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    String systemPrompt = "";
    if (promptResponse.statusCode == 200) {
      systemPrompt = jsonDecode(promptResponse.body)['system_prompt'] ?? "";
    } else if (promptResponse.statusCode == 503) {
      ConfigService.enterMaintenance();
    }

    // 2. Format messages for local model
    List<Map<String, String>> localMessages = List.from(messages);
    bool hasSystem = localMessages.any((m) => m['role'] == 'system');
    if (!hasSystem && systemPrompt.isNotEmpty) {
      localMessages.insert(0, {'role': 'system', 'content': systemPrompt});
    }

    // 3. Send directly to local/custom endpoint
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': localMessages,
        ...advancedParams,
      }),
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 503) {
      ConfigService.enterMaintenance();
    }

    dynamic parsedBody;
    try {
      parsedBody = jsonDecode(response.body);
    } catch (_) {}

    return {
      'error': true,
      'status_code': response.statusCode,
      'raw_error': parsedBody ?? response.body,
      'message': 'Server returned ${response.statusCode}',
    };
  }

  Future<Map<String, dynamic>?> summarizeChat({
    required List<Map<String, String>> messages,
    String? botId,
    String? language,
    String? provider,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final actualLanguage =
        language ?? LocalizationService().currentLanguageName;
    final mode = normalizeProvider(provider);

    // BYOM: skip summarization, model lokal handle large context secara native
    if (mode == 'BYOM') return null;

    try {
      if (mode == 'BYOK') {
        final prefs = await SharedPreferences.getInstance();
        final apiKey = prefs.getString('byok_api_key') ?? '';
        final model = prefs.getString('byok_model') ?? '';
        final byokProvider = prefs.getString('byok_provider') ?? 'openrouter';
        final baseUrl = prefs.getString('byok_base_url') ?? '';
        final endpoint = '${AppConstants.apiUrl}/byok/$byokProvider/chat';

        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'messages': messages,
            'bot_id': botId,
            'language': actualLanguage,
            'api_key': apiKey,
            'model': model,
            'base_url': baseUrl,
            'is_summarize': true,
          }),
        );
        if (response.statusCode == 200) return jsonDecode(response.body);
        return null;
      }

      // Default: System
      final response = await http.post(
        Uri.parse(AppConstants.chatSummarizeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messages': messages,
          'bot_id': botId,
          'language': actualLanguage,
        }),
      );

      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: AIService summarizeChat Error: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkChatStatus(String uuid) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiUrl}/chat/status/$uuid'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 404) return {'status': 'not_found'};

      // Preserve error payload from non-200 responses (e.g. BYOK provider errors)
      try {
        final body = jsonDecode(response.body);
        return body is Map<String, dynamic> ? body : {'status': 'not_found'};
      } catch (_) {
        return {'status': 'not_found', 'raw_error': response.body};
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: AIService checkChatStatus Error: $e');
      }
    }
    return null;
  }
}
