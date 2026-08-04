import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';

class StudentRequestService {
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> getRequests() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/student-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching student requests: $e');
      }
    }
    return [];
  }

  Future<bool> submitRequest(String studentName) async {
    final token = await _authService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/student-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'student_name': studentName}),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting student request: $e');
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> checkStudent(String studentName) async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/student-request/check'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'student_name': studentName}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking student: $e');
      }
    }
    return [];
  }
}
