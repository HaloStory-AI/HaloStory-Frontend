import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/auth/glass_auth_card.dart';
import '../widgets/auth/starry_auth_scaffold.dart';
import '../utils/no_animation_route.dart';
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

  Widget _buildForm() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('login_welcome_back'),
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('login_please_sign_in'),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF9CA8BC)),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: tr('login_email_hint'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: tr('login_password_hint'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
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
              : FilledButton(
                  onPressed: _handleLogin,
                  child: Text(tr('btn_login')),
                ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              noAnimationRoute(const ForgotPasswordScreen()),
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
              noAnimationRoute(const RegisterScreen()),
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

  @override
  Widget build(BuildContext context) {
    return StarryAuthScaffold(
      child: GlassAuthCard(child: _buildForm()),
    );
  }
}
