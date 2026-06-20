import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'config_service.dart';

class BotService {
  final AuthService _authService = AuthService();

  static const String _botsCacheKey = 'cached_bots_list';
  static const String _botsTimeKey = 'cached_bots_timestamp';
  static const String _knownBotsDictKey = 'known_bots_dict';

  static Map<String, dynamic>? _knownBots;

  // Static cache to persist across service instances in the same session
  static List<Map<String, dynamic>>? _cachedBots;
  static DateTime? _lastBotsFetch;
  static Future<List<Map<String, dynamic>>>? _pendingFetch;

  Future<List<Map<String, dynamic>>> getBots({
    bool forceRefresh = false,
    String? type,
    String? category,
  }) async {
    final effectiveType = type ?? 'all';
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    // Only use cache for 'Main' or 'all' type with no category (default)
    bool isDefault = (effectiveType == 'Main' || effectiveType == 'all') && category == null;

    if (!isDefault) {
      return await _performFetch(type: type, category: category);
    }

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
    return await _fetchAndCacheBots(type: effectiveType);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheBots({String? type}) async {
    if (_pendingFetch != null) return _pendingFetch!;

    _pendingFetch = _performFetch(type: type);
    try {
      return await _pendingFetch!;
    } finally {
      _pendingFetch = null;
    }
  }

  Future<List<Map<String, dynamic>>> _performFetch({
    String? type,
    String? category,
  }) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final token = await _authService.getToken();
    if (token == null) return _cachedBots ?? [];

    try {
      if (kDebugMode) {
        print("DEBUG: Fetching bots from API... type=$type, category=$category");
      }

      String url = '${AppConstants.baseUrl}/bots';
      List<String> params = [];
      if (type != null) params.add('type=$type');
      if (category != null) params.add('category=$category');
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final result = List<Map<String, dynamic>>.from(data);

        // --- NEW: UPDATE KNOWN BOTS ---
        if (_knownBots == null) {
          final localJson = prefs.getString(_knownBotsDictKey);
          if (localJson != null) {
            _knownBots = Map<String, dynamic>.from(jsonDecode(localJson));
          } else {
            _knownBots = {};
          }
        }
        bool updatedKnownBots = false;
        for (var bot in result) {
          _knownBots![bot['id'].toString()] = bot;
          updatedKnownBots = true;
        }
        if (updatedKnownBots) {
          await prefs.setString(_knownBotsDictKey, jsonEncode(_knownBots));
        }
        // --- END ---

        // Only update global cache if fetching default bots
        if ((type == null || type == 'Main' || type == 'all') && category == null) {
          _cachedBots = result;
          _lastBotsFetch = now;
          await prefs.setString(_botsCacheKey, jsonEncode(_cachedBots));
          await prefs.setString(_botsTimeKey, now.toIso8601String());
        }

        return result;
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: BotService API Error: $e');
      }
    }

    return (type == null || type == 'Main' || type == 'all') ? (_cachedBots ?? []) : [];
  }

  Future<List<Map<String, dynamic>>> getEventCategories() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/event-categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: getEventCategories Error: $e');
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> getCategories() async {
    final token = await _authService.getToken();
    if (token == null) return {};

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/v1/categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: getCategories Error: $e');
      }
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getBotsByCategory(String slug) async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/v1/category/$slug'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: getBotsByCategory Error: $e');
      }
    }
    return [];
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
      if (kDebugMode) {
        print('DEBUG: recruitBot Error: $e');
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCalendarBots() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/v1/calendar'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: getCalendarBots Error: $e');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getChatTabBots() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/v1/bot-tab'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = List<Map<String, dynamic>>.from(jsonDecode(response.body));

        // Update _knownBots so getBotById can resolve bonded bots
        _knownBots ??= {};
        for (var bot in result) {
          _knownBots![bot['id'].toString()] = Map<String, dynamic>.from(bot);
        }

        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: getChatTabBots Error: $e');
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getRecruitedBots() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/v1/recruited-bots'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: getRecruitedBots Error: $e');
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getBotById(String botId) async {
    if (_knownBots != null && _knownBots!.containsKey(botId)) {
      return _knownBots![botId];
    }
    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString(_knownBotsDictKey);
    if (localJson != null) {
      _knownBots = Map<String, dynamic>.from(jsonDecode(localJson));
      if (_knownBots!.containsKey(botId)) {
        return _knownBots![botId];
      }
    }
    return null;
  }
}
