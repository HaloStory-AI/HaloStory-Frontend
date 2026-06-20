import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';

class StoryService {
  final AuthService _authService = AuthService();

  static const String _seenPrefix = 'story_seen_';

  static List<Map<String, dynamic>>? _cachedStories;
  static DateTime? _lastFetchTime;

  Future<List<Map<String, dynamic>>> getStories() async {
    final now = DateTime.now();
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/v1/stories'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final freshStories = List<Map<String, dynamic>>.from(data);

        Map<String, DateTime> botLatestMap = {};
        for (var s in freshStories) {
          final dt = DateTime.parse(s['created_at']);
          if (botLatestMap[s['bot_id']] == null ||
              dt.isAfter(botLatestMap[s['bot_id']]!)) {
            botLatestMap[s['bot_id']] = dt;
          }
        }

        freshStories.sort((a, b) {
          final aTime = botLatestMap[a['bot_id']]!;
          final bTime = botLatestMap[b['bot_id']]!;
          if (aTime != bTime) return bTime.compareTo(aTime);
          return DateTime.parse(
            a['created_at'],
          ).compareTo(DateTime.parse(b['created_at']));
        });

        _cachedStories = freshStories;
        _lastFetchTime = now;

        return freshStories;
      }
    } catch (e) {
      print('DEBUG: getStories Error: $e');
    }
    return _cachedStories ?? [];
  }



  Future<void> markAsSeen(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenPrefix$storyId', true);
  }

  Future<bool> isSeen(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenPrefix$storyId') ?? false;
  }

  // --- PERSISTENT CACHING ---
  Future<Directory> _getCacheDir() async {
    if (kIsWeb) throw UnsupportedError("Web not supported for local caching");

    // Use getTemporaryDirectory() — works on ALL Android versions without any
    // storage permission. OS cleans it up automatically when storage is low.
    // Perfect for temp story media (short-lived cache anyway).
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/bluetalk_story_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<File?> getLocalMedia(String url) async {
    if (kIsWeb) return null;
    try {
      final cacheDir = await _getCacheDir();
      _cleanupOldCache(cacheDir);

      final fileName = url.split('/').last.split('?').first;
      final localFile = File('${cacheDir.path}/$fileName');

      // Hanya kembalikan file jika sudah ada di cache (didownload oleh getMediaDownloadProgress).
      // Jangan download lagi di sini — cukup baca hasil cache saja.
      if (localFile.existsSync() && localFile.lengthSync() > 0) {
        return localFile;
      }
    } catch (e) {
      print("DEBUG: Local Cache Read Error: $e");
    }
    return null;
  }

  // Stream for Progress Tracking
  Stream<double> getMediaDownloadProgress(String url) async* {
    if (kIsWeb) {
      yield 1.0;
      return;
    }

    final cacheDir = await _getCacheDir();
    final fileName = url.split('/').last.split('?').first;
    final localFile = File('${cacheDir.path}/$fileName');

    if (localFile.existsSync() && localFile.lengthSync() > 0) {
      yield 1.0;
      return;
    }

    // Yield 0.0 to indicate download started (fixes stuck at 0%)
    yield 0.0;

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));

      final total = response.contentLength ?? 0;
      int received = 0;
      final List<int> bytes = [];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) {
          double p = received / total;
          if (p >= 0.99)
            p = 0.99; // Cap so we don't break stream early before saving
          yield p;
        } else {
          // Indeterminate progress - server didn't provide content length
          yield -2.0;
        }
      }

      await localFile.writeAsBytes(bytes, flush: true);
      client.close();
      yield 1.0;
    } catch (e) {
      print("DEBUG: Download Stream Error: $e");
      yield -1.0; // Error indicator
    }
  }

  Future<void> _cleanupOldCache(Directory cacheDir) async {
    try {
      final now = DateTime.now();
      final List<FileSystemEntity> files = cacheDir.listSync();

      for (var file in files) {
        if (file is File) {
          final stat = file.statSync();
          final diff = now.difference(stat.modified);

          if (diff.inHours >= 24) {
            print("DEBUG: Cleaning up old story cache: ${file.path}");
            await file.delete();
          }
        }
      }
    } catch (e) {
      print("DEBUG: Cleanup Cache Error: $e");
    }
  }

  // Optimize saving: Move/Copy if already in cache
  Future<String?> getCachedPath(String url) async {
    if (kIsWeb) return null;
    final cacheDir = await _getCacheDir();
    final fileName = url.split('/').last.split('?').first;
    final localFile = File('${cacheDir.path}/$fileName');
    if (localFile.existsSync()) {
      return localFile.path;
    }
    return null;
  }

  Future<Directory> _getDocumentsDir() async {
    if (Platform.isWindows) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/HaloStory-Memories');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '/tmp';
      final dir = Directory('$home/Documents/HaloStory-Memories');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    throw UnsupportedError("Platform not supported for Documents save");
  }

  Future<bool> saveMediaToGallery(String url) async {
    if (kIsWeb) return false;
    try {
      String? filePath = await getCachedPath(url);
      if (filePath == null) {
        final cacheDir = await _getCacheDir();
        final fileName = url.split('/').last.split('?').first;
        final localFile = File('${cacheDir.path}/$fileName');

        final client = http.Client();
        final request = http.Request('GET', Uri.parse(url));
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 45));

        final List<int> bytes = [];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
        }

        await localFile.writeAsBytes(bytes, flush: true);
        client.close();
        filePath = localFile.path;
      }

      final isVideo = url.toLowerCase().endsWith('.mp4') ||
          url.toLowerCase().endsWith('.mov') ||
          url.toLowerCase().endsWith('.avi') ||
          url.toLowerCase().endsWith('.webm');

      if (Platform.isAndroid) {
        if (isVideo) {
          await Gal.putVideo(filePath);
        } else {
          await Gal.putImage(filePath);
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        final docsDir = await _getDocumentsDir();
        final fileName = url.split('/').last.split('?').first;
        await File(filePath).copy('${docsDir.path}/$fileName');
      } else {
        return false;
      }
      return true;
    } catch (e) {
      print("DEBUG: Save to Gallery Error: $e");
      return false;
    }
  }
}
