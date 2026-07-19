import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import 'verify_email_screen.dart';
import 'forgot_password_screen.dart';
import '../services/localization_service.dart';
import 'banned_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final result = await _authService.login(
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    bool isSuccess = result['success'] == true;
    if (isSuccess && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final bool isSetupCompleted =
          prefs.getBool('is_setup_completed') ?? false;

      if (!mounted) return;

      if (!_authService.isEmailVerified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
          (route) => false,
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              isSetupCompleted ? const HomeScreen() : const SetupScreen(),
        ),
        (route) => false,
      );
    } else if (result['banned'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BannedScreen()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? tr('login_failed'))));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('login_welcome_back'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('login_please_sign_in'),
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: tr('login_email_hint'),
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: tr('login_password_hint'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _handleLogin,
                  child: Text(tr('btn_login')),
                ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen(),
              ),
            );
          },
          child: Text(
            tr('login_forgot_password'),
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: Text(
            tr('login_dont_have_account'),
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SvgPicture.asset(
                  'assets/icon/HaloStory.svg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                tr('login_welcome_back'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('login_please_sign_in'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: SizedBox(
                          width: 400,
                          child: _buildForm(colorScheme),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: colorScheme.outlineVariant),
                  Expanded(
                    child: _buildRightPanel(colorScheme),
                  ),
                ],
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildForm(colorScheme),
                ),
              ),
      ),
    );
  }
}
