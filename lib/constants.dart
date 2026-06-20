import 'package:flutter/foundation.dart';
import 'services/config_service.dart';

class AppConstants {
  // Hardcoded string for development
  static const String _devBaseUrl = 'https://api-hsaiapp.my-bini.my.id/api';

  // Use hardcoded for dev, and ConfigService (GitHub dynamic) for prod
  static String get baseUrl => kDebugMode ? _devBaseUrl : ConfigService.baseUrl;
  static String get apiUrl => baseUrl;

  static String get chatSystemUrl => '$baseUrl/ai/chat/system';
  static String get chatByokUrl => '$baseUrl/ai/chat/byok';
  static String get chatSummarizeUrl => '$baseUrl/ai/summarize';
  static String get byomPromptUrl => '$baseUrl/ai/system-prompt';

  static String get callUrl => '$baseUrl/v1/get-call';

  // This should match the API_STATIC_TOKEN in backend .env
  static const String staticToken = 'BlueTalkImportantAccessToAllEndpoint';
}
