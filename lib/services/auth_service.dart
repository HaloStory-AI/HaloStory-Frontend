import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _loginDateKey = 'login_date';

  Future<bool> register(String name, String email, String password, String passwordConfirmation) async {
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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['access_token']);
      return true;
    }
    return false;
  }

  Future<bool> login(String email, String password) async {
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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveToken(data['access_token']);
      return true;
    }
    return false;
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

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // --- Profile Caching ---
  Map<String, dynamic>? _userProfileCache;

  Future<Map<String, dynamic>?> getUserProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _userProfileCache != null) {
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
      );

      if (response.statusCode == 200) {
        _userProfileCache = jsonDecode(response.body);
        print("DEBUG: Fetched user profile from API");
        return _userProfileCache;
      } else {
        print("DEBUG: Failed to fetch profile: ${response.statusCode}");
      }
    } catch (e) {
      print("DEBUG: Error fetching profile: $e");
    }
    return null;
  }

  void clearCache() {
    _userProfileCache = null;
  }
}
