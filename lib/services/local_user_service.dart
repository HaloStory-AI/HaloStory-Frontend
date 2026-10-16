import 'package:shared_preferences/shared_preferences.dart';

class LocalUserService {
  static const String _key = 'local_user_name';
  static const String defaultName = 'Sensei';
  static const int maxLength = 50;

  static String sanitize(String input) {
    var s = input.trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }

  static Future<String> getLocalUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == null || v.trim().isEmpty) return defaultName;
    return v;
  }

  static String getLocalUserNameSync(SharedPreferences prefs) {
    final v = prefs.getString(_key);
    if (v == null || v.trim().isEmpty) return defaultName;
    return v;
  }

  static Future<void> setLocalUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final s = sanitize(name);
    if (s.isEmpty) return;
    await prefs.setString(_key, s);
  }

  static Future<bool> hasLocalUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    return v != null && v.trim().isNotEmpty;
  }

  static Future<String?> getRawLocalUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}
