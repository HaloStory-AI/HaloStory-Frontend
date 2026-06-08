import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';

class PinScreen extends StatefulWidget {
  final Widget target;

  const PinScreen({super.key, required this.target});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _input = '';
  bool _isError = false;
  int _wrongAttempts = 0;
  String _errorMessage = '';

  static const int _pinLength = 6;
  static const int _maxAttempts = 3;

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  void _onKeyPress(String digit) {
    if (_input.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _input += digit;
      _isError = false;
    });

    if (_input.length == _pinLength) {
      _validatePin();
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _isError = false;
    });
  }

  Future<void> _validatePin() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('app_lock_pin') ?? '';

    if (_hashPin(_input) == storedHash) {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.target),
      );
    } else {
      HapticFeedback.heavyImpact();
      _wrongAttempts++;
      if (_wrongAttempts >= _maxAttempts) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('pin_wrong_attempts')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          _input = '';
          _isError = false;
          _wrongAttempts = 0;
        });
        await Future.delayed(const Duration(seconds: 3));
      } else {
        setState(() {
          _isError = true;
          _errorMessage = tr('pin_wrong');
          _input = '';
        });
      }
    }
  }

  Future<void> _onForgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('pin_forgot_confirm_title')),
        content: Text(tr('pin_forgot_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('dev_mode_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('dev_mode_proceed')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_lock_pin');
      await prefs.setBool('app_lock_enabled', false);
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(
              Icons.lock_outline,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              tr('pin_title'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('pin_subtitle'),
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _PinDots(
              length: _pinLength,
              filled: _input.length,
              isError: _isError,
            ),
            if (_isError) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.error,
                ),
              ),
            ],
            const Spacer(flex: 2),
            _Numpad(
              onDigit: _onKeyPress,
              onDelete: _onDelete,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _onForgotPin,
              child: Text(
                tr('pin_forgot'),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool isError;

  const _PinDots({
    required this.length,
    required this.filled,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        Color dotColor;
        if (isError) {
          dotColor = colorScheme.error;
        } else if (isFilled) {
          dotColor = colorScheme.primary;
        } else {
          dotColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        );
      }),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _Numpad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', 'DEL'],
      ].map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 52);
              }
              if (key == 'DEL') {
                return SizedBox(
                  width: 72,
                  height: 52,
                  child: TextButton(
                    onPressed: onDelete,
                    child: Icon(
                      Icons.backspace_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return SizedBox(
                width: 72,
                height: 52,
                child: TextButton(
                  onPressed: () => onDigit(key),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
