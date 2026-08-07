import 'package:bluetalk_frontend/screens/banned_screen.dart';
import 'package:bluetalk_frontend/screens/home_screen.dart';
import 'package:bluetalk_frontend/screens/setup_screen.dart';
import 'package:bluetalk_frontend/services/auth_service.dart';
import 'package:bluetalk_frontend/services/google_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreen();
}

class _WelcomeScreen extends State<WelcomeScreen> {
  final GoogleService _googleOauth = GoogleService();
  final _authService = AuthService();

  bool _gdLoading = false;

  @override
  void initState() {
    super.initState();
    _initGoogle();
  }

  Future<void> _initGoogle() async {
    await _googleOauth.init();
  }

  Future<void> _googleOauthSignIn() async {
    setState(() => _gdLoading = true);

    final authCode = await _googleOauth.getAuthCode();
    if (!mounted) return;
    if (authCode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('login_failed'))));

      if (!mounted) return;

      setState(() {
        _gdLoading = false;
      });
      return;
    }

    final result = await _authService.sendAuthCode(
      authCode,
      AuthType.EXCHANGE,
      redirectUri: _googleOauth.lastRedirectUri,
      clientId: _googleOauth.lastClientId,
      clientSecret: _googleOauth.lastClientSecret,
    );
    bool isSuccess = result['success'] == true;
    if (isSuccess && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final bool isSetupCompleted =
          prefs.getBool('is_setup_completed') ?? false;

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              isSetupCompleted ? const HomeScreen() : const SetupScreen(),
        ),
        (route) => false,
      );
    } else if (result['banned'] == true) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BannedScreen()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? tr('login_failed'))),
      );
    }

    if (!mounted) return;

    setState(() {
      _gdLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: SafeArea(
        child: isDesktop
            ? _buildDesktop(context, colorScheme)
            : _buildMobile(context, colorScheme),
      ),
    );
  }

  Widget _buildLogo(ColorScheme colorScheme) {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 0,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SvgPicture.asset('assets/icon/HaloStory.svg', fit: BoxFit.contain),
    );
  }

  Widget _buildWelcomeText(ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          tr('welcome_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('welcome_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLogo(colorScheme),
                  const SizedBox(height: 40),
                  _buildWelcomeText(colorScheme),
                  const SizedBox(height: 16),
                  Text(
                    tr('welcome_made_by'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(width: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: Container(
            color: colorScheme.surfaceContainer,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('welcome_ready'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 280,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(tr('btn_login')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: colorScheme.primary,
                        ),
                        child: Text(tr('btn_register')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogo(colorScheme),
            const SizedBox(height: 40),
            _buildWelcomeText(colorScheme),
            const SizedBox(height: 16),
            Text(
              tr('welcome_made_by'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _gdLoading
                    ? null
                    : () async {
                        _googleOauthSignIn();
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF747775), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _gdLoading
                    ? const SizedBox(
                        height: 25,
                        width: 25,
                        child: CircularProgressIndicator(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/image/google_logo.png',
                            height: 24,
                            width: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Sign in with Google",
                            style: TextStyle(
                              color: Color(0xFF1F1F1F),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                const Text(
                  "OR",
                  style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(tr('btn_login')),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: colorScheme.primary,
                ),
                child: Text(tr('btn_register')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
