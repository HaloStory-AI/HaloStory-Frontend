import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'google_config.dart';

class GoogleService {
  GoogleSignIn? _googleSignIn;
  bool _initialized = false;

  String? lastRedirectUri;
  String? get lastClientId => (kIsWeb || Platform.isAndroid || Platform.isIOS) ? GoogleConfig.webClientId : GoogleConfig.desktopClientId;
  String? get lastClientSecret => (kIsWeb || Platform.isAndroid || Platform.isIOS) ? null : GoogleConfig.desktopClientSecret;

  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/drive.file',
    'email',
    'profile',
  ];

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      _googleSignIn = GoogleSignIn(
        scopes: _scopes,
        serverClientId: GoogleConfig.webClientId,
        forceCodeForRefreshToken: true,
      );
    }
  }

  Future<String?> getAuthCode() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      return await _getMobileAuthCode();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await _getDesktopAuthCode();
    }
    return null;
  }

  Future<String?> _getMobileAuthCode() async {
    try {
      if (_googleSignIn == null) await init();

      await _googleSignIn!.signOut();

      final account = await _googleSignIn!.signIn();
      if (account == null) return null;

      final authCode = account.serverAuthCode;
      return authCode;
    } catch (e) {
      print('Mobile Auth Code Error: $e');
      return null;
    }
  }

  Future<String?> _getDesktopAuthCode() async {
    HttpServer? redirectServer;
    StreamSubscription<HttpRequest>? requestSubscription;

    try {
      redirectServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirectPort = redirectServer.port;
      final redirectUri = 'http://127.0.0.1:$redirectPort';
      lastRedirectUri = redirectUri;

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': GoogleConfig.desktopClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
      });

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch browser for OAuth');
      }

      final Completer<String?> authCodeCompleter = Completer<String?>();

      requestSubscription = redirectServer.listen((HttpRequest request) async {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''
          <!DOCTYPE html>
          <html>
          <head><title>Authentication Complete</title></head>
          <body style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;background-color:#121212;color:#ffffff;">
            <h2>${code != null ? "Authentication Successful! You can close this window." : "Authentication Failed or Cancelled."}</h2>
            <script>setTimeout(function(){ window.close(); }, 2000);</script>
          </body>
          </html>
        ''');
        await request.response.close();

        if (!authCodeCompleter.isCompleted) {
          if (code != null) {
            authCodeCompleter.complete(code);
          } else {
            authCodeCompleter.completeError(error ?? 'User denied access');
          }
        }
      });

      final authCode = await authCodeCompleter.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );

      return authCode;
    } catch (e) {
      print('Desktop Auth Code Error: $e');
      return null;
    } finally {
      await requestSubscription?.cancel();
      await redirectServer?.close(force: true);
    }
  }

  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
  }
}














// import 'dart:async';
// import 'dart:convert';
// import 'dart:io' show Platform;
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:googleapis/drive/v3.dart' as drive;
// import 'package:googleapis_auth/auth_io.dart' as auth;
// import 'package:googleapis_auth/googleapis_auth.dart' as auth_base;
// import 'package:http/http.dart' as http;
// import 'package:url_launcher/url_launcher.dart';
// import 'google_drive_config.dart';

// class GoogleDriveService {
//   static const String _refreshTokenKey = 'google_drive_credentials';

//   GoogleSignIn? _googleSignIn;
//   drive.DriveApi? _driveApi;
//   auth.AutoRefreshingAuthClient? _authClient;
//   bool _initialized = false;

//   Future<bool> get isSignedIn async => await _googleSignIn!.isSignedIn();
//   Future<void> dissconnect() async {
//     _googleSignIn!.disconnect();
//   }

//   Future<void> init() async {
//     if (_initialized) return;
//     _initialized = true;

//     if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
//       final String? _ = kIsWeb
//           ? GoogleDriveConfig.webClientId
//           : Platform.isIOS
//               ? GoogleDriveConfig.iosClientId
//               : null;
//       _googleSignIn = GoogleSignIn(
//         scopes: ['email', 'profile', 'https://www.googleapis.com/auth/drive.file'],
//         // clientId: clientId,
//         serverClientId: GoogleDriveConfig.webClientId,
//         forceCodeForRefreshToken: true,
//       );
//     } else {
//       await _restoreStoredSession();
//     }
//   }

//   Future<String?> signIn() async {
//     if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
//       try {
//         final account = await _googleSignIn!.signIn();
//         if (account == null) return null;
//         return account.serverAuthCode;
//       } catch (e) {
//         print(e);
//         return null;
//       }
//     } else {
//       try {
//         final clientId = auth_base.ClientId(
//           GoogleDriveConfig.desktopClientId,
//           GoogleDriveConfig.desktopClientSecret,
//         );
//         final scopes = [drive.DriveApi.driveFileScope, 'https://www.googleapis.com/auth/drive.appdata'];

//         final client = await auth.clientViaUserConsent(
//           clientId,
//           scopes,
//           (url) => _openBrowser(url),
//         );

//         _authClient = client;
//         _driveApi = drive.DriveApi(client);

//         await _saveCredentials(client.credentials);
//         final about = await _driveApi!.about.get();
//         return about.user?.emailAddress;
//       } catch (e) {
//         return null;
//       }
//     }
//   }

//   Future<void> signOut() async {
//     if (_googleSignIn != null) {
//       await _googleSignIn!.signOut();
//     }
//     await _clearStoredSession();
//   }

//   Future<List<drive.File>> listBackups() async {
//     if (_driveApi == null) return [];
//     try {
//       final response = await _driveApi!.files.list(
//         q: "name contains 'HaloStory_Backup_' and trashed = false",
//         orderBy: 'createdTime desc',
//         pageSize: 20,
//         spaces: 'appDataFolder',
//       );
//       return response.files ?? [];
//     } catch (_) {
//       return [];
//     }
//   }

//   Future<bool> uploadBackup(String encryptedData) async {
//     if (_driveApi == null) return false;
//     try {
//       final timestamp = DateTime.now()
//           .toIso8601String()
//           .replaceAll(RegExp(r'[:.]'), '-');
//       final fileName = 'HaloStory_Backup_$timestamp.hsai.enc';
//       final bytes = utf8.encode(encryptedData);

//       final stream = http.ByteStream.fromBytes(bytes);
//       final media = drive.Media(stream, bytes.length,
//           contentType: 'application/octet-stream');

//       final file = drive.File()
//         ..name = fileName
//         ..parents = ['appDataFolder']
//         ..mimeType = 'application/octet-stream'
//         ..description = 'HaloStory backup created at $timestamp';

//       await _driveApi!.files.create(file, uploadMedia: media);
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<String?> downloadBackup(String fileId) async {
//     if (_driveApi == null) return null;
//     try {
//       final response = await _driveApi!.files.get(
//         fileId,
//         downloadOptions: drive.DownloadOptions.fullMedia,
//       );

//       if (response is drive.Media) {
//         final chunks = await response.stream.toList();
//         final bytes = <int>[];
//         for (final chunk in chunks) {
//           bytes.addAll(chunk);
//         }
//         return utf8.decode(bytes);
//       }
//       return null;
//     } catch (_) {
//       return null;
//     }
//   }

//   Future<bool> deleteBackup(String fileId) async {
//     if (_driveApi == null) return false;
//     try {
//       await _driveApi!.files.delete(fileId);
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<void> _restoreStoredSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     final stored = prefs.getString(_refreshTokenKey);
//     if (stored == null || stored.isEmpty) return;

//     try {
//       final credsMap = jsonDecode(stored) as Map<String, dynamic>;
//       final expiryStr = credsMap['expiry'] as String?;
//       final expiry = expiryStr != null
//           ? DateTime.parse(expiryStr).toUtc()
//           : DateTime.now().toUtc().add(const Duration(hours: 1));
//       final accessToken = auth_base.AccessToken(
//         credsMap['token_type'] as String? ?? 'Bearer',
//         credsMap['access_token'] as String? ?? '',
//         expiry,
//       );
//       final creds = auth_base.AccessCredentials(
//         accessToken,
//         credsMap['refresh_token'] as String?,
//         List<String>.from(credsMap['scopes'] as List? ?? []),
//         idToken: credsMap['id_token'] as String?,
//       );

//       final oauthClientId = auth_base.ClientId(
//         GoogleDriveConfig.desktopClientId,
//         GoogleDriveConfig.desktopClientSecret,
//       );
//       final httpClient = http.Client();

//       _authClient = auth_base.autoRefreshingClient(
//         oauthClientId,
//         creds,
//         httpClient,
//       );
//       _driveApi = drive.DriveApi(_authClient!);
//     } catch (_) {
//       await _clearStoredSession();
//     }
//   }

//   Future<void> _saveCredentials(auth_base.AccessCredentials creds) async {
//     final prefs = await SharedPreferences.getInstance();
//     final data = jsonEncode({
//       'access_token': creds.accessToken.data,
//       'token_type': creds.accessToken.type,
//       'expiry': creds.accessToken.expiry.toIso8601String(),
//       'refresh_token': creds.refreshToken,
//       'scopes': creds.scopes,
//       'id_token': creds.idToken,
//     });
//     await prefs.setString(_refreshTokenKey, data);
//   }

//   Future<void> _clearStoredSession() async {
//     _driveApi = null;
//     _authClient?.close();
//     _authClient = null;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(_refreshTokenKey);
//   }

//   void _openBrowser(String url) {
//     launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
//   }

//   void dispose() {
//     _authClient?.close();
//     _authClient = null;
//     _driveApi = null;
//   }
// }