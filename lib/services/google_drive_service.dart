import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis_auth/googleapis_auth.dart' as auth_base;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'google_drive_config.dart';

class GoogleDriveService {
  static const String _refreshTokenKey = 'google_drive_credentials';

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  auth.AutoRefreshingAuthClient? _authClient;
  bool _initialized = false;

  bool get isSignedIn => _driveApi != null;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      final String? clientId = kIsWeb
          ? GoogleDriveConfig.webClientId
          : Platform.isIOS
              ? GoogleDriveConfig.iosClientId
              : null;
      _googleSignIn = GoogleSignIn(
        scopes: [drive.DriveApi.driveFileScope, 'https://www.googleapis.com/auth/drive.appdata'],
        clientId: clientId,
      );

      if (await _googleSignIn!.isSignedIn()) {
        final account = _googleSignIn!.currentUser;
        if (account != null) {
          final authHeaders = await account.authHeaders;
          final client = _GoogleAuthClient(authHeaders);
          _driveApi = drive.DriveApi(client);
        }
      }
    } else {
      await _restoreStoredSession();
    }
  }

  Future<String?> signIn() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      try {
        final account = await _googleSignIn!.signIn();
        if (account == null) return null;
        final authHeaders = await account.authHeaders;
        final client = _GoogleAuthClient(authHeaders);
        _driveApi = drive.DriveApi(client);
        return account.email;
      } catch (e) {
        return null;
      }
    } else {
      try {
        final clientId = auth_base.ClientId(
          GoogleDriveConfig.desktopClientId,
          GoogleDriveConfig.desktopClientSecret,
        );
        final scopes = [drive.DriveApi.driveFileScope, 'https://www.googleapis.com/auth/drive.appdata'];

        final client = await auth.clientViaUserConsent(
          clientId,
          scopes,
          (url) => _openBrowser(url),
        );

        _authClient = client;
        _driveApi = drive.DriveApi(client);

        await _saveCredentials(client.credentials);
        final about = await _driveApi!.about.get();
        return about.user?.emailAddress;
      } catch (e) {
        return null;
      }
    }
  }

  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    await _clearStoredSession();
  }

  Future<List<drive.File>> listBackups() async {
    if (_driveApi == null) return [];
    try {
      final response = await _driveApi!.files.list(
        q: "name contains 'HaloStory_Backup_' and trashed = false",
        orderBy: 'createdTime desc',
        pageSize: 20,
        spaces: 'appDataFolder',
      );
      return response.files ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> uploadBackup(String encryptedData) async {
    if (_driveApi == null) return false;
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final fileName = 'HaloStory_Backup_$timestamp.hsai.enc';
      final bytes = utf8.encode(encryptedData);

      final stream = http.ByteStream.fromBytes(bytes);
      final media = drive.Media(stream, bytes.length,
          contentType: 'application/octet-stream');

      final file = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder']
        ..mimeType = 'application/octet-stream'
        ..description = 'HaloStory backup created at $timestamp';

      await _driveApi!.files.create(file, uploadMedia: media);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> downloadBackup(String fileId) async {
    if (_driveApi == null) return null;
    try {
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        final chunks = await response.stream.toList();
        final bytes = <int>[];
        for (final chunk in chunks) {
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteBackup(String fileId) async {
    if (_driveApi == null) return false;
    try {
      await _driveApi!.files.delete(fileId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _restoreStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_refreshTokenKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final credsMap = jsonDecode(stored) as Map<String, dynamic>;
      final expiryStr = credsMap['expiry'] as String?;
      final expiry = expiryStr != null
          ? DateTime.parse(expiryStr).toUtc()
          : DateTime.now().toUtc().add(const Duration(hours: 1));
      final accessToken = auth_base.AccessToken(
        credsMap['token_type'] as String? ?? 'Bearer',
        credsMap['access_token'] as String? ?? '',
        expiry,
      );
      final creds = auth_base.AccessCredentials(
        accessToken,
        credsMap['refresh_token'] as String?,
        List<String>.from(credsMap['scopes'] as List? ?? []),
        idToken: credsMap['id_token'] as String?,
      );

      final oauthClientId = auth_base.ClientId(
        GoogleDriveConfig.desktopClientId,
        GoogleDriveConfig.desktopClientSecret,
      );
      final httpClient = http.Client();

      _authClient = auth_base.autoRefreshingClient(
        oauthClientId,
        creds,
        httpClient,
      );
      _driveApi = drive.DriveApi(_authClient!);
    } catch (_) {
      await _clearStoredSession();
    }
  }

  Future<void> _saveCredentials(auth_base.AccessCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'access_token': creds.accessToken.data,
      'token_type': creds.accessToken.type,
      'expiry': creds.accessToken.expiry.toIso8601String(),
      'refresh_token': creds.refreshToken,
      'scopes': creds.scopes,
      'id_token': creds.idToken,
    });
    await prefs.setString(_refreshTokenKey, data);
  }

  Future<void> _clearStoredSession() async {
    _driveApi = null;
    _authClient?.close();
    _authClient = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshTokenKey);
  }

  void _openBrowser(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void dispose() {
    _authClient?.close();
    _authClient = null;
    _driveApi = null;
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _httpClient = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _httpClient.send(request);
  }
}
