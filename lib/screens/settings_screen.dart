import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../providers/app_data_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _notificationsEnabled = false;
  int _selectedInterval = 4;
  int? _customInterval;
  final TextEditingController _customIntervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _customIntervalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notificationService.areNotificationsEnabled();
    final interval = await _notificationService.getReminderInterval();
    final custom = await _notificationService.getCustomInterval();

    setState(() {
      _notificationsEnabled = enabled;
      _selectedInterval = interval;
      _customInterval = custom;
      if (custom != null) {
        _customIntervalController.text = custom.toString();
      }
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    await _notificationService.setNotificationsEnabled(value);
    setState(() {
      _notificationsEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Notifications enabled! You\'ll receive reminders.'
                : 'Notifications disabled.',
          ),
          backgroundColor: value ? const Color(0xFF4CAF50) : Colors.grey,
        ),
      );
    }
  }

  Future<void> _setInterval(int hours) async {
    await _notificationService.setReminderInterval(hours);
    await _notificationService.setCustomInterval(null);
    setState(() {
      _selectedInterval = hours;
      _customInterval = null;
      _customIntervalController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder interval set to $hours hour${hours > 1 ? 's' : ''}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  Future<void> _setCustomInterval() async {
    final minutes = int.tryParse(_customIntervalController.text);
    if (minutes == null || minutes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of minutes'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      return;
    }

    await _notificationService.setCustomInterval(minutes);
    setState(() {
      _customInterval = minutes;
      _selectedInterval = -1; // Custom option
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Custom interval set to $minutes minute${minutes > 1 ? 's' : ''}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: Color(0xFF2196F3),
        ),
      );
    }
  }

  Future<void> _confirmResetAllData() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFF44336)),
            SizedBox(width: 12),
            Text('Reset All Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️  This action cannot be undone!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF44336),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• All habits'),
            const SizedBox(height: 4),
            const Text('• All daily tasks'),
            const SizedBox(height: 4),
            const Text('• All work sessions'),
            const SizedBox(height: 4),
            const Text('• All reflections'),
            const SizedBox(height: 4),
            const Text('• All goals and notes'),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to continue?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppDataProvider>().resetAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ All data has been reset'),
                    backgroundColor: Color(0xFF4CAF50),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset All Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBatterySettings() async {
    try {
      const platform = MethodChannel('com.example.discipline_tracker/settings');
      await platform.invokeMethod('openBatteryOptimization');
    } catch (e) {
      // Fallback - show instructions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Go to Settings → Apps → Discipline Tracker → Battery → Unrestricted'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _viewScheduledNotifications() async {
    final pending = await _notificationService.getPendingNotifications();
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Color(0xFF2196F3)),
            SizedBox(width: 12),
            Text('Scheduled Notifications'),
          ],
        ),
        content: pending.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '❌ No notifications are currently scheduled.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Troubleshooting steps:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Make sure notifications are enabled above',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '2. Go to Phone Settings → Apps → Discipline Tracker → Permissions',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '3. Enable "Notifications" and "Alarms & Reminders"',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '4. Disable battery optimization for this app',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '5. Turn off "Do Not Disturb" mode',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✅ ${pending.length} notifications scheduled',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pending.length,
                      itemBuilder: (context, index) {
                        final notification = pending[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            notification.title ?? 'No title',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            notification.body ?? 'No description',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        actions: [
          if (pending.isEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                // Try to reschedule
                if (_notificationsEnabled) {
                  await _notificationService.setNotificationsEnabled(false);
                  await Future.delayed(const Duration(milliseconds: 500));
                  await _notificationService.setNotificationsEnabled(true);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Notifications reset. Check your phone settings if still not working.'),
                      backgroundColor: Color(0xFF4CAF50),
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              label: const Text('Reset Notifications'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.settings,
            size: 60,
            color: Color(0xFF2196F3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Notification Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Enable/Disable Notifications
          Card(
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              title: const Text(
                'Enable Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Receive reminders to update your daily data'),
              secondary: Icon(
                _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                color: _notificationsEnabled ? const Color(0xFF4CAF50) : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Battery Optimization Warning
          if (_notificationsEnabled)
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Important for Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'To ensure scheduled notifications work reliably:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Disable Battery Optimization for this app'),
                    const Text('2. Allow "Alarms & Reminders" permission'),
                    const Text('3. Don\'t force close the app'),
                    const Text('4. Check DND (Do Not Disturb) settings'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openBatterySettings,
                        icon: const Icon(Icons.battery_saver, color: Colors.orange),
                        label: const Text('Open Battery Settings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Reminder Interval Section
          if (_notificationsEnabled) ...[
            const Text(
              'Reminder Interval',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Predefined Intervals
            _buildIntervalOption(1, '1 Hour'),
            _buildIntervalOption(2, '2 Hours'),
            _buildIntervalOption(4, '4 Hours'),
            _buildIntervalOption(8, '8 Hours'),

            const SizedBox(height: 16),

            // Custom Interval
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Radio<int>(
                          value: -1,
                          groupValue: _selectedInterval,
                          onChanged: (value) {
                            setState(() {
                              _selectedInterval = -1;
                            });
                          },
                        ),
                        const Text(
                          'Custom Interval',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customIntervalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., 30, 90, 180',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _setCustomInterval,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Set'),
                        ),
                      ],
                    ),
                    if (_customInterval != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current: $_customInterval minute${_customInterval! > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Test Notification Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testNotification,
                icon: const Icon(Icons.notifications),
                label: const Text('Send Test Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),

            // View Scheduled Notifications Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _viewScheduledNotifications,
                icon: const Icon(Icons.schedule),
                label: const Text('View Scheduled Notifications'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  side: const BorderSide(color: Color(0xFF2196F3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Reset Data Section
          Card(
            color: const Color(0xFFF44336).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.delete_forever, color: Color(0xFFF44336)),
                      SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF44336),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Permanently delete all your data',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.maxFinite,
                    child: ElevatedButton.icon(
                      onPressed: _confirmResetAllData,
                      icon: const Icon(Icons.warning, size: 20),
                      label: const Text('Reset All Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF44336),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info Card
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Color(0xFFFF9800)),
                      SizedBox(width: 8),
                      Text(
                        'Important: Enable Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For notifications to work on Android 12+:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Go to Phone Settings → Apps → Discipline Tracker',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '2. Tap "Permissions" or "Notifications"',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '3. Enable "Notifications" permission',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '4. Enable "Alarms & Reminders" permission',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '5. Battery → Allow background activity',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF9800)),
                    ),
                    child: const Text(
                      '⚠️ Without "Alarms & Reminders" permission, scheduled notifications will NOT work!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF9800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalOption(int hours, String label) {
    return Card(
      child: RadioListTile<int>(
        value: hours,
        groupValue: _selectedInterval,
        onChanged: (value) {
          if (value != null) {
            _setInterval(value);
          }
        },
        title: Text(label),
        secondary: const Icon(Icons.schedule, color: Color(0xFF2196F3)),
      ),
    );
  }
}
