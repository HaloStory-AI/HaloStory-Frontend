import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'localization_service.dart';

class AIService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> sendMessage({
    required String provider, // 'System', 'BYOK', 'BYOM'
    required List<Map<String, String>> messages,
    String? botId,
    String? language,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final actualLanguage = language ?? LocalizationService().currentLanguageName;
    final prefs = await SharedPreferences.getInstance();

    // Normalize provider for legacy support if needed
    String mode = provider;
    if (provider.contains('Groq') ||
        provider == 'OpenAI' ||
        provider == 'Gemini') {
      mode = 'System'; // Fallback for old selections
    }

    try {
      if (mode == 'System') {
        return await _sendSystemMessage(token, messages, botId, actualLanguage);
      } else if (mode == 'BYOK') {
        final apiKey = prefs.getString('byok_api_key') ?? '';
        final model = prefs.getString('byok_model') ?? 'gpt-3.5-turbo';
        final baseUrl =
            prefs.getString('byok_base_url') ??
            'https://api.openai.com/v1/chat/completions';
        return await _sendByokMessage(
          token,
          messages,
          botId,
          actualLanguage,
          apiKey,
          model,
          baseUrl,
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
        );
      }
    } catch (e) {
      print('DEBUG: AIService Error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _sendSystemMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    String? language,
  ) async {
    final response = await http.post(
      Uri.parse(AppConstants.chatSystemUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'messages': messages,
        'bot_id': botId,
        'language': language,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>?> _sendByokMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    String? language,
    String apiKey,
    String model,
    String baseUrl,
  ) async {
    final response = await http.post(
      Uri.parse(AppConstants.chatByokUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'messages': messages,
        'bot_id': botId,
        'language': language,
        'api_key': apiKey,
        'model': model,
        'base_url': baseUrl,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>?> _sendByomMessage(
    String token,
    List<Map<String, String>> messages,
    String? botId,
    String? language,
    String endpoint,
    String model,
    String apiKey,
  ) async {
    // 1. Fetch system prompt from backend
    final promptResponse = await http.get(
      Uri.parse('${AppConstants.byomPromptUrl}/$botId?language=$language'),
      headers: {'Authorization': 'Bearer $token'},
    );

    String systemPrompt = "";
    if (promptResponse.statusCode == 200) {
      systemPrompt = jsonDecode(promptResponse.body)['system_prompt'] ?? "";
    }

    // 2. Format messages for local model
    List<Map<String, String>> localMessages = List.from(messages);
    bool hasSystem = localMessages.any((m) => m['role'] == 'system');
    if (!hasSystem && systemPrompt.isNotEmpty) {
      localMessages.insert(0, {'role': 'system', 'content': systemPrompt});
    }

    // 3. Send directly to local/custom endpoint
    final headers = {'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'messages': localMessages,
        'max_tokens': 4000,
      }),
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }
}
