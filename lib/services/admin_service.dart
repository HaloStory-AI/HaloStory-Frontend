import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class AdminService {
  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${AppConstants.staticToken}',
    };
  }

  // --- USERS ---
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/users'),
        headers: _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('AdminService getUsers error: $e');
      }
    }
    return [];
  }

  Future<bool> changeUserRole(int id, String role) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/admin/users/$id/role'),
        headers: _headers(),
        body: jsonEncode({'role': role}),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('AdminService changeUserRole error: $e');
      }
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/admin/users/$id'),
        headers: _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('AdminService deleteUser error: $e');
      }
      return false;
    }
  }

  // --- BOTS ---
  Future<List<dynamic>> getBots() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/bots'),
        headers: _headers(),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      if (kDebugMode) {
        print('AdminService getBots error: $e');
      }
    }
    return [];
  }

  Future<bool> createBot(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/bots'),
        headers: _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('AdminService createBot error: $e');
      }
      return false;
    }
  }

  Future<bool> updateBot(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/admin/bots/$id'),
        headers: _headers(),
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('AdminService updateBot error: $e');
      }
      return false;
    }
  }

  Future<bool> deleteBot(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/admin/bots/$id'),
        headers: _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('AdminService deleteBot error: $e');
      }
      return false;
    }
  }
}
