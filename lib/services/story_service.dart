import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'auth_service.dart';
import 'local_chat_service.dart';
import 'bot_service.dart';

class StoryService {
  final LocalChatService _localChatService = LocalChatService();
  final BotService _botService = BotService();
  final AuthService _authService = AuthService();

  static const String _seenPrefix = 'story_seen_';

  // --- MEMORY DATA ---
  // "Lepas cache jika sudah close aplikasi" -> simpan di variabel static (memory).
  static List<Map<String, dynamic>>? _cachedStories;
  static DateTime? _lastFetchTime;
  static DateTime? _lastManualReload;

  Future<List<Map<String, dynamic>>> getStories({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // 1. Logic COOLDOWN 5 Menit untuk Manual Reload
    if (forceRefresh && _lastManualReload != null) {
      final diff = now.difference(_lastManualReload!);
      if (diff.inMinutes < 5) {
        print("DEBUG: Reload Stories is on cooldown. ${5 - diff.inMinutes} mins left.");
        return _cachedStories ?? [];
      }
    }

    // 2. Logic AUTO-REFRESH 30 Menit (Silent/Lazy) atau Hit DB jika Kosong
    bool shouldFetch = false;

    if (forceRefresh) {
      shouldFetch = true;
    } else if (_cachedStories == null) {
      shouldFetch = true;
    } else if (_lastFetchTime != null) {
      // Jika sudah lebih dari 30 menit sejak fetch terakhir, kita update datanya.
      if (now.difference(_lastFetchTime!).inMinutes >= 30) {
        shouldFetch = true;
      }
    }

    if (!shouldFetch) {
      return _cachedStories!;
    }

    // 3. HIT DATABASE (Backend tidak pakai cache, jadi Live DB)
    print("DEBUG: Fetching stories from DB (Live)...");

    try {
      final allChats = await _localChatService.getAllChatMetadata();
      if (allChats.isEmpty) {
        _cachedStories = [];
        return [];
      }

      allChats.sort((a, b) => (b['lastModified'] as DateTime).compareTo(a['lastModified'] as DateTime));

      final allBots = await _botService.getBots();
      final botMap = {for (var b in allBots) b['id']: b};

      final orderedBotIds = allChats
          .map((c) => c['id'] as String)
          .where((id) => botMap.containsKey(id) && botMap[id]!['sbr'] != null)
          .toList();

      if (orderedBotIds.isEmpty) {
        _cachedStories = [];
        return [];
      }

      final token = await _authService.getToken();
      if (token == null) return _cachedStories ?? [];

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/stories/fetch-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'fetch_status': orderedBotIds}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        final freshStories = data.map((item) {
          final bot = botMap[item['bot_id']];
          return <String, dynamic>{
            ...Map<String, dynamic>.from(item),
            'bot_avatar': bot?['image_url'],
          };
        }).toList();

        // Sort by LATEST story timestamp (Like WhatsApp)
        // Groups bots first
        Map<String, DateTime> botLatestMap = {};
        for (var s in freshStories) {
          final dt = DateTime.parse(s['created_at']);
          if (botLatestMap[s['bot_id']] == null || dt.isAfter(botLatestMap[s['bot_id']]!)) {
            botLatestMap[s['bot_id']] = dt;
          }
        }

        freshStories.sort((a, b) {
          final aTime = botLatestMap[a['bot_id']]!;
          final bTime = botLatestMap[b['bot_id']]!;
          
          if (aTime != bTime) {
            return bTime.compareTo(aTime); // Newest bot first
          }

          // Then internal sequence (Oldest to Newest within a bot)
          return DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']));
        });

        // Update tracking
        _cachedStories = freshStories;
        _lastFetchTime = now;
        if (forceRefresh) {
          _lastManualReload = now;
        }

        return freshStories;
      }
    } catch (e) {
      print('DEBUG: StoryService Refresh Error: $e');
    }

    return _cachedStories ?? [];
  }

  // Mendapatkan waktu sisa cooldown reload dalam detik
  int getReloadCooldownSeconds() {
    if (_lastManualReload == null) return 0;
    final diff = DateTime.now().difference(_lastManualReload!);
    final remaining = 300 - diff.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> markAsSeen(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenPrefix$storyId', true);
  }

  Future<bool> isSeen(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenPrefix$storyId') ?? false;
  }

  // --- LOCAL CACHING HELPER ---
  Future<File?> getLocalMedia(String url) async {
    if (kIsWeb) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/.statustemp');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final fileName = url.split('/').last;
      final localFile = File('${cacheDir.path}/$fileName');

      if (localFile.existsSync()) {
        return localFile;
      }

      // Download
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        return localFile;
      }
    } catch (e) {
      print("DEBUG: Local Cache Error: $e");
    }
    return null;
  }
}
