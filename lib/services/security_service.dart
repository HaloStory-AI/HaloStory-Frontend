import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import '../constants.dart';

class SecurityService {
  static Future<bool> isDeviceCompromised() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        bool isJailBroken = await SafeDevice.isJailBroken;
        bool isRealDevice = await SafeDevice.isRealDevice;
        bool isSafeDevice = await SafeDevice.isSafeDevice;
        bool isDevelopmentModeEnable = false;

        if (Platform.isAndroid) {
          isDevelopmentModeEnable = await SafeDevice.isDevelopmentModeEnable;
        }

        // We consider the device compromised if it's rooted/jailbroken OR in dev mode
        return isJailBroken || isDevelopmentModeEnable || !isSafeDevice;
      }
    } catch (e) {
      debugPrint('Security check error: $e');
    }
    return false;
  }

  /// Encrypts plain text using AES-256 (CBC) with the app's static token.
  static String encryptData(String plainText) {
    // Generate a 32-byte key from staticToken using SHA-256
    final keyBytes = sha256.convert(utf8.encode(AppConstants.staticToken)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));

    // Generate a random 16-byte IV
    final iv = enc.IV.fromLength(16);

    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Format: base64(iv):base64(encrypted)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts AES-256 (CBC) encrypted text.
  static String decryptData(String encryptedText) {
    final parts = encryptedText.split(':');
    if (parts.length != 2) throw Exception("Invalid encrypted format");

    final iv = enc.IV.fromBase64(parts[0]);
    final encryptedData = parts[1];

    final keyBytes = sha256.convert(utf8.encode(AppConstants.staticToken)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));

    final encrypter = enc.Encrypter(enc.AES(key));
    return encrypter.decrypt64(encryptedData, iv: iv);
  }
}
