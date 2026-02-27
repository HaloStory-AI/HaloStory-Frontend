import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCreateService {
  static const String _webPrefix = 'create_history_';
  static const String _webTimePrefix = 'create_time_';

  Future<String> _getStoragePath() async {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/BlueTalkData/Manual';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return path;
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> saveDialogue(String id, List<Map<String, dynamic>> messages, Map<String, dynamic> metadata) async {
    final data = {
      'metadata': metadata,
      'messages': messages,
    };
    final jsonContent = jsonEncode(data);
    
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webPrefix$id', jsonContent);
      await prefs.setString('$_webTimePrefix$id', DateTime.now().toIso8601String());
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$id.json');
      await file.writeAsString(jsonContent);
    } catch (e) {
      print('DEBUG: Error saving manual dialogue: $e');
    }
  }

  Future<Map<String, dynamic>?> loadDialogue(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_webPrefix$id');
      if (data != null) {
        return jsonDecode(data);
      }
      return null;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$id.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (e) {
      print('DEBUG: Error loading manual dialogue: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllDialoguesMetadata() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys()
          .where((key) => key.startsWith(_webPrefix))
          .map((key) {
            final id = key.replaceFirst(_webPrefix, '');
            final timeStr = prefs.getString('$_webTimePrefix$id');
            return {
              'id': id,
              'lastModified': timeStr != null ? DateTime.parse(timeStr) : DateTime.fromMillisecondsSinceEpoch(0),
            };
          }).toList();
    }

    try {
      final path = await _getStoragePath();
      final dir = Directory(path);
      if (await dir.exists()) {
        return dir.listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .map((file) => {
              'id': file.uri.pathSegments.last.replaceFirst('.json', ''),
              'lastModified': file.lastModifiedSync(),
            })
            .toList();
      }
    } catch (e) {
      print('DEBUG: Error listing manual dialogues: $e');
    }
    return [];
  }

  Future<void> deleteDialogue(String id) async {
     if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_webPrefix$id');
      await prefs.remove('$_webTimePrefix$id');
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$id.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('DEBUG: Error deleting dialogue: $e');
    }
  }
}
