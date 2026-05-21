import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService extends ChangeNotifier {
  static final WallpaperService _instance = WallpaperService._internal();
  factory WallpaperService() => _instance;
  WallpaperService._internal();

  static const String _typeKey = 'chat_wallpaper_type';
  static const String _valueKey = 'chat_wallpaper_value';
  static const String _dimKey = 'chat_wallpaper_dim';

  static const List<String> presetWallpapers = [
    'assets/background/wallpaper_1.png',
    'assets/background/wallpaper_2.png',
    'assets/background/wallpaper_3.png',
    'assets/background/wallpaper_4.png',
  ];

  String _type = 'none';
  String? _value;
  double _dim = 0.0;

  String get type => _type;
  String? get value => _value;
  double get dim => _dim;

  static bool isMobileLayout(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _type = prefs.getString(_typeKey) ?? 'none';
    _value = prefs.getString(_valueKey);
    _dim = prefs.getDouble(_dimKey) ?? 0.0;
    notifyListeners();
  }

  Future<void> setNone() async {
    _type = 'none';
    _value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'none');
    await prefs.remove(_valueKey);
    notifyListeners();
  }

  Future<void> setPreset(String assetPath) async {
    _type = 'preset';
    _value = assetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'preset');
    await prefs.setString(_valueKey, assetPath);
    notifyListeners();
  }

  Future<void> setGallery(String localPath) async {
    _type = 'gallery';
    _value = localPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'gallery');
    await prefs.setString(_valueKey, localPath);
    notifyListeners();
  }

  Future<void> setDim(double dim) async {
    _dim = dim;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_dimKey, dim);
    notifyListeners();
  }

  BoxDecoration? getBoxDecoration(BuildContext context) {
    if (!isMobileLayout(context)) return null;
    if (_type == 'none') return null;

    ImageProvider image;
    if (_type == 'preset' && _value != null) {
      image = AssetImage(_value!);
    } else if (_type == 'gallery' && _value != null) {
      final file = File(_value!);
      if (!file.existsSync()) return null;
      image = FileImage(file);
    } else {
      return null;
    }

    return BoxDecoration(
      image: DecorationImage(
        image: image,
        fit: BoxFit.cover,
        colorFilter: _dim > 0
            ? ColorFilter.mode(
                Colors.black.withValues(alpha: _dim),
                BlendMode.darken,
              )
            : null,
      ),
    );
  }
}
