import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, amoled }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;
  bool get isAmoledDark => _mode == AppThemeMode.amoled;
  ThemeMode get themeMode => isAmoledDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawMode = prefs.getString(_themeKey);

    if (rawMode == 'amoled') {
      _mode = AppThemeMode.amoled;
    } else {
      _mode = AppThemeMode.light;
    }
  }

  Future<void> setAmoledDark(bool enabled) async {
    final AppThemeMode newMode = enabled
        ? AppThemeMode.amoled
        : AppThemeMode.light;

    if (newMode == _mode) return;

    _mode = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, enabled ? 'amoled' : 'light');
    notifyListeners();
  }
}
