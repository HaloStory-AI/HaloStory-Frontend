import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_chat_service.dart';
import 'bot_service.dart';

class StoryService {
  final LocalChatService _localChatService = LocalChatService();
  final BotService _botService = BotService();
  
  static const String _seenPrefix = 'story_seen_';
  static const String _lastUpdateKey = 'stories_last_update_';
  static const String _cachedStoriesKey = 'cached_stories_data';

  Future<String> _getStoragePath() async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/BlueTalkData/statustemp';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  // Fetch images from Safebooru based on 'sbr' tag
  Future<List<Map<String, dynamic>>> getStories() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString('global_stories_timestamp');
    final cachedJson = prefs.getString(_cachedStoriesKey);
    final now = DateTime.now();

    // 1. Logic for Fixed 4-Hour Intervals
    // Intervals: 0, 4, 8, 12, 16, 20
    int currentHour = now.hour;
    int lastIntervalHour = (currentHour ~/ 4) * 4;
    DateTime lastIntervalTime = DateTime(now.year, now.month, now.day, lastIntervalHour);

    bool isIntervalExpired = false;
    if (lastUpdateStr != null) {
      DateTime lastUpdate = DateTime.parse(lastUpdateStr);
      if (lastUpdate.isBefore(lastIntervalTime)) {
        isIntervalExpired = true;
      }
    } else {
      isIntervalExpired = true;
    }

    // 2. Logic for New Bots (Immediate appearance after chat)
    final allBots = await _botService.getBots();
    final activeChats = await _localChatService.getAllChatMetadata();
    final activeChatIds = activeChats.map((e) => e['id']).toSet();

    List<Map<String, dynamic>> cachedStories = [];
    if (cachedJson != null) {
      cachedStories = List<Map<String, dynamic>>.from(jsonDecode(cachedJson));
    }
    
    final cachedBotIds = cachedStories.map((e) => e['bot_id']).toSet();
    final storyBots = allBots.where((b) => activeChatIds.contains(b['id']) && b['sbr'] != null).toList();
    
    // Check if there are any active bots NOT in cache
    bool hasNewBot = storyBots.any((b) => !cachedBotIds.contains(b['id']));

    // Decide if we should refresh
    if (!isIntervalExpired && !hasNewBot && cachedStories.isNotEmpty) {
      return cachedStories;
    }

    // Refresh Logic
    List<Map<String, dynamic>> newStoriesList = [];

    for (var bot in storyBots) {
      // If it's not interval expired, we keep the old story if it exists
      if (!isIntervalExpired && cachedBotIds.contains(bot['id'])) {
        final existing = cachedStories.firstWhere((s) => s['bot_id'] == bot['id']);
        newStoriesList.add(existing);
        continue;
      }

      final sbrTag = bot['sbr'];
      try {
        final response = await http.get(Uri.parse(
          'https://safebooru.donmai.us/posts.json?tags=$sbrTag+order:random&limit=1'
        ));

        if (response.statusCode == 200) {
          final List<dynamic> posts = jsonDecode(response.body);
          if (posts.isNotEmpty) {
            final post = posts[0];
            final imageUrl = post['file_url'] ?? post['large_file_url'] ?? post['preview_file_url'];
            
            if (imageUrl != null) {
              newStoriesList.add({
                'bot_id': bot['id'],
                'bot_name': bot['name'],
                'bot_avatar': bot['image_url'],
                'image_url': imageUrl,
                'timestamp': now.toIso8601String(),
                'id': post['id'].toString(),
              });
            }
          }
        }
      } catch (e) {
        print('DEBUG: Story Service Error: $e');
      }
    }

    if (newStoriesList.isNotEmpty) {
      await prefs.setString('global_stories_timestamp', now.toIso8601String());
      await prefs.setString(_cachedStoriesKey, jsonEncode(newStoriesList));
    }

    return newStoriesList;
  }

  Future<void> markAsSeen(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_seenPrefix$storyId', true);
  }

  Future<bool> isSeen(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_seenPrefix$storyId') ?? false;
  }

  // Cleanup old stories (simplified: just clear cache if expired over 24h)
  Future<void> cleanupExpiredStories() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdateStr = prefs.getString('global_stories_timestamp');
    if (lastUpdateStr != null) {
      final now = DateTime.now();
      final lastUpdate = DateTime.parse(lastUpdateStr);
      if (now.difference(lastUpdate).inHours >= 24) {
        await prefs.remove(_cachedStoriesKey);
        await prefs.remove('global_stories_timestamp');
      }
    }
  }
}
