import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class P2PSyncService {
  static HttpServer? _server;
  static Timer? _timeoutTimer;

  static String _generateToken() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // --- DESKTOP: SERVER METHODS ---

  /// Starts the HTTP Server on Desktop.
  /// [mode] can be 'upload' (Desktop expecting to receive data) or 'download' (Desktop providing data).
  static Future<String> startHost({
    required String mode,
    required Future<Map<String, dynamic>> Function() getDownloadPayload,
    required Function(Map<String, dynamic> payload) onUploadReceived,
    required VoidCallback onTimeout,
  }) async {
    await stopHost();
    
    // Find local IP
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    
    InternetAddress? hostAddress;
    // Prefer Wi-Fi/WLAN network interfaces if available
    for (var interface in interfaces) {
      if (interface.name.toLowerCase().contains('wi-fi') || interface.name.toLowerCase().contains('wlan')) {
        hostAddress = interface.addresses.first;
        break;
      }
    }
    if (hostAddress == null && interfaces.isNotEmpty) {
      hostAddress = interfaces.first.addresses.first;
    }
    
    if (hostAddress == null) {
      throw Exception('Local network interface not found. Connect to Wi-Fi.');
    }

    // Bind on any available port (0) or specify a fixed port.
    _server = await HttpServer.bind(hostAddress, 0); 
    final token = _generateToken();
    
    _timeoutTimer = Timer(const Duration(minutes: 5), () {
      stopHost();
      onTimeout();
    });

    _server!.listen((HttpRequest request) async {
      // Basic CORS
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type');

      if (request.method == 'OPTIONS') {
         request.response.statusCode = 200;
         await request.response.close();
         return;
      }

      final uri = request.uri;
      final qToken = uri.queryParameters['token'];
      
      if (qToken != token) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write(jsonEncode({'error': 'Invalid Token'}));
        await request.response.close();
        return;
      }

      if (uri.path == '/download' && request.method == 'GET') {
         try {
           final payload = await getDownloadPayload();
           request.response.statusCode = HttpStatus.ok;
           request.response.headers.contentType = ContentType.json;
           request.response.write(jsonEncode(payload));
         } catch (e) {
           request.response.statusCode = HttpStatus.internalServerError;
           request.response.write(jsonEncode({'error': e.toString()}));
         }
         await request.response.close();
         
         // After successful download to mobile, we can stop hosting shortly
         Future.delayed(const Duration(seconds: 3), () {
           stopHost();
           // Optionally notify someone about successful download completion
         });

      } else if (uri.path == '/upload' && request.method == 'POST') {
         try {
           final content = await utf8.decoder.bind(request).join();
           final payload = jsonDecode(content);
           
           request.response.statusCode = HttpStatus.ok;
           request.response.write(jsonEncode({'success': true}));
           await request.response.close();

           // Notify callback immediately
           onUploadReceived(payload);
           
           stopHost();
         } catch (e) {
           request.response.statusCode = HttpStatus.badRequest;
           request.response.write(jsonEncode({'error': e.toString()}));
           await request.response.close();
         }
      } else {
         request.response.statusCode = HttpStatus.notFound;
         await request.response.close();
      }
    });

    return 'http://${hostAddress.address}:${_server!.port}/$mode?token=$token';
  }

  static Future<void> stopHost() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  // --- MOBILE: CLIENT METHODS ---

  static Future<Map<String, dynamic>?> syncWithDesktop(String qrUrl, {Map<String, dynamic>? payloadToUpload}) async {
    final uri = Uri.parse(qrUrl);
    
    if (uri.path == '/download') {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Download failed code: ${response.statusCode} / ${response.body}');
    } else if (uri.path == '/upload') {
      if (payloadToUpload == null) throw Exception('Payload is empty!');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payloadToUpload),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return {'success': true};
      }
      throw Exception('Upload failed code: ${response.statusCode} / ${response.body}');
    }

    throw Exception('Invalid sync QR Code');
  }
}
