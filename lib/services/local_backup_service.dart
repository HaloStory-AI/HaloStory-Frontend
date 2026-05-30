import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalBackupService {
  static const String _extension = 'hsai';
  static const String _filePrefix = 'halostory_backup_';

  static String _generateFileName() {
    final now = DateTime.now();
    final ts = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return '$_filePrefix$ts.$_extension';
  }

  static Future<bool> saveBackup(String encryptedData) async {
    if (kIsWeb) return false;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _generateFileName();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(encryptedData);

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        bytes: await tempFile.readAsBytes(),
      );

      await tempFile.delete();

      return savedPath != null;
    } catch (e) {
      debugPrint('LocalBackupService.saveBackup error: $e');
      return false;
    }
  }

  static Future<String?> pickBackup() async {
    if (kIsWeb) return null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [_extension],
        dialogTitle: 'Select Backup File',
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.bytes != null) {
        return String.fromCharCodes(file.bytes!);
      }
      if (file.path != null) {
        return await File(file.path!).readAsString();
      }
      return null;
    } catch (e) {
      debugPrint('LocalBackupService.pickBackup error: $e');
      return null;
    }
  }
}
