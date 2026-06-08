import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _appLockEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      await _showSetupPinDialog();
    } else {
      await _showDisablePinDialog();
    }
  }

  Future<void> _showSetupPinDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PinSetupDialog(),
    );

    if (result == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_lock_enabled', true);
      setState(() => _appLockEnabled = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('pin_setup_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showDisablePinDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('pin_disable_confirm_title')),
        content: Text(tr('pin_disable_confirm_body')),
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
      setState(() => _appLockEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('pin_remove_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? colorScheme.surface : colorScheme.surfaceContainer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('settings_tab_privacy'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        tr('privacy_app_lock'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        tr('privacy_app_lock_desc'),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _appLockEnabled,
                      activeThumbColor: colorScheme.primary,
                      onChanged: _toggleAppLock,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  String _errorText = '';
  bool _isError = false;

  static const int _pinLength = 6;

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  void _onKeyPress(String digit) {
    if (_isConfirmStep) {
      if (_confirmPin.length >= _pinLength) return;
      HapticFeedback.lightImpact();
      setState(() {
        _confirmPin += digit;
        _isError = false;
      });
      if (_confirmPin.length == _pinLength) {
        _validatePins();
      }
    } else {
      if (_pin.length >= _pinLength) return;
      HapticFeedback.lightImpact();
      setState(() {
        _pin += digit;
        _isError = false;
      });
      if (_pin.length == _pinLength) {
        setState(() {
          _isConfirmStep = true;
        });
      }
    }
  }

  void _onDelete() {
    if (_isConfirmStep) {
      if (_confirmPin.isEmpty) return;
      HapticFeedback.lightImpact();
      setState(() {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        _isError = false;
      });
    } else {
      if (_pin.isEmpty) return;
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  void _validatePins() {
    if (_pin == _confirmPin) {
      HapticFeedback.mediumImpact();
      _savePin();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorText = tr('pin_setup_mismatch');
        _isError = true;
        _pin = '';
        _confirmPin = '';
        _isConfirmStep = false;
      });
    }
  }

  Future<void> _savePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lock_pin', _hashPin(_pin));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayPin = _isConfirmStep ? _confirmPin : _pin;

    return AlertDialog(
      title: Text(
        _isConfirmStep ? tr('pin_setup_confirm_title') : tr('pin_setup_title'),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isConfirmStep
                ? tr('pin_setup_confirm_subtitle')
                : tr('pin_setup_subtitle'),
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _DialogPinDots(
            length: _pinLength,
            filled: displayPin.length,
            isError: _isError,
          ),
          if (_isError) ...[
            const SizedBox(height: 8),
            Text(
              _errorText,
              style: TextStyle(fontSize: 12, color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          _DialogNumpad(
            onDigit: _onKeyPress,
            onDelete: _onDelete,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('dev_mode_cancel')),
        ),
      ],
    );
  }
}

class _DialogPinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool isError;

  const _DialogPinDots({
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        );
      }),
    );
  }
}

class _DialogNumpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _DialogNumpad({required this.onDigit, required this.onDelete});

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
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 56, height: 42);
              }
              if (key == 'DEL') {
                return SizedBox(
                  width: 56,
                  height: 42,
                  child: TextButton(
                    onPressed: onDelete,
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return SizedBox(
                width: 56,
                height: 42,
                child: TextButton(
                  onPressed: () => onDigit(key),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 18,
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
