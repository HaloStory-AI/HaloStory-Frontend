import 'services/config_service.dart';

class AppConstants {
  static String get baseUrl => ConfigService.baseUrl;
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // For Android Emulator
  
  // This should match the API_STATIC_TOKEN in backend .env
  static const String staticToken = 'BlueTalkImportantAccessToAllEndpoint'; 
}
