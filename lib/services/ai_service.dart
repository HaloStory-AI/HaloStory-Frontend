import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';

class AIService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> sendMessage({
    required String provider,
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    final prefs = await SharedPreferences.getInstance();
    
    // Get user-provided API key if not system
    String? userApiKey;
    if (provider != 'Groq (System)') {
      userApiKey = prefs.getString('api_key_$provider');
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/ai/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          if (userApiKey != null && userApiKey.isNotEmpty) 'X-AI-API-Key': userApiKey,
        },
        body: jsonEncode({
          'provider': provider,
          'model': model,
          'messages': messages,
          // max_tokens is handled by backend default or passed here
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('DEBUG: AI Request Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DEBUG: AIService Error: $e');
    }
    return null;
  }
}
