import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto/crypto.dart';
import '../constants.dart';

class BanService {
  static bool _isBanned = false;
  static String? _banReason;
  static String? _bannedUntil;
  static Map<String, String?>? _deviceInfo;

  static const String _banCacheKey = 'ban_cache_result';
  static const String _banCacheTimeKey = 'ban_cache_timestamp';
  static DateTime? _lastBanCheck;
  static bool? _cachedBanResult;

  static bool get isBanned => _isBanned;
  static String? get banReason => _banReason;
  static String? get bannedUntil => _bannedUntil;

  static void setBanned(String reason, {String? until}) {
    _isBanned = true;
    _banReason = reason;
    _bannedUntil = until;
  }

  static void clearBan() {
    _isBanned = false;
    _banReason = null;
    _bannedUntil = null;
  }

  static bool isBanResponse(http.Response response) {
    if (response.statusCode != 403) return false;
    try {
      final body = jsonDecode(response.body);
      return body['message']?.toString().contains('banned') == true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic>? extractBanData(http.Response response) {
    if (!isBanResponse(response)) return null;
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> handleBanFromResponse(http.Response response) async {
    if (!isBanResponse(response)) return;
    try {
      final body = jsonDecode(response.body);
      setBanned(body['reason'] ?? 'Violation', until: body['banned_until']);
    } catch (_) {
      setBanned('Unknown reason');
    }
    await _collectAndReport();
  }

  static Future<void> handleBanFromProfile(Map<String, dynamic> profile) async {
    final banned = profile['is_banned'] == true;
    if (!banned) return;
    setBanned(
      profile['ban_reason'] ?? 'Violation',
      until: profile['banned_until'],
    );
    await _collectAndReport();
  }

  static Future<void> handleBanFromMessage(String reason, {String? until}) async {
    setBanned(reason, until: until);
    await _collectAndReport();
  }

  static Future<Map<String, String?>> collectDeviceInfo() async {
    if (_deviceInfo != null) return _deviceInfo!;

    final info = <String, String?>{
      'device_model': 'Unknown',
      'device_brand': 'Unknown',
      'os_version': 'Unknown',
      'platform': kIsWeb ? 'web' : 'unknown',
    };

    try {
      final plugin = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await plugin.webBrowserInfo;
        info['device_id'] = 'web-${_webFingerprint(webInfo)}';
        info['device_model'] = webInfo.userAgent?.substring(0, 120);
        info['device_brand'] = webInfo.vendor;
        info['os_version'] = webInfo.platform;
        info['platform'] = 'web';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await plugin.androidInfo;
        info['device_id'] = androidInfo.id;
        info['device_model'] = androidInfo.model;
        info['device_brand'] = '${androidInfo.brand} ${androidInfo.manufacturer}';
        info['os_version'] = '${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        info['platform'] = 'android';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await plugin.iosInfo;
        info['device_id'] = iosInfo.identifierForVendor;
        info['device_model'] = iosInfo.model;
        info['device_brand'] = 'Apple';
        info['os_version'] = iosInfo.systemVersion;
        info['platform'] = 'ios';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windowsInfo = await plugin.windowsInfo;
        info['device_id'] = 'windows-${windowsInfo.deviceId}';
        info['device_model'] = windowsInfo.computerName;
        info['device_brand'] = 'Microsoft';
        info['os_version'] = '${windowsInfo.majorVersion}.${windowsInfo.minorVersion}.${windowsInfo.buildNumber}';
        info['platform'] = 'windows';
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await plugin.linuxInfo;
        info['device_id'] = 'linux-${linuxInfo.machineId}';
        info['device_model'] = linuxInfo.name;
        info['device_brand'] = linuxInfo.id;
        info['os_version'] = linuxInfo.version;
        info['platform'] = 'linux';
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macosInfo = await plugin.macOsInfo;
        info['device_id'] = 'macos-${macosInfo.systemGUID}';
        info['device_model'] = macosInfo.model;
        info['device_brand'] = 'Apple';
        info['os_version'] = macosInfo.osRelease;
        info['platform'] = 'macos';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: BanService deviceInfo error: $e');
    }

    info['device_id'] = info['device_id'] ?? 'unknown-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      info['app_version'] = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      info['app_version'] = 'Unknown';
    }

    _deviceInfo = info;
    return info;
  }

  static String _webFingerprint(WebBrowserInfo info) {
    final raw = '${info.vendor ?? ''}|${info.platform ?? ''}|${info.userAgent ?? ''}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
  }

  static Future<void> _collectAndReport() async {
    final info = await collectDeviceInfo();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/report-banned-device'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'device_id': info['device_id'],
              'device_model': info['device_model'],
              'device_brand': info['device_brand'],
              'os_version': info['os_version'],
              'platform': info['platform'],
              'app_version': info['app_version'],
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: BanService report error: $e');
    }
  }

  static Future<bool> checkUserBanStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return false;

    // Cache check: skip API call if checked < 10 minutes ago
    final now = DateTime.now();
    if (_lastBanCheck != null &&
        now.difference(_lastBanCheck!).inMinutes < 10) {
      return _cachedBanResult ?? false;
    }

    final cachedTimeStr = prefs.getString(_banCacheTimeKey);
    if (cachedTimeStr != null) {
      final cachedTime = DateTime.parse(cachedTimeStr);
      if (now.difference(cachedTime).inMinutes < 10) {
        _lastBanCheck = cachedTime;
        _cachedBanResult = prefs.getBool(_banCacheKey) ?? false;
        return _cachedBanResult!;
      }
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/user'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      final bool banned;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['is_banned'] == true) {
          await handleBanFromProfile(body);
          banned = true;
        } else {
          banned = false;
        }
      } else if (isBanResponse(response)) {
        await handleBanFromResponse(response);
        banned = true;
      } else {
        banned = false;
      }

      // Cache the result
      _lastBanCheck = now;
      _cachedBanResult = banned;
      await prefs.setBool(_banCacheKey, banned);
      await prefs.setString(_banCacheTimeKey, now.toIso8601String());

      return banned;
    } catch (_) {
      return false;
    }
  }
}
