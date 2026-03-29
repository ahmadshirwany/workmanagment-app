import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/app_data.dart';

class StorageService {
  static const String _dataKey = 'app_data';
  static const int _maxBackups = 10;

  Future<void> saveData(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(data.toJson());
    await prefs.setString(_dataKey, jsonString);
    
    // Auto-backup
    await _createBackup(jsonString);
  }

  Future<AppData> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_dataKey);
    
    if (jsonString == null) {
      return AppData.empty();
    }
    
    try {
      final jsonData = jsonDecode(jsonString);
      return AppData.fromJson(jsonData);
    } catch (e) {
      print('Error loading data: $e');
      return AppData.empty();
    }
  }

  Future<void> _createBackup(String jsonString) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File('${backupDir.path}/backup_$timestamp.json');
      await backupFile.writeAsString(jsonString);

      // Clean old backups
      await _cleanOldBackups(backupDir);
      
      // Update last backup timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error creating backup: $e');
    }
  }

  Future<void> _cleanOldBackups(Directory backupDir) async {
    try {
      final files = await backupDir.list().toList();
      final backupFiles = files.whereType<File>().toList();
      
      if (backupFiles.length > _maxBackups) {
        backupFiles.sort((a, b) => a.path.compareTo(b.path));
        final filesToDelete = backupFiles.sublist(0, backupFiles.length - _maxBackups);
        
        for (final file in filesToDelete) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error cleaning old backups: $e');
    }
  }

  Future<String?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_backup');
  }

  Future<String> exportData(AppData data) async {
    try {
      // Try to get Downloads directory, fall back to Documents if not available
      Directory? directory;
      
      // For Windows, use Downloads directory
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          directory = Directory('$userProfile\\Downloads');
        }
      } else if (Platform.isAndroid) {
        // For Android, use Downloads directory
        directory = Directory('/storage/emulated/0/Download');
      } else {
        // Fall back to Documents directory for other platforms
        directory = await getApplicationDocumentsDirectory();
      }
      
      // Ensure directory exists
      if (directory != null && !await directory.exists()) {
        // If Downloads doesn't exist, fall back to Documents
        directory = await getApplicationDocumentsDirectory();
      }
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory!.path}${Platform.pathSeparator}discipline_tracker_export_$timestamp.json');
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(data.toJson());
      await file.writeAsString(jsonString);
      
      return file.path;
    } catch (e) {
      throw Exception('Export failed: $e');
    }
  }

  Future<AppData> importData(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);
      return AppData.fromJson(jsonData);
    } catch (e) {
      throw Exception('Import failed: $e');
    }
  }

  Future<List<File>> getBackupFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      
      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      return files.whereType<File>().toList();
    } catch (e) {
      return [];
    }
  }
}
