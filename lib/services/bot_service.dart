import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'config_service.dart';

class BotService {
  final AuthService _authService = AuthService();

  static const String _botsCacheKey = 'cached_bots_list';
  static const String _botsTimeKey = 'cached_bots_timestamp';

  // Static cache to persist across service instances in the same session
  static List<Map<String, dynamic>>? _cachedBots;
  static DateTime? _lastBotsFetch;
  static Future<List<Map<String, dynamic>>>? _pendingFetch;

  Future<List<Map<String, dynamic>>> getBots({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // 1. Memory Cache Check - FRESH (< 10 minutes)
    bool isMemCacheFresh =
        _lastBotsFetch != null &&
        now.difference(_lastBotsFetch!).inMinutes < 10;

    if (!forceRefresh && isMemCacheFresh && _cachedBots != null) {
      return _cachedBots!;
    }

    // 2. Persistent Cache Check (SharedPreferences)
    if (!forceRefresh) {
      final localJson = prefs.getString(_botsCacheKey);
      final localTimeStr = prefs.getString(_botsTimeKey);

      if (localJson != null && localTimeStr != null) {
        final localTime = DateTime.parse(localTimeStr);
        _cachedBots = List<Map<String, dynamic>>.from(jsonDecode(localJson));
        _lastBotsFetch = localTime;

        // If it's fresh (< 5 minutes), return and don't re-fetch
        if (now.difference(localTime).inMinutes < 5) {
          return _cachedBots!;
        }

        // If it's sort of fresh (< 24h), return cache IMMEDIATELY but trigger background fetch
        if (now.difference(localTime).inHours < 24) {
          // Trigger background fetch only if not already fetching
          if (_pendingFetch == null) {
            _fetchAndCacheBots();
          }
          return _cachedBots!;
        }
      }
    }
    // 3. API Fetch (Sync)
    return await _fetchAndCacheBots();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheBots() async {
    if (_pendingFetch != null) return _pendingFetch!;

    _pendingFetch = _performFetch();
    try {
      return await _pendingFetch!;
    } finally {
      _pendingFetch = null;
    }
  }

  Future<List<Map<String, dynamic>>> _performFetch() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final token = await _authService.getToken();
    if (token == null) return _cachedBots ?? [];

    try {
      print("DEBUG: Fetching bots from API... (Refreshing Cache)");
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/bots'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _cachedBots = List<Map<String, dynamic>>.from(data);
        _lastBotsFetch = now;

        // Save to Persistent Cache
        await prefs.setString(_botsCacheKey, jsonEncode(_cachedBots));
        await prefs.setString(_botsTimeKey, now.toIso8601String());

        return _cachedBots!;
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
    } catch (e) {
      print('DEBUG: BotService API Error: $e');
    }

    return _cachedBots ?? [];
  }

  void clearCache() async {
    _cachedBots = null;
    _lastBotsFetch = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_botsCacheKey);
    await prefs.remove(_botsTimeKey);
  }

  Future<bool> recruitBot(String botId) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/bots/recruit'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'bot_id': botId}),
      );

      if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
      return response.statusCode == 200;
    } catch (e) {
      print('DEBUG: recruitBot Error: $e');
      return false;
    }
  }
}
