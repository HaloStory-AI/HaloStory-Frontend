import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();

  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError(tr('forgot_password_otp_empty'));
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.forgotPassword(email);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() => _isOtpSent = true);
      _showSuccess(result['message'] ?? tr('forgot_password_otp_sent'));
    } else {
      _showError(result['message'] ?? tr('forgot_password_otp_failed'));
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.length != 6) {
      _showError(tr('reset_password_otp_length_error'));
      return;
    }
    if (password.length < 8) {
      _showError(tr('register_password_min_length'));
      return;
    }
    if (password != confirmPassword) {
      _showError(tr('register_passwords_not_match'));
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.resetPassword(
      email,
      otp,
      password,
      confirmPassword,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      _showSuccess(result['message'] ?? tr('reset_password_success'));
      Navigator.pop(context);
    } else {
      _showError(result['message'] ?? tr('reset_password_failed'));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildEmailStepForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('login_forgot_password'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('forgot_password_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: tr('login_email_hint'),
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    tr('forgot_password_send_otp'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetStepForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('reset_password_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            children: [
              TextSpan(text: '${tr('reset_password_otp_sent_to')}\n'),
              TextSpan(
                text: _emailController.text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: tr('reset_password_otp_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: tr('reset_password_new_password_hint'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isLoading) _resetPassword();
          },
          decoration: InputDecoration(
            labelText: tr('reset_password_confirm_password_hint'),
            prefixIcon: const Icon(Icons.lock_clock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    tr('reset_password_save_btn'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                tr('login_forgot_password'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('forgot_password_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
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
    final form = _isOtpSent
        ? _buildResetStepForm(colorScheme)
        : _buildEmailStepForm(colorScheme);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                          child: form,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: form,
                ),
              ),
      ),
    );
  }
}
