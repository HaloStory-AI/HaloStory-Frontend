import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../services/bot_service.dart';
import '../services/config_service.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import 'welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final AuthService _authService = AuthService();
  final BotService _botService = BotService();

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

    // 2. Request Permissions (Requested by user to be forced here)
    await _requestPermissions();

    // 3. Simultan: Cek Auth dan Warm-up Cache (Bots & Stories)
    final results = await Future.wait([
      _authService.isLoggedIn(),
      _botService.getBots(),
      Future.delayed(const Duration(seconds: 2)),
    ]);

    final bool isLoggedIn = results[0] as bool;
    final prefs = await SharedPreferences.getInstance();
    final bool isSetupCompleted = prefs.getBool('is_setup_completed') ?? false;

    // 3. Navigate
    if (!mounted) return;

    if (isLoggedIn) {
      // Show notice about email security (0.8.0 requirement)
      await _showEmailNotice();
      if (!mounted) return;

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

  Future<void> _showEmailNotice() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/image/notice_image.png',
                height: 200,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('splash_email_notice_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF135ACF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('splash_email_notice_body'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A5568),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _LoadingNoticeButton(
              onPressed: () async {
                // Simulasi delay sedikit agar user melihat loading (opsional)
                // atau jika ada proses async lain di masa depan.
                // Untuk saat ini kita hanya menutup dialog.
                await Future.delayed(
                  const Duration(milliseconds: 500),
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    await [
      Permission.photos,
      Permission.storage,
      Permission.notification,
      Permission.manageExternalStorage, // Penting untuk menyimpan file ke folder Download
    ].request();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('update_title'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF135ACF),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('update_desc'), style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Text(
              "${tr('update_version')}: v${ConfigService.remoteVersion}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => launchUrl(
              Uri.parse('https://bluetalk.my-bini.my.id/download'),
              mode: LaunchMode.externalApplication,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135ACF),
            ),
            child: Text(
              tr('update_btn'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/image/maintenance_image.png',
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('maintenance_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('maintenance_info'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              ConfigService.maintenanceMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tr('exit_app'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
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
                        color: Colors.black.withValues(alpha: 0.1),
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

class _LoadingNoticeButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const _LoadingNoticeButton({required this.onPressed});

  @override
  State<_LoadingNoticeButton> createState() => _LoadingNoticeButtonState();
}

class _LoadingNoticeButtonState extends State<_LoadingNoticeButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              await widget.onPressed();
              if (mounted) setState(() => _isLoading = false);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF0F5FF),
        foregroundColor: const Color(0xFF135ACF),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF135ACF),
              ),
            )
          : Text(
              tr('system_notice_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
    );
  }
}
