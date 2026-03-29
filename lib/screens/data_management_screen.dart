import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_data_provider.dart';
import '../services/cloud_sync_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> with SingleTickerProviderStateMixin {
  String? _lastBackupTime;
  bool _isLoading = false;
  
  // Cloud sync state
  final CloudSyncService _cloudSync = CloudSyncService();
  bool _isSignedIn = false;
  String? _userEmail;
  DateTime? _lastCloudSync;
  bool _autoSyncEnabled = false;
  bool _cloudLoading = false;
  bool _firebaseAvailable = false;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLastBackupTime();
    _loadCloudSyncStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCloudSyncStatus() async {
    // Try auto sign-in first
    await _cloudSync.tryAutoSignIn();
    
    final isSignedIn = _cloudSync.isSignedIn;
    final autoSync = await _cloudSync.isAutoSyncEnabled();
    final lastSyncStr = await _cloudSync.getLastSyncTime();
    DateTime? lastSync;
    if (lastSyncStr != null) {
      try {
        lastSync = DateTime.parse(lastSyncStr);
      } catch (_) {}
    }
    
    if (mounted) {
      setState(() {
        _firebaseAvailable = true; // Google Drive is always available
        _isSignedIn = isSignedIn;
        _userEmail = _cloudSync.userEmail;
        _autoSyncEnabled = autoSync;
        _lastCloudSync = lastSync;
      });
    }
  }

  Future<void> _loadLastBackupTime() async {
    final provider = Provider.of<AppDataProvider>(context, listen: false);
    final lastBackup = await provider.getLastBackupTime();
    
    if (mounted) {
      setState(() {
        _lastBackupTime = lastBackup;
      });
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AppDataProvider>(context, listen: false);
      final filePath = await provider.exportData();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported successfully!\n$filePath'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    // Use file picker to select a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select backup file to import',
    );

    if (result == null || result.files.single.path == null) {
      return; // User canceled the picker
    }

    final filePath = result.files.single.path!;

    // Confirm import
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Import'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will replace all current data. Are you sure?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'File: ${result.files.single.name}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF44336),
                foregroundColor: Colors.white,
              ),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AppDataProvider>(context, listen: false);
      await provider.importData(filePath);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data imported successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        await _loadLastBackupTime();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  String _formatBackupTime(String? isoString) {
    if (isoString == null) return 'Never';
    
    try {
      final dateTime = DateTime.parse(isoString);
      return DateFormat('MMM d, y - h:mm a').format(dateTime);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    return DateFormat('MMM d, y - h:mm a').format(dateTime);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _cloudLoading = true);
    
    try {
      final account = await _cloudSync.signInWithGoogle();
      
      if (account != null && mounted) {
        setState(() {
          _isSignedIn = true;
          _userEmail = account.email;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as ${account.email}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        
        await _loadCloudSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _cloudSync.signOut();
    
    if (mounted) {
      setState(() {
        _isSignedIn = false;
        _userEmail = null;
        _lastCloudSync = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out'),
          backgroundColor: Color(0xFF2196F3),
        ),
      );
    }
  }

  Future<void> _uploadToCloud() async {
    setState(() => _cloudLoading = true);
    
    try {
      final provider = Provider.of<AppDataProvider>(context, listen: false);
      final data = provider.getCurrentData();
      
      await _cloudSync.uploadData(data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data uploaded to cloud successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        await _loadCloudSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
    }
  }

  Future<void> _downloadFromCloud() async {
    // Check if cloud data exists
    final hasCloudData = await _cloudSync.hasCloudData();
    
    if (!hasCloudData) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cloud data found'),
            backgroundColor: Color(0xFFFF9800),
          ),
        );
      }
      return;
    }
    
    // Confirm download
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download from Cloud'),
          content: const Text(
            'This will replace all current data with cloud data. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
    
    if (confirm != true) return;
    
    setState(() => _cloudLoading = true);
    
    try {
      final cloudData = await _cloudSync.downloadData();
      
      if (cloudData != null && mounted) {
        final provider = Provider.of<AppDataProvider>(context, listen: false);
        await provider.importAppData(cloudData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data downloaded from cloud successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        
        await _loadCloudSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    await _cloudSync.setAutoSync(value);
    setState(() => _autoSyncEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom header
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.7),
                        const Color(0xFF4CAF50),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // App bar row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const Expanded(
                                child: Text(
                                  'Data Management',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Icon and subtitle
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.backup_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Backup, restore & sync your data',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tab bar
                        TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          indicatorWeight: 3,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.folder_rounded, size: 20),
                              text: 'Local',
                            ),
                            Tab(
                              icon: Icon(Icons.cloud_rounded, size: 20),
                              text: 'Cloud',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLocalBackupTab(),
                      _buildCloudSyncTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLocalBackupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildGradientCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Auto-Backup',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBackupTime(_lastBackupTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent[100],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Export Card
          _buildActionCard(
            icon: Icons.download_rounded,
            iconColor: const Color(0xFF4CAF50),
            title: 'Export Data',
            subtitle: 'Save to Downloads folder',
            onTap: _exportData,
          ),
          
          const SizedBox(height: 12),
          
          // Import Card
          _buildActionCard(
            icon: Icons.upload_rounded,
            iconColor: const Color(0xFF2196F3),
            title: 'Import Data',
            subtitle: 'Restore from backup file',
            onTap: _importData,
          ),
          
          const SizedBox(height: 24),
          
          // Tips Section
          _buildTipsCard(
            title: 'Backup Tips',
            icon: Icons.lightbulb_outline,
            iconColor: const Color(0xFFFF9800),
            tips: const [
              'Auto-backup saves your data on every change',
              'Last 10 local backups are kept automatically',
              'Export creates a file in your Downloads folder',
              'Use Import to restore from any backup file',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSyncTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_cloudLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Syncing...'),
                  ],
                ),
              ),
            )
          else if (!_isSignedIn) ...[
            // Check if platform supports Google Sign-In
            if (Platform.isWindows || Platform.isLinux) ...[
              _buildGradientCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Available on Mobile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Google Drive sync is available on\nAndroid and iOS devices',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
            // Not signed in - show welcome card
            _buildGradientCard(
              gradient: const LinearGradient(
                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_to_drive_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Google Drive Sync',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Back up to your Google Drive for free\nSync across all your devices',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],  // close platform if/else
          ] else ...[
            // Signed in - show account and sync options
            _buildGradientCard(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.green[100],
                          child: Text(
                            (_userEmail ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: Colors.greenAccent[100],
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Connected',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded),
                        color: Colors.white,
                        tooltip: 'Sign Out',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Last sync: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatDateTime(_lastCloudSync),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Auto Sync Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SwitchListTile(
                  title: const Text(
                    'Auto Sync',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Sync automatically when data changes'),
                  value: _autoSyncEnabled,
                  onChanged: _toggleAutoSync,
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _autoSyncEnabled 
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sync_rounded,
                      color: _autoSyncEnabled 
                          ? const Color(0xFF4CAF50)
                          : Colors.grey,
                    ),
                  ),
                  activeColor: const Color(0xFF4CAF50),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Sync Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Sync action buttons in a row
            Row(
              children: [
                Expanded(
                  child: _buildSyncButton(
                    icon: Icons.cloud_upload_rounded,
                    label: 'Upload',
                    color: const Color(0xFF4CAF50),
                    onTap: _uploadToCloud,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSyncButton(
                    icon: Icons.cloud_download_rounded,
                    label: 'Download',
                    color: const Color(0xFF2196F3),
                    onTap: _downloadFromCloud,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Cloud Tips
          _buildTipsCard(
            title: 'Google Drive Sync',
            icon: Icons.cloud_done_outlined,
            iconColor: const Color(0xFF4CAF50),
            tips: const [
              'Free — uses your Google Drive storage',
              'No server setup — just sign in and sync',
              'Data saved as a file in your Drive',
              'Access your data from any device',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientCard({
    required Gradient gradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: color.withOpacity(0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> tips,
  }) {
    return Card(
      elevation: 0,
      color: iconColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: iconColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
