import 'package:flutter/material.dart';
import 'package:bluetalk_frontend/services/auth_service.dart';
import 'package:bluetalk_frontend/screens/login_screen.dart';
import 'package:bluetalk_frontend/screens/home_screen.dart';
import 'package:bluetalk_frontend/screens/welcome_screen.dart';

void main() {
  runApp(const BlueTalkApp());
}

class BlueTalkApp extends StatelessWidget {
  const BlueTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8D8F8),
          primary: const Color(0xFFB8D8F8),
          secondary: const Color(0xFF135ACF),
          surface: const Color(0xFFF4F8FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF135ACF),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF135ACF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF135ACF),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF135ACF), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final status = await _authService.isLoggedIn();
    print("DEBUG: Checking login status: $status");
    setState(() {
      _isLoggedIn = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isLoggedIn! ? const HomeScreen() : const WelcomeScreen();
  }
}
