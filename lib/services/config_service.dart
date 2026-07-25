import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static const String _configUrl =
      'https://icy-recipe-89f8.r8kstudio.workers.dev/';

  static String? _baseUrl;
  static bool _isMaintenance = false;
  static bool isAutoDetectedMaintenance = false;
  static bool isConnectionTimeout = false;
  static String _maintenanceMsg = "HaloStory is under maintenance.";
  static String _remoteVersion = "0.0.0";
  static bool _needsUpdate = false;
  static bool _hasMinorUpdate = false;

  static DateTime? _lastWorkerCheck;

  static String get baseUrl =>
      _baseUrl ??
      'https://imouto-fansub.my.id/bluetalk_backend/api'; // Menggunakan base url default yang baru
  static bool get isMaintenance => kDebugMode ? false : _isMaintenance;
  static String get maintenanceMsg => _maintenanceMsg;
  static String get remoteVersion => _remoteVersion;
  static bool get needsUpdate => _needsUpdate;
  static bool get hasMinorUpdate => _hasMinorUpdate;

  /// Manually trigger maintenance mode (e.g. on 503 error)
  static void enterMaintenance([String? msg]) {
    if (kDebugMode) return;
    isAutoDetectedMaintenance = true;
    if (msg != null) _maintenanceMsg = msg;
    if (kDebugMode) {
      print("DEBUG: ConfigService - Entered Maintenance Mode via 503");
    }
  }

  /// Fetch CF Worker to check server status (throttled to once per 5 min)
  static Future<void> checkServerUp() async {
    final now = DateTime.now();
    if (_lastWorkerCheck != null &&
        now.difference(_lastWorkerCheck!).inMinutes < 5) {
      return;
    }

    try {
      final String url =
          '$_configUrl?t=${now.millisecondsSinceEpoch}';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastWorkerCheck = now;
        _applyConfig(data);
        isAutoDetectedMaintenance = _isMaintenance;
      } else if (response.statusCode == 503) {
        _lastWorkerCheck = now;
        isAutoDetectedMaintenance = true;
        _maintenanceMsg =
            "Server on maintenance, No detail from Developer cause the auto detect, try again later.";
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: ConfigService Worker Ping Error: $e');
      }
    }
  }

  /// Fetch configuration from Laravel API
  static Future<bool> initConfig() async {
    isAutoDetectedMaintenance = false;
    isConnectionTimeout = false;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVer = packageInfo.version;

      // Prevent caching by adding a timestamp, also pass local version
      final String antiCacheUrl =
          '$_configUrl?app-ver=$localVer&t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await http
          .get(Uri.parse(antiCacheUrl), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _applyConfig(data);
        await _checkVersion(data['version']);
        return true;
      } else if (response.statusCode == 503) {
        isAutoDetectedMaintenance = true;
        _maintenanceMsg =
            "Server on maintenance, No detail from Developer cause the auto detect, try again later.";
        return true; // Return true because we handled it as a known state (Maintenance)
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: ConfigService Fetch Error: $e');
      }
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException')) {
        isConnectionTimeout = true;
      }
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
      while (localParts.length < 3) {
        localParts.add(0);
      }
      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }

      // Comparison logic:
      // SuperMajor [0] or Major [1] requires update.
      // Minor [2] does NOT require update (Silent).

      bool superMajorUpdate = remoteParts[0] > localParts[0];
      bool majorUpdate =
          remoteParts[0] == localParts[0] && remoteParts[1] > localParts[1];

      if (superMajorUpdate || majorUpdate) {
        _needsUpdate = true;
        _hasMinorUpdate = false;
      } else {
        _needsUpdate = false;
        bool minorUpdate = remoteParts[0] == localParts[0] &&
            remoteParts[1] == localParts[1] &&
            remoteParts[2] > localParts[2];
        _hasMinorUpdate = minorUpdate;
      }

      if (kDebugMode) {
        print(
        "DEBUG: Version Check - Local: $localVer, Remote: $remoteVer, NeedsUpdate: $_needsUpdate",
      );
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Version check error: $e");
      }
    }
  }

  /// Refetch config
  static Future<bool> refreshConfigOnFailure() async {
    return await initConfig();
  }
}
