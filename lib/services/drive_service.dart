import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';
import 'config_service.dart';

class DriveService {
  final AuthService _authService = AuthService();

  Future<bool> uploadtoDrive(String data) async {
    final token = await _authService.getToken();
    if (token == null) return true;

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/drive-backup'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'data': data,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // final result = jsonDecode(response.body);
        return true;
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: 503 (Maintenance)");
        }
      } else {
        if (kDebugMode) {
          print("DEBUG: Failed to fetch check has_google_auth: ${response.statusCode}");
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching has_google_auth: $e");
      }
      // Return local cache if available during network issues
      return false;
    }

    return false;
  }

  Future<List<dynamic>> listDriveFile() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/user/drive-list'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (kDebugMode) {
          print("DEBUG: $result");
        }
        return result;
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: 503 (Maintenance)");
        }
      } else {
        if (kDebugMode) {
          print("DEBUG: Failed to fetch check has_google_auth: ${response.statusCode}");
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching has_google_auth: $e");
      }
      // Return local cache if available during network issues
      return [];
    }

    return [];
  }

  Future<String?> downloadDriveFile(String fileID) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/user/drive-download'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'file_id': fileID,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (kDebugMode) {
          print("DEBUG: $result");
        }
        return result["data"];
      } else if (response.statusCode == 503) {
        ConfigService.enterMaintenance();
        if (kDebugMode) {
          print("DEBUG: Failed to fetch profile: 503 (Maintenance)");
        }
      } else {
        if (kDebugMode) {
          print("DEBUG: Failed to fetch check has_google_auth: ${response.statusCode}");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("DEBUG: Error fetching has_google_auth: $e");
      }
      // Return local cache if available during network issues
      return null;
    }

    return null;
  }
}