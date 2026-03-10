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

  String get currentLocale => _currentLocale;

  final Map<String, String> _localeToName = {
    'id': 'Indonesian',
    'en': 'English',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
  };

  String get currentLanguageName => _localeToName[_currentLocale] ?? 'Indonesian';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_language') ?? 'id';
    await load(_currentLocale);
  }

  Future<void> load(String locale) async {
    String jsonString = await rootBundle.loadString('assets/lang/$locale.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    _currentLocale = locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale);

    notifyListeners();
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  static LocalizationService of(k) => _instance;
}

// Global helper for cleaner code
String tr(String key) => LocalizationService().translate(key);
