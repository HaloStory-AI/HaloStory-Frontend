import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ConfigService {
  static const String _configUrl = 'https://raw.githubusercontent.com/rafiq8k-moga/bluetalk-app_repo/refs/heads/main/bluetalk-app-endpoint.json';
  static const String _cacheKey = 'dynamic_api_config';
  static const String _cacheTimeKey = 'dynamic_api_config_time';

  static String? _baseUrl;
  static bool _isMaintenance = false;
  static String _maintenanceMsg = "BlueTalk is under maintenance.";

  static String get baseUrl => _baseUrl ?? 'https://moutogami.com/bluetalk_backend/api';
  static bool get isMaintenance => _isMaintenance;
  static String get maintenanceMsg => _maintenanceMsg;

  /// Fetch configuration from GitHub or Cache (24h)
  static Future<void> initConfig({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!forceRefresh) {
      final cachedJson = prefs.getString(_cacheKey);
      final cachedTimeStr = prefs.getString(_cacheTimeKey);

      if (cachedJson != null && cachedTimeStr != null) {
        final cachedTime = DateTime.parse(cachedTimeStr);
        if (now.difference(cachedTime).inHours < 24) {
          _applyConfig(jsonDecode(cachedJson));
          return;
        }
      }
    }

    try {
      final response = await http.get(Uri.parse(_configUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _applyConfig(data);
        
        // Save to cache
        await prefs.setString(_cacheKey, response.body);
        await prefs.setString(_cacheTimeKey, now.toIso8601String());
      }
    } catch (e) {
      print('DEBUG: ConfigService Fetch Error: $e');
      // If fetch fails and we have no cache, we use defaults in get baseUrl
    }
  }

  static void _applyConfig(Map<String, dynamic> data) {
    _baseUrl = data['api_url'];
    _isMaintenance = data['status'] == 'maintenance';
    _maintenanceMsg = data['maintenance_message'] ?? _maintenanceMsg;
  }

  /// Call this when an API request fails with a connection error (not 503)
  static Future<void> refreshConfigOnFailure() async {
    await initConfig(forceRefresh: true);
  }
}
