import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';

class BotService {
  final AuthService _authService = AuthService();
  
  static const String _botsCacheKey = 'cached_bots_list';
  static const String _botsTimeKey = 'cached_bots_timestamp';
  
  // Static cache to persist across service instances in the same session
  static List<Map<String, dynamic>>? _cachedBots;
  static DateTime? _lastBotsFetch;

  Future<List<Map<String, dynamic>>> getBots({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // 1. Memory Cache Check - VERY FRESH (< 1 minute)
    bool isMemCacheVeryFresh = _lastBotsFetch != null && 
                           now.difference(_lastBotsFetch!).inMinutes < 1;

    if (!forceRefresh && isMemCacheVeryFresh && _cachedBots != null) {
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
          _fetchAndCacheBots(); // Background fetch
          return _cachedBots!;
        }
      }
    }

    // 3. API Fetch (Sync)
    return await _fetchAndCacheBots();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheBots() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final token = await _authService.getToken();
    if (token == null) return _cachedBots ?? [];

    try {
      print("DEBUG: Fetching bots from API... (Refreshing Cache)");
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _cachedBots = List<Map<String, dynamic>>.from(data);
        _lastBotsFetch = now;
        
        // Save to Persistent Cache
        await prefs.setString(_botsCacheKey, jsonEncode(_cachedBots));
        await prefs.setString(_botsTimeKey, now.toIso8601String());
        
        return _cachedBots!;
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
}
