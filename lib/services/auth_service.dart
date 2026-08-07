import 'dart:async';
import 'dart:convert';
import 'package:bluetalk_frontend/notifier/bottomnav_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'config_service.dart';
import 'ban_service.dart';

enum AuthType {
  EXCHANGE,
  LINK
}

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _loginDateKey = 'login_date';

  static final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  static Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${AppConstants.staticToken}',
            },
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveToken(data['access_token']);
        _userProfileCache = data['user'];
        _lastProfileFetch = DateTime.now();
        return {'success': true, 'message': data['message'] ?? 'Berhasil.'};
      }
      if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
      if (kDebugMode) {
        print('DEBUG: Register failed with status: ${response.statusCode}');
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal mendaftar.',
      };
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Register error (timeout or network): $e');
      }
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${AppConstants.staticToken}',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveToken(data['access_token']);
        _userProfileCache = data['user'];
        _lastProfileFetch = DateTime.now();
        return {'success': true, 'message': data['message'] ?? 'Berhasil.'};
      }
      if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
      if (response.statusCode == 403 && data is Map && data['message']?.toString().contains('banned') == true) {
        await BanService.handleBanFromResponse(response);
        return {'success': false, 'banned': true, 'message': data['message'] ?? 'Akun dibanned.'};
      }
      if (kDebugMode) {
        print(
        'DEBUG: Login failed with status: ${response.statusCode}, body: ${response.body}',
      );
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal masuk.'};
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Login error (timeout or network): $e');
      }
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await plugin.webBrowserInfo;
        return 'web-${webInfo.userAgent.hashCode}';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final androidInfo = await plugin.androidInfo;
          return androidInfo.id;
        case TargetPlatform.iOS:
          final iosInfo = await plugin.iosInfo;
          return iosInfo.identifierForVendor ?? 'ios-unknown';
        case TargetPlatform.windows:
          final windowsInfo = await plugin.windowsInfo;
          return windowsInfo.deviceId;
        case TargetPlatform.linux:
          final linuxInfo = await plugin.linuxInfo;
          return linuxInfo.machineId ?? 'linux-unknown';
        case TargetPlatform.macOS:
          final macosInfo = await plugin.macOsInfo;
          return macosInfo.systemGUID ?? 'macos-unknown';
        default:
          return 'unknown';
      }
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Error getting device ID: $e');
      }
      return 'unknown-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<Map<String, dynamic>> sendAuthCode(
    String authCode,
    AuthType authType, {
    String? redirectUri,
    String? clientId,
    String? clientSecret,
  }) async {
    try {
      final deviceId = await _getDeviceId();

      String authEndpoint = "exchange";
      String bearer = AppConstants.staticToken;
      if (authType == AuthType.LINK) {
        authEndpoint = "link";
        bearer = await getToken() ?? "";
      }

      final Map<String, dynamic> bodyParams = {
        'authorization_code': authCode,
        'device_id': deviceId,
      };
      if (redirectUri != null) bodyParams['redirect_uri'] = redirectUri;
      if (clientId != null) bodyParams['client_id'] = clientId;
      if (clientSecret != null) bodyParams['client_secret'] = clientSecret;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/google/$authEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $bearer',
            },
            body: jsonEncode(bodyParams),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveToken(data['access_token']);
        _userProfileCache = data['user'];
        _lastProfileFetch = DateTime.now();
        return {'success': true, 'message': data['message'] ?? 'Berhasil.', 'email': data["user"]["email"]};
      }
      if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
      }
      if (response.statusCode == 403 && data is Map && data['message']?.toString().contains('banned') == true) {
        await BanService.handleBanFromResponse(response);
        return {'success': false, 'banned': true, 'message': data['message'] ?? 'Akun dibanned.', 'email': ''};
      }
      if (kDebugMode) {
        print(
        'DEBUG: Login failed with status: ${response.statusCode}, body: ${response.body}',
      );
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal masuk.', 'email': ''};
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: Login error (timeout or network): $e');
      }
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.', 'email': ''};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/forgot-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${AppConstants.staticToken}',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Berhasil.'};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memproses.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/reset-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${AppConstants.staticToken}',
            },
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Berhasil.'};
      }
      return {'success': false, 'message': data['message'] ?? 'Gagal mereset.'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> sendVerificationOtp() async {
    final token = await getToken();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/email/verify/send'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Berhasil.'};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memproses.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String otp) async {
    final token = await getToken();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/email/verify'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Cache the updated user profile
        _userProfileCache = data['user'];
        _lastProfileFetch = DateTime.now();
        return {'success': true, 'message': data['message'] ?? 'Berhasil.'};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Gagal memverifikasi.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_loginDateKey, DateTime.now().toIso8601String());
    if (kDebugMode) {
      print("DEBUG: Token saved to SharedPrefs: $token");
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final loginDateStr = prefs.getString(_loginDateKey);

    if (token != null && loginDateStr != null) {
      final loginDate = DateTime.parse(loginDateStr);
      final now = DateTime.now();

      // Check if it has been more than 30 days
      if (now.difference(loginDate).inDays > 30) {
        await logout();
        return null;
      }
      return token;
    }
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_loginDateKey);
  }

  bool _validationHadNetworkError = false;
  bool get validationHadNetworkError => _validationHadNetworkError;

  // Validate token against the server - used on app start
  Future<bool> validateTokenWithServer(String token) async {
    _validationHadNetworkError = false;
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
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        _userProfileCache = body;
        _lastProfileFetch = DateTime.now();

        // Check if user is banned
        if (body is Map<String, dynamic> && body['is_banned'] == true) {
          await BanService.handleBanFromProfile(body);
          return false;
        }

        return true;
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          print('DEBUG: Token rejected by server (401), clearing local token.');
        }
        await logout();
        _sessionExpiredController.add(null);
        return false;
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        return false;
      } else if (BanService.isBanResponse(response)) {
        await BanService.handleBanFromResponse(response);
        return false;
      }
      return false;
    } catch (e) {
      _validationHadNetworkError = true;
      // Network error: don't clear token (server might be temporarily down)
      // Return true so the user can still access cached content
      if (kDebugMode) {
        print(
        'DEBUG: Token validation network error: $e. Allowing offline access.',
      );
      }
      return true;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;
    return await validateTokenWithServer(token);
  }

  bool get isEmailVerified {
    if (_userProfileCache == null) return false;
    return _userProfileCache!['email_verified_at'] != null;
  }

  // --- Profile Caching ---
  Map<String, dynamic>? _userProfileCache;
  DateTime? _lastProfileFetch;

  Future<Map<String, dynamic>?> getUserProfile({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    bool isCacheExpired =
        _lastProfileFetch == null ||
        now.difference(_lastProfileFetch!).inHours >= 3;

    if (!forceRefresh && !isCacheExpired && _userProfileCache != null) {
      if (kDebugMode) {
        print("DEBUG: Returning cached user profile");
      }
      return _userProfileCache;
    }

    final token = await getToken();
    if (token == null) return null;

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
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _userProfileCache = jsonDecode(response.body);
        _lastProfileFetch = DateTime.now();
        BottomNavProvider().setEmail(_userProfileCache!["email"]);
        if (kDebugMode) {
          print("DEBUG: Fetched user profile from API");
        }
        return _userProfileCache;
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: 503 (Maintenance)");
        }
      } else {
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching profile: $e");
      }
      // Return local cache if available during network issues
      return _userProfileCache;
    }
    return null;
  }

  Future<bool> getUserHasLocalPassword() async {
    final token = await getToken();
    if (token == null) return true;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/user/has_local_password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result["has_local_password"];
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: 503 (Maintenance)");
        }
      } else {
        if (kDebugMode) {
          print("DEBUG: Failed to fetch check has_local_password: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching has_local_password: $e");
      }
      // Return local cache if available during network issues
      return true;
    }

    return true;
  }

  Future<bool> getUserOauthStatus() async {
    final token = await getToken();
    if (token == null) return true;

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/user/has_google_auth'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result["has_google_auth"];
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: 503 (Maintenance)");
        }
      } else {
        if (kDebugMode) {
          print("DEBUG: Failed to fetch check has_google_auth: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching has_google_auth: $e");
      }
      // Return local cache if available during network issues
      return true;
    }

    return true;
  }

  Future<Map<String, dynamic>> updateEmail(
    String email,
    String password,
  ) async {
    final token = await getToken();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/update-email'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        clearCache();
        return {'success': true, 'message': 'Email updated successfully'};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update email',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> updateName(String name) async {
    final token = await getToken();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/update-name'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Cache the updated user profile
        _userProfileCache = data['user'];
        _lastProfileFetch = DateTime.now();
        return {'success': true, 'message': 'Username updated successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update username',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> updatePersona(String persona) async {
    final token = await getToken();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/update-persona'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'persona': persona}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _userProfileCache = data['user'];
        _lastProfileFetch = DateTime.now();
        return {'success': true, 'message': 'Persona updated successfully'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update persona',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  Future<Map<String, dynamic>> updatePassword(
    String currentPassword,
    String newPassword,
    String newPasswordConfirmation,
  ) async {
    final token = await getToken();
    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/update-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
              'new_password_confirmation': newPasswordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Password updated successfully'};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update password',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred'};
    }
  }

  void clearCache() {
    _userProfileCache = null;
    _lastProfileFetch = null;
  }
}
