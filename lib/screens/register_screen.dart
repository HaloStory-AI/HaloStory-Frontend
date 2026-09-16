import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../widgets/auth/glass_auth_card.dart';
import '../widgets/auth/starry_auth_scaffold.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import 'verify_email_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isAgreed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('register_password_min_length'))),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('register_passwords_not_match'))),
      );
      return;
    }

    if (!_isAgreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('register_agree_required'))));
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
      _confirmPasswordController.text,
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
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'] ?? tr('register_failed'))));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildForm() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('btn_register'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: tr('register_full_name_hint'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
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
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: tr('register_confirm_password_hint'),
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleRegister(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _isAgreed,
              onChanged: (val) {
                setState(() {
                  _isAgreed = val ?? false;
                });
              },
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(text: tr('register_terms_agree')),
                    TextSpan(
                      text: tr('register_terms_tos'),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _launchURL(
                          "https://s.my-bini.my.id/hs-terms-of-service",
                        ),
                    ),
                    TextSpan(text: tr('register_terms_comma')),
                    TextSpan(
                      text: tr('register_terms_privacy'),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _launchURL(
                          "https://s.my-bini.my.id/hs-privacy-policy",
                        ),
                    ),
                    TextSpan(text: tr('register_terms_and')),
                    TextSpan(
                      text: tr('register_terms_sfw'),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _launchURL(
                          "https://s.my-bini.my.id/hs-sfw-policy",
                        ),
                    ),
                    TextSpan(text: tr('register_terms_suffix')),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: _handleRegister,
                  child: Text(tr('btn_register')),
                ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            tr('register_have_account'),
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
