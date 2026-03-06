import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/bot_service.dart';
import '../services/story_service.dart';
import '../services/config_service.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import 'welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  final AuthService _authService = AuthService();
  final BotService _botService = BotService();
  final StoryService _storyService = StoryService();

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Fetch Dynamic Config First (API URL, Maintenance, & Version)
    await ConfigService.initConfig();

    if (ConfigService.needsUpdate) {
      if (!mounted) return;
      _showUpdateDialog();
      return;
    }

    if (ConfigService.isMaintenance) {
      if (!mounted) return;
      _showMaintenanceDialog();
      return;
    }

    // 2. Simultan: Cek Auth dan Warm-up Cache (Bots & Stories)
    final results = await Future.wait([
      _authService.isLoggedIn(),
      _botService.getBots(), 
      Future.delayed(const Duration(seconds: 2)), 
    ]);

    final bool isLoggedIn = results[0] as bool;
    final prefs = await SharedPreferences.getInstance();
    final bool isSetupCompleted = prefs.getBool('is_setup_completed') ?? false;

    // Check permissions
    bool permissionsGranted = true;
    if (isSetupCompleted && !kIsWeb) {
      final photoStatus = await Permission.photos.status;
      final notificationStatus = await Permission.notification.status;
      if (!photoStatus.isGranted || !notificationStatus.isGranted) {
        permissionsGranted = false;
      }
    }

    if (!mounted) return;

    // Pindah ke screen selanjutnya
    if (isLoggedIn) {
      if (isSetupCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Update Tersedia!',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Versi baru BlueTalk sudah rilis! Kamu perlu memperbarui aplikasi untuk terus menggunakan fitur terbaru.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              "Versi Terbaru: v${ConfigService.remoteVersion}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/rafiq8k-moga/bluetalk-app_repo/releases'),
              mode: LaunchMode.externalApplication,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF135ACF)),
            child: const Text('Download Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Pemeliharaan Sistem',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
        ),
        content: Text(
          ConfigService.maintenanceMsg,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Keluar Aplikasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB8D8F8), // Primary Color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Animasi Popup
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icon/icon.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Teks Blue Talk
            FadeTransition(
              opacity: _opacityAnimation,
              child: const Text(
                'Blue Talk',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
