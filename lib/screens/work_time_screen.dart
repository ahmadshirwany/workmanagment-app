import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';
import '../services/work_time_service.dart';
import '../services/notification_service.dart';

class WorkTimeScreen extends StatefulWidget {
  const WorkTimeScreen({super.key});

  @override
  State<WorkTimeScreen> createState() => _WorkTimeScreenState();
}

class _WorkTimeScreenState extends State<WorkTimeScreen> {
  late WorkTimeService _workTimeService;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _workTimeService = WorkTimeService();
    
    // Check if there's an active session to resume
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppDataProvider>();
      final activeSession = provider.getActiveWorkSession();
      if (activeSession != null) {
        _workTimeService.resumeFromSaved(activeSession);
      }
    });
    
    // Set up 45-minute notification callback
    _workTimeService.onFortyFiveMinutesPassed = () {
      NotificationService().showWorkTimeAlert();
      _show45MinuteNotification();
    };
  }

  @override
  void dispose() {
    _workTimeService.dispose();
    super.dispose();
  }

  void _show45MinuteNotification() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Color(0xFFFF9800), size: 28),
            SizedBox(width: 12),
            Text('Time Check'),
          ],
        ),
        content: const Text(
          '⏰ You\'ve been working for 45+ minutes!\n\nTake a short break or update your work status if needed.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Working'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopWork();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop & Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _startWork() {
    final provider = context.read<AppDataProvider>();
    _workTimeService.start();
    provider.startWorkSession(DateTime.now());
  }

  void _stopWork() {
    final provider = context.read<AppDataProvider>();
    final sessionData = _workTimeService.stop();
    if (sessionData != null) {
      provider.stopWorkSession(sessionData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Work session saved: ${_workTimeService.formatDuration(Duration(seconds: sessionData['duration'] as int))}',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _editCurrentSession() {
    if (!_workTimeService.isRunning) return;

    final currentStartTime = _workTimeService.startTime;
    if (currentStartTime == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF00BCD4)),
            SizedBox(width: 12),
            Text('Edit Start Time'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current start time: ${DateFormat('h:mm a').format(currentStartTime)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select new start time:',
              style: TextStyle(fontWeight: FontWeight.w500),
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
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(currentStartTime),
              );
              
              if (picked != null) {
                final now = DateTime.now();
                final newStartTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  picked.hour,
                  picked.minute,
                );

                if (newStartTime.isAfter(now)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Start time cannot be in the future'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                _workTimeService.updateStartTime(newStartTime);
                final provider = context.read<AppDataProvider>();
                provider.updateActiveWorkSessionStartTime(newStartTime);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Start time updated to ${DateFormat('h:mm a').format(newStartTime)}'),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (tomorrow.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = tomorrow;
      });
    }
  }

  void _showManualEntryDialog() {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle, color: Color(0xFF00BCD4)),
                SizedBox(width: 12),
                Text('Add Manual Work Hours'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date selector
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          _selectedDate = picked;
                          dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Start time
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startTime = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        startTime != null
                            ? startTime!.format(context)
                            : 'Select start time',
                        style: TextStyle(
                          color: startTime != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // End time
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endTime = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        endTime != null
                            ? endTime!.format(context)
                            : 'Select end time',
                        style: TextStyle(
                          color: endTime != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (startTime == null || endTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select both start and end times'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final selectedDate = DateTime.parse(dateController.text);
                  final start = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    startTime!.hour,
                    startTime!.minute,
                  );
                  final end = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    endTime!.hour,
                    endTime!.minute,
                  );

                  if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final duration = end.difference(start).inSeconds;
                  final sessionData = {
                    'startTime': start.toIso8601String(),
                    'endTime': end.toIso8601String(),
                    'duration': duration,
                    'date': _formatDate(selectedDate),
                  };

                  final provider = context.read<AppDataProvider>();
                  provider.stopWorkSession(sessionData);
                  
                  Navigator.pop(context);
                  setState(() {});
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Work session added: ${_workTimeService.formatDuration(Duration(seconds: duration))}',
                      ),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSessionDialog(Map<String, dynamic> existingSession) {
    final originalStartTime = DateTime.parse(existingSession['startTime'] as String);
    final originalEndTime = DateTime.parse(existingSession['endTime'] as String);
    final sessionDate = DateTime.parse(existingSession['date'] as String);
    
    TimeOfDay? startTime = TimeOfDay.fromDateTime(originalStartTime);
    TimeOfDay? endTime = TimeOfDay.fromDateTime(originalEndTime);
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(sessionDate),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit, color: Color(0xFF00BCD4)),
                SizedBox(width: 12),
                Text('Edit Work Session'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date selector
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: sessionDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Start time
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startTime = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        startTime != null
                            ? startTime!.format(context)
                            : 'Select start time',
                        style: TextStyle(
                          color: startTime != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // End time
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endTime = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        endTime != null
                            ? endTime!.format(context)
                            : 'Select end time',
                        style: TextStyle(
                          color: endTime != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (startTime == null || endTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select both start and end times'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final selectedDate = DateTime.parse(dateController.text);
                  final start = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    startTime!.hour,
                    startTime!.minute,
                  );
                  final end = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    endTime!.hour,
                    endTime!.minute,
                  );

                  if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final duration = end.difference(start).inSeconds;
                  final updatedSession = {
                    'startTime': start.toIso8601String(),
                    'endTime': end.toIso8601String(),
                    'duration': duration,
                    'date': _formatDate(selectedDate),
                  };

                  final provider = context.read<AppDataProvider>();
                  provider.updateWorkSession(existingSession, updatedSession);
                  
                  Navigator.pop(context);
                  setState(() {});
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Work session updated: ${_workTimeService.formatDuration(Duration(seconds: duration))}',
                      ),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Time'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          final selectedDateString = _formatDate(_selectedDate);
          final sessions = provider.getWorkSessionsForDate(selectedDateString);
          final totalSeconds = provider.getTotalWorkTimeForDate(selectedDateString);
          final totalDuration = Duration(seconds: totalSeconds);
          final isToday = selectedDateString == provider.getTodayDateString();

          return Column(
            children: [
              // Date Selector
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00BCD4)),
                        onPressed: _previousDay,
                        tooltip: 'Previous Day',
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today, color: Color(0xFF00BCD4), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF00BCD4)),
                        onPressed: _nextDay,
                        tooltip: 'Next Day',
                      ),
                    ],
                  ),
                ),
              ),

              // Stopwatch Section (only show for today)
              if (isToday) ...[
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.timer,
                          size: 60,
                          color: Color(0xFF00BCD4),
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _workTimeService,
                          builder: (context, child) {
                            return Text(
                              _workTimeService.formatDuration(_workTimeService.elapsedTime),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        AnimatedBuilder(
                          animation: _workTimeService,
                          builder: (context, child) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _workTimeService.isRunning ? _stopWork : _startWork,
                                    icon: Icon(_workTimeService.isRunning ? Icons.stop : Icons.play_arrow),
                                    label: Text(
                                      _workTimeService.isRunning ? 'Stop Work' : 'Start Work',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _workTimeService.isRunning 
                                          ? const Color(0xFFF44336) 
                                          : const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_workTimeService.isRunning) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _editCurrentSession,
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit Start Time'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF00BCD4),
                                      side: const BorderSide(color: Color(0xFF00BCD4)),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Daily Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: const Color(0xFF00BCD4).withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.today, color: Color(0xFF00BCD4)),
                            SizedBox(width: 12),
                            Text(
                              'Total Work Time',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _workTimeService.formatDuration(totalDuration),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00BCD4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sessions List
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Work Sessions (${sessions.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: sessions.isEmpty
                          ? Center(
                              child: Text(
                                isToday 
                                    ? 'No work sessions yet today.\nTap "Start Work" to begin tracking.'
                                    : 'No work sessions on this day.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                final session = sessions[index];
                                final startTime = DateTime.parse(session['startTime'] as String);
                                final endTime = DateTime.parse(session['endTime'] as String);
                                final duration = Duration(seconds: session['duration'] as int);

                                return Dismissible(
                                  key: Key('${session['startTime']}_${session['endTime']}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Work Session'),
                                        content: Text(
                                          'Delete this work session?\n${_workTimeService.formatDuration(duration)}\n${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) {
                                    provider.deleteWorkSession(session);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Work session deleted'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00BCD4).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.work_history,
                                          color: Color(0xFF00BCD4),
                                        ),
                                      ),
                                      title: Text(
                                        _workTimeService.formatDuration(duration),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${duration.inMinutes} min',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 20),
                                            color: const Color(0xFF00BCD4),
                                            onPressed: () => _showEditSessionDialog(session),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualEntryDialog,
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Manual'),
      ),
    );
  }
}
