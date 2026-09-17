import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';

/// Wrapper terpusat untuk request authenticated.
/// - Ambil token via getValidAccessToken (auto refresh jika <60s exp).
/// - On 401 → refreshTokens() → retry sekali.
/// Adopsi incremental: ganti callsite http.* bertahap ke ApiClient.
class ApiClient {
  static final AuthService _auth = AuthService();

  static Map<String, String> _headers(String? token, Map<String, String>? extra) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  static Future<http.Response> _withRetry(
    Future<http.Response> Function(String? token) doRequest,
  ) async {
    var token = await _auth.getValidAccessToken();
    var resp = await doRequest(token);
    if (resp.statusCode == 401) {
      final ok = await _auth.refreshTokens();
      if (ok) {
        token = await _auth.getValidAccessToken();
        resp = await doRequest(token);
      }
    }
    return resp;
  }

  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    bool auth = true,
  }) {
    if (!auth) {
      return http.get(Uri.parse('${AppConstants.baseUrl}$path'), headers: _headers(null, headers));
    }
    return _withRetry((token) => http.get(
          Uri.parse('${AppConstants.baseUrl}$path'),
          headers: _headers(token, headers),
        ));
  }

  static Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool auth = true,
  }) {
    final encoded = body == null ? null : (body is String ? body : jsonEncode(body));
    if (!auth) {
      return http.post(Uri.parse('${AppConstants.baseUrl}$path'), headers: _headers(null, headers), body: encoded);
    }
    return _withRetry((token) => http.post(
          Uri.parse('${AppConstants.baseUrl}$path'),
          headers: _headers(token, headers),
          body: encoded,
        ));
  }

  static Future<http.Response> postWithStaticToken(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) {
    return http.post(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${AppConstants.staticToken}',
        ...?headers,
      },
      body: body == null ? null : (body is String ? body : jsonEncode(body)),
    );
  }
}
