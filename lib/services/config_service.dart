import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static const String _configUrl =
      'https://api-bluetalk.my-bini.my.id/api/app/status';

  static String? _baseUrl;
  static bool _isMaintenance = false;
  static String _maintenanceMsg = "HaloStory is under maintenance.";
  static String _remoteVersion = "0.0.0";
  static bool _needsUpdate = false;

  static String get baseUrl =>
      _baseUrl ??
      'https://imouto-fansub.my.id/bluetalk_backend/api'; // Menggunakan base url default yang baru
  static bool get isMaintenance => kDebugMode ? false : _isMaintenance;
  static String get maintenanceMsg => _maintenanceMsg;
  static String get remoteVersion => _remoteVersion;
  static bool get needsUpdate => _needsUpdate;

  /// Manually trigger maintenance mode (e.g. on 503 error)
  static void enterMaintenance([String? msg]) {
    if (kDebugMode) return;
    _isMaintenance = true;
    if (msg != null) _maintenanceMsg = msg;
    print("DEBUG: ConfigService - Entered Maintenance Mode via 503");
  }

  /// Fetch configuration from Laravel API
  static Future<bool> initConfig() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVer = packageInfo.version;

      // Prevent caching by adding a timestamp, also pass local version
      final String antiCacheUrl =
          '$_configUrl?app-ver=$localVer&t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await http
          .get(Uri.parse(antiCacheUrl), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _applyConfig(data);
        await _checkVersion(data['version']);
        return true;
      }
      return false;
    } catch (e) {
      print('DEBUG: ConfigService Fetch Error: $e');
      return false;
    }
  }

  static void _applyConfig(Map<String, dynamic> data) {
    _baseUrl = data['api_url'];
    _isMaintenance = kDebugMode ? false : (data['status'] == 'maintenance');
    _maintenanceMsg = data['maintenance_message'] ?? _maintenanceMsg;
    _remoteVersion = data['version'] ?? "0.0.0";
  }

  static Future<void> _checkVersion(String? remoteVer) async {
    if (remoteVer == null) {
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
      bool majorUpdate =
          remoteParts[0] == localParts[0] && remoteParts[1] > localParts[1];

      if (superMajorUpdate || majorUpdate) {
        _needsUpdate = true;
      } else {
        _needsUpdate = false;
      }

      print(
        "DEBUG: Version Check - Local: $localVer, Remote: $remoteVer, NeedsUpdate: $_needsUpdate",
      );
    } catch (e) {
      print("DEBUG: Version check error: $e");
    }
  }

  /// Refetch config
  static Future<bool> refreshConfigOnFailure() async {
    return await initConfig();
  }
}
