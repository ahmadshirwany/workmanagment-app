import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_data.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  static const String _lastSyncKey = 'last_cloud_sync';
  static const String _autoSyncKey = 'auto_sync_enabled';
  static const String _backupFileName = 'discipline_tracker_backup.json';
  static const String _appFolderName = 'DisciplineTracker';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;

  // Current user info
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.displayName;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  bool get isAvailable => true; // Always available - no server setup needed

  // Try to restore previous sign-in silently
  Future<void> tryAutoSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (e) {
      print('Silent sign-in failed: $e');
    }
  }

  // Sign in with Google
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  // Get authenticated Drive API client
  Future<drive.DriveApi> _getDriveApi() async {
    if (_currentUser == null) {
      throw Exception('Not signed in');
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw Exception('Failed to get authenticated client');
    }

    return drive.DriveApi(httpClient);
  }

  // Find or create app folder in Google Drive
  Future<String> _getOrCreateAppFolder(drive.DriveApi driveApi) async {
    // Search for existing folder
    final folderQuery = "name = '$_appFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final folderList = await driveApi.files.list(q: folderQuery, spaces: 'drive');

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      return folderList.files!.first.id!;
    }

    // Create new folder
    final folder = drive.File()
      ..name = _appFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await driveApi.files.create(folder);
    return createdFolder.id!;
  }

  // Find backup file in app folder
  Future<String?> _findBackupFile(drive.DriveApi driveApi, String folderId) async {
    final query = "name = '$_backupFileName' and '$folderId' in parents and trashed = false";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');

    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }
    return null;
  }

  // Upload data to Google Drive
  Future<void> uploadData(AppData data) async {
    if (!isSignedIn) {
      throw Exception('Please sign in first');
    }

    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getOrCreateAppFolder(driveApi);

      // Prepare JSON data
      final jsonData = data.toJson();
      jsonData['_syncMeta'] = {
        'lastModified': DateTime.now().toIso8601String(),
        'email': userEmail,
        'deviceInfo': 'Flutter App',
      };

      final content = utf8.encode(jsonEncode(jsonData));
      final media = drive.Media(
        Stream.value(content),
        content.length,
        contentType: 'application/json',
      );

      // Check if file already exists
      final existingFileId = await _findBackupFile(driveApi, folderId);

      if (existingFileId != null) {
        // Update existing file
        await driveApi.files.update(
          drive.File()..name = _backupFileName,
          existingFileId,
          uploadMedia: media,
        );
      } else {
        // Create new file
        final file = drive.File()
          ..name = _backupFileName
          ..parents = [folderId];

        await driveApi.files.create(
          file,
          uploadMedia: media,
        );
      }

      // Save last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Upload error: $e');
      rethrow;
    }
  }

  // Download data from Google Drive
  Future<AppData?> downloadData() async {
    if (!isSignedIn) {
      throw Exception('Please sign in first');
    }

    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getOrCreateAppFolder(driveApi);
      final fileId = await _findBackupFile(driveApi, folderId);

      if (fileId == null) {
        return null; // No backup found
      }

      // Download file content
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }

      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Remove sync metadata
      jsonData.remove('_syncMeta');

      // Save last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      return AppData.fromJson(jsonData);
    } catch (e) {
      print('Download error: $e');
      rethrow;
    }
  }

  // Check if backup exists on Drive
  Future<bool> hasCloudData() async {
    if (!isSignedIn) return false;

    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getOrCreateAppFolder(driveApi);
      final fileId = await _findBackupFile(driveApi, folderId);
      return fileId != null;
    } catch (e) {
      return false;
    }
  }

  // Get cloud data last modified time
  Future<DateTime?> getCloudLastModified() async {
    if (!isSignedIn) return null;

    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getOrCreateAppFolder(driveApi);
      
      final query = "name = '$_backupFileName' and '$folderId' in parents and trashed = false";
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get last sync time
  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  // Check availability (always true for Google Drive)
  Future<bool> checkAvailability() async {
    return true;
  }

  // Auto sync settings
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? false;
  }

  Future<void> setAutoSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }

  // Delete cloud data
  Future<void> deleteCloudData() async {
    if (!isSignedIn) {
      throw Exception('Please sign in first');
    }

    try {
      final driveApi = await _getDriveApi();
      final folderId = await _getOrCreateAppFolder(driveApi);
      final fileId = await _findBackupFile(driveApi, folderId);

      if (fileId != null) {
        await driveApi.files.delete(fileId);
      }
    } catch (e) {
      print('Delete error: $e');
      rethrow;
    }
  }
}
