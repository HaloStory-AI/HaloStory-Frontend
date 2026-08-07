import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  static final BottomNavProvider _instance = BottomNavProvider._internal();
  factory BottomNavProvider() => _instance;
  BottomNavProvider._internal();

  int _currentIndex = 0;
  String? _email;

  int get currentIndex => _currentIndex;
  String? get email => _email;

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }
}