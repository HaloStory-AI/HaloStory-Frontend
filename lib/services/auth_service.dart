import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _loginDateKey = 'login_date';

  Future<bool> register(String name, String email, String password, String passwordConfirmation) async {
    try {
      final response = await http.post(
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['access_token']);
        return true;
      }
      print('DEBUG: Register failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      print('DEBUG: Register error (timeout or network): $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${AppConstants.staticToken}',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveToken(data['access_token']);
        return true;
      }
      print('DEBUG: Login failed with status: ${response.statusCode}, body: ${response.body}');
      return false;
    } catch (e) {
      print('DEBUG: Login error (timeout or network): $e');
      return false;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_loginDateKey, DateTime.now().toIso8601String());
    print("DEBUG: Token saved to SharedPrefs: $token");
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

  // Validate token against the server - used on app start
  Future<bool> validateTokenWithServer(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/user'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Cache the profile since we fetched it anyway
        _userProfileCache = jsonDecode(response.body);
        _lastProfileFetch = DateTime.now();
        return true;
      } else if (response.statusCode == 401) {
        // Token is invalid/expired on server side - clear it
        print('DEBUG: Token rejected by server (401), clearing local token.');
        await logout();
        return false;
      }
      return false;
    } catch (e) {
      // Network error: don't clear token (server might be temporarily down)
      // Return true so the user can still access cached content
      print('DEBUG: Token validation network error: $e. Allowing offline access.');
      return true;
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;
    return await validateTokenWithServer(token);
  }

  // --- Profile Caching ---
  Map<String, dynamic>? _userProfileCache;
  DateTime? _lastProfileFetch;

  Future<Map<String, dynamic>?> getUserProfile({bool forceRefresh = false}) async {
    final now = DateTime.now();
    bool isCacheExpired = _lastProfileFetch == null || 
                         now.difference(_lastProfileFetch!).inHours >= 3;

    if (!forceRefresh && !isCacheExpired && _userProfileCache != null) {
      print("DEBUG: Returning cached user profile");
      return _userProfileCache;
    }

    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/user'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _userProfileCache = jsonDecode(response.body);
        _lastProfileFetch = DateTime.now();
        print("DEBUG: Fetched user profile from API");
        return _userProfileCache;
      } else {
        print("DEBUG: Failed to fetch profile: ${response.statusCode}");
      }
    } catch (e) {
      print("DEBUG: Error fetching profile: $e");
      // Return local cache if available during network issues
      return _userProfileCache;
    }
    return null;
  }

  void clearCache() {
    _userProfileCache = null;
    _lastProfileFetch = null;
  }
}
