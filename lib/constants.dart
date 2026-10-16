import 'package:flutter/foundation.dart';
import 'services/config_service.dart';

class AppConstants {
  // Hardcoded string for development
  static const String _devBaseUrl = 'http://localhost:3000/api';

  // Use hardcoded for dev, and ConfigService (GitHub dynamic) for prod
  static String get baseUrl => kDebugMode ? _devBaseUrl : ConfigService.baseUrl;
  static String get apiUrl => baseUrl;

  static String get callUrl => '$baseUrl/v1/get-call';

  // This should match the API_STATIC_TOKEN in backend .env
  static const String staticToken = 'BlueTalkImportantAccessToAllEndpoint';
}
