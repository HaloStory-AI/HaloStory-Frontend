import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';

class BotService {
  final AuthService _authService = AuthService();
  
  // Static cache to persist across service instances
  static List<Map<String, dynamic>>? _cachedBots;
  static DateTime? _lastBotsFetch;

  Future<List<Map<String, dynamic>>> getBots({bool forceRefresh = false}) async {
    final now = DateTime.now();
    bool isCacheExpired = _lastBotsFetch == null || 
                         now.difference(_lastBotsFetch!).inHours >= 3;

    if (!forceRefresh && !isCacheExpired && _cachedBots != null) {
      print("DEBUG: Returning cached bots");
      return _cachedBots!;
    }

    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _cachedBots = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        _lastBotsFetch = DateTime.now();
        print("DEBUG: Fetched bots from API");
        return _cachedBots!;
      }
    } catch (e) {
      print('DEBUG: BotService Error: $e');
    }
    return _cachedBots ?? [];
  }

  void clearCache() {
    _cachedBots = null;
    _lastBotsFetch = null;
  }
}
