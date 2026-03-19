import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

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
}
