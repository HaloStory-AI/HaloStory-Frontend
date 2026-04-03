import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Map<String, String> _localizedStrings = {};
  String _currentLocale = 'id';

  // Fallback strings for essential UI components (Splash, Maintenance, Update)
  // This ensures the app doesn't show a white screen if assets fail to load.
  final Map<String, String> _fallbackStrings = {
    'update_title': 'Pembaruan Tersedia',
    'update_desc':
        'Versi baru BlueTalk sudah tersedia. Yuk update ke versi terbaru!',
    'update_version': 'Versi',
    'update_btn': 'Update Sekarang',
    'maintenance_title': 'Sedang Maintenance',
    'maintenance_info': 'Mohon maaf, BlueTalk sedang dalam pemeliharaan.',
    'exit_app': 'Keluar Aplikasi',
    'system_notice_title': 'Pemberitahuan Sistem',
    'system_notice_content':
        'Semua model AI sedang sibuk. Silakan coba lagi nanti.',
    'system_notice_btn': 'Mengerti',
    'settings_theme': 'Tampilan',
    'settings_theme_amoled_title': 'Aktifkan Mode Gelap AMOLED',
    'settings_theme_amoled_desc':
        'Gunakan latar hitam pekat untuk kontras lebih tinggi dan efisiensi baterai pada layar OLED.',
  };

  String get currentLocale => _currentLocale;

  final Map<String, String> _localeToName = {
    'id': 'Indonesian',
    'en': 'English',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
  };

  String get currentLanguageName =>
      _localeToName[_currentLocale] ?? 'Indonesian';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedLocale = prefs.getString('app_language');

      if (savedLocale == null) {
        // Detect device locale
        final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
        if (_localeToName.containsKey(deviceLocale)) {
          _currentLocale = deviceLocale;
        } else {
          _currentLocale =
              'en'; // Fallback to English if device locale is not supported
        }
      } else {
        _currentLocale = savedLocale;
      }

      await load(_currentLocale);
    } catch (e) {
      debugPrint('Localization Init Error: $e');
      _currentLocale = 'en'; // Hard fallback to English
      notifyListeners();
    }
  }

  Future<void> load(String locale) async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/lang/$locale.json',
        cache: false,
      );
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      _currentLocale = locale;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', locale);
    } catch (e) {
      debugPrint('Localization Load Error ($locale): $e');
      // If we failed to load, we still want to notifyListeners so the splash screen can move on
    }
    notifyListeners();
  }

  String translate(String key) {
    return _localizedStrings[key] ?? _fallbackStrings[key] ?? key;
  }

  static LocalizationService of(k) => _instance;
}

// Global helper for cleaner code
String tr(String key) => LocalizationService().translate(key);
