import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static const String _configUrl = 'https://raw.githubusercontent.com/rafiq8k-moga/bluetalk-app_repo/refs/heads/main/bluetalk-app-endpoint.json';

  static String? _baseUrl;
  static bool _isMaintenance = false;
  static String _maintenanceMsg = "BlueTalk is under maintenance.";
  static String _remoteVersion = "0.0.0";
  static bool _needsUpdate = false;

  static String get baseUrl => _baseUrl ?? 'https://moutogami.com/bluetalk_backend/api';
  static bool get isMaintenance => _isMaintenance;
  static String get maintenanceMsg => _maintenanceMsg;
  static String get remoteVersion => _remoteVersion;
  static bool get needsUpdate => _needsUpdate;

  /// Fetch configuration from GitHub (No Cache)
  static Future<void> initConfig() async {
    try {
      final response = await http.get(Uri.parse(_configUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _applyConfig(data);
        await _checkVersion(data['version']);
      }
    } catch (e) {
      print('DEBUG: ConfigService Fetch Error: $e');
    }
  }

  static void _applyConfig(Map<String, dynamic> data) {
    _baseUrl = data['api_url'];
    _isMaintenance = data['status'] == 'maintenance';
    _maintenanceMsg = data['maintenance_message'] ?? _maintenanceMsg;
    _remoteVersion = data['version'] ?? "0.0.0";
  }

  static Future<void> _checkVersion(String? remoteVer) async {
    if (remoteVer == null || kDebugMode) {
      _needsUpdate = false;
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVer = packageInfo.version; // e.g. "0.3.0"

      final localParts = localVer.split('.').map(int.parse).toList();
      final remoteParts = remoteVer.split('.').map(int.parse).toList();

      // Ensure we have at least 3 parts (SuperMajor.Major.Minor)
      while (localParts.length < 3) localParts.add(0);
      while (remoteParts.length < 3) remoteParts.add(0);

      // Comparison logic:
      // SuperMajor [0] or Major [1] requires update.
      // Minor [2] does NOT require update (Silent).
      
      bool superMajorUpdate = remoteParts[0] > localParts[0];
      bool majorUpdate = remoteParts[0] == localParts[0] && remoteParts[1] > localParts[1];

      if (superMajorUpdate || majorUpdate) {
        _needsUpdate = true;
      } else {
        _needsUpdate = false;
      }
      
      print("DEBUG: Version Check - Local: $localVer, Remote: $remoteVer, NeedsUpdate: $_needsUpdate");
    } catch (e) {
      print("DEBUG: Version check error: $e");
    }
  }

  /// Refetch config
  static Future<void> refreshConfigOnFailure() async {
    await initConfig();
  }
}
