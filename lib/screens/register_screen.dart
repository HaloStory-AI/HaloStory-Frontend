import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('btn_register'))),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: tr('register_full_name_hint'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: tr('login_email_hint'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: tr('login_password_hint'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  hintText: tr('register_confirm_password_hint'),
                  prefixIcon: const Icon(Icons.lock_reset),
                ),
                obscureText: true,
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
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black87,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(text: tr('register_terms_agree')),
                          TextSpan(
                            text: tr('register_terms_tos'),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _launchURL(
                                "https://bluetalk.my-bini.my.id/terms",
                              ),
                          ),
                          TextSpan(text: tr('register_terms_and')),
                          TextSpan(
                            text: tr('register_terms_privacy'),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _launchURL(
                                "https://bluetalk.my-bini.my.id/privacy",
                              ),
                          ),
                          TextSpan(text: tr('register_terms_suffix')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleRegister,
                      child: Text(tr('btn_register')),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
