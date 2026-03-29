import 'dart:async';
import 'package:flutter/foundation.dart';

class WorkTimeService extends ChangeNotifier {
  Timer? _timer;
  DateTime? _sessionStartTime;
  Duration _elapsedTime = Duration.zero;
  bool _isRunning = false;
  DateTime? _lastNotificationTime;

  bool get isRunning => _isRunning;
  Duration get elapsedTime => _isRunning 
      ? _elapsedTime + DateTime.now().difference(_sessionStartTime!)
      : _elapsedTime;
  DateTime? get sessionStartTime => _sessionStartTime;
  DateTime? get startTime => _sessionStartTime;

  // Start a new work session
  void start() {
    if (_isRunning) return;
    
    _isRunning = true;
    _sessionStartTime = DateTime.now();
    _elapsedTime = Duration.zero;
    _lastNotificationTime = null;
    
    // Start timer that updates every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
      _checkFor45MinuteNotification();
    });
    
    notifyListeners();
  }

  // Stop the current work session and return session data
  Map<String, dynamic>? stop() {
    if (!_isRunning || _sessionStartTime == null) return null;
    
    _timer?.cancel();
    _timer = null;
    
    final endTime = DateTime.now();
    final totalDuration = endTime.difference(_sessionStartTime!);
    
    final sessionData = {
      'startTime': _sessionStartTime!.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': totalDuration.inSeconds,
      'date': _formatDate(_sessionStartTime!),
    };
    
    _isRunning = false;
    _sessionStartTime = null;
    _elapsedTime = Duration.zero;
    _lastNotificationTime = null;
    
    notifyListeners();
    return sessionData;
  }

  // Resume from a saved session (used when app restarts with active session)
  void resumeFromSaved(Map<String, dynamic> sessionData) {
    try {
      final startTime = DateTime.parse(sessionData['startTime'] as String);
      
      _isRunning = true;
      _sessionStartTime = startTime;
      _elapsedTime = Duration.zero;
      
      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        notifyListeners();
        _checkFor45MinuteNotification();
      });
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming work session: $e');
    }
  }

  // Update the start time of the current session
  void updateStartTime(DateTime newStartTime) {
    if (!_isRunning) return;
    
    _sessionStartTime = newStartTime;
    notifyListeners();
  }

  // Check if 45 minutes have passed and trigger notification
  void _checkFor45MinuteNotification() {
    if (!_isRunning || _sessionStartTime == null) return;
    
    final elapsed = DateTime.now().difference(_sessionStartTime!);
    
    // Check if we've passed 45 minutes
    if (elapsed.inMinutes >= 45) {
      // Check if we haven't notified in the last 45 minutes
      if (_lastNotificationTime == null || 
          DateTime.now().difference(_lastNotificationTime!).inMinutes >= 45) {
        _lastNotificationTime = DateTime.now();
        // Trigger notification callback (will be set by the provider)
        onFortyFiveMinutesPassed?.call();
      }
    }
  }

  // Callback for 45-minute notification
  Function? onFortyFiveMinutesPassed;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Format duration for display
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
