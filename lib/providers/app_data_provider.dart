import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_data.dart';
import '../services/storage_service.dart';
import '../services/statistics_calculator.dart';
import '../models/statistics.dart';

typedef GamificationEventHandler = Future<void> Function(
  String eventType,
  Map<String, dynamic> payload,
);

class AppDataProvider extends ChangeNotifier {
  AppData _data = AppData.empty();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  GamificationEventHandler? _gamificationEventHandler;

  AppData get data => _data;
  bool get isLoading => _isLoading;

  AppDataProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    
    _data = await _storageService.loadData();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    await _storageService.saveData(_data);
  }

  void setGamificationEventHandler(GamificationEventHandler? handler) {
    _gamificationEventHandler = handler;
  }

  Future<void> _emitGamificationEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    if (_gamificationEventHandler == null) return;
    await _gamificationEventHandler!(eventType, payload);
  }

  // Habit operations
  String getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _toDateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _parseDateOnly(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) {
      return getBusinessTodayDate();
    }
    return _toDateOnly(parsed);
  }

  DateTime getBusinessTodayDate() {
    final now = DateTime.now();
    final businessNow = now.hour < 6
        ? now.subtract(const Duration(days: 1))
        : now;
    return _toDateOnly(businessNow);
  }

  String getBusinessDateString() {
    return _formatDate(getBusinessTodayDate());
  }

  int getDayOffsetFromBusinessToday(String date) {
    return _parseDateOnly(date).difference(getBusinessTodayDate()).inDays;
  }

  bool canEditHabitsForDate(String date) {
    return getDayOffsetFromBusinessToday(date) == 0;
  }

  bool canEditTasksForDate(String date) {
    return getDayOffsetFromBusinessToday(date) == 0;
  }

  bool canEditWorkSessionForDate(String date) {
    return getDayOffsetFromBusinessToday(date) == 0;
  }

  bool canToggleVacationForDate(String date) {
    final offset = getDayOffsetFromBusinessToday(date);
    return offset >= -7 && offset <= 7;
  }

  String getRestrictionMessage({required String domain, required String date}) {
    if (domain == 'vacation') {
      return 'Vacation toggle is only available from 7 days before to 7 days after today.';
    }

    final offset = getDayOffsetFromBusinessToday(date);
    if (offset < 0) {
      return 'Past dates are read-only after 6:00 AM. Only vacation can be toggled for the last 7 days.';
    }
    if (offset > 0) {
      return 'Future dates are read-only. Only vacation can be toggled for the next 7 days.';
    }
    return 'This action is currently locked.';
  }

  // Get habits active for a specific date
  List<String> getActiveHabitsForDate(String date) {
    return _data.habits
        .where((habit) {
          final startDate = habit['startDate'] as String?;
          final endDate = habit['endDate'] as String?;
          
          // Habit must have started before or on this date
          if (startDate != null && startDate.compareTo(date) > 0) {
            return false;
          }
          
          // If habit has an end date, check if date is after end date
          // The habit should appear UP TO AND INCLUDING the end date
          if (endDate != null && date.compareTo(endDate) > 0) {
            return false;
          }
          
          return true;
        })
        .map((habit) => habit['name'] as String)
        .toList();
  }

  // Get all habit names including inactive ones
  List<String> getAllHabitNames() {
    return _data.habits.map((h) => h['name'] as String).toList();
  }

  void addHabit(String habitName) {
    if (habitName.trim().isEmpty) return;

    if (!canEditHabitsForDate(getBusinessDateString())) return;
    
    final today = getBusinessDateString();
    _data = _data.copyWith(
      habits: [
        ..._data.habits,
        {
          'name': habitName.trim(),
          'startDate': today,
          'endDate': null,
        }
      ],
    );
    notifyListeners();
    _saveData();
  }

  void updateHabit(String oldHabitName, String newHabitName) {
    if (newHabitName.trim().isEmpty || oldHabitName == newHabitName.trim()) return;

    if (!canEditHabitsForDate(getBusinessDateString())) return;
    
    final today = getBusinessDateString();
    final yesterdayString =
        _formatDate(getBusinessTodayDate().subtract(const Duration(days: 1)));
    
    // End the old habit (set endDate to yesterday so it doesn't appear from today onwards)
    final updatedHabits = _data.habits.map((habit) {
      if (habit['name'] == oldHabitName) {
        return {
          ...habit,
          'endDate': yesterdayString,
        };
      }
      return habit;
    }).toList();
    
    // Add a new habit with the new name starting from today
    updatedHabits.add({
      'name': newHabitName.trim(),
      'startDate': today,
      'endDate': null,
    });
    
    // Don't modify past habit data - keep historical records with old name
    // This preserves the integrity of past tracking data
    
    _data = _data.copyWith(
      habits: updatedHabits,
    );
    notifyListeners();
    _saveData();
  }

  void removeHabit(String habitName) {
    if (!canEditHabitsForDate(getBusinessDateString())) return;

    // Set end date to yesterday so the habit disappears from today
    final yesterdayString =
        _formatDate(getBusinessTodayDate().subtract(const Duration(days: 1)));
    
    // Update the habit to set its end date to yesterday
    final updatedHabits = _data.habits.map((habit) {
      if (habit['name'] == habitName) {
        return {
          ...habit,
          'endDate': yesterdayString,
        };
      }
      return habit;
    }).toList();
    
    _data = _data.copyWith(
      habits: updatedHabits,
    );
    notifyListeners();
    _saveData();
  }

  void toggleHabit(String habitName, String date) {
    if (!canEditHabitsForDate(date)) return;

    final updatedHabitData = Map<String, Map<String, bool>>.from(_data.habitData);
    
    if (!updatedHabitData.containsKey(date)) {
      updatedHabitData[date] = {};
    }
    
    final currentValue = updatedHabitData[date]![habitName] ?? false;
    final nextValue = !currentValue;
    updatedHabitData[date]![habitName] = nextValue;
    
    _data = _data.copyWith(habitData: updatedHabitData);
    notifyListeners();
    _saveData();

    if (nextValue) {
      unawaited(_emitGamificationEvent('habit_completed', {
        'habitName': habitName,
        'date': date,
        'hour': DateTime.now().hour,
      }));
    }
  }

  bool isHabitCompleted(String habitName, String date) {
    return _data.habitData[date]?[habitName] ?? false;
  }

  int getHabitStreak(String habitName) {
    // Find the habit to get its date range
    final habit = _data.habits.firstWhere(
      (h) => h['name'] == habitName,
      orElse: () => <String, dynamic>{},
    );
    
    if (habit.isEmpty) return 0;
    
    final startDate = habit['startDate'] as String?;
    final endDate = habit['endDate'] as String?;
    
    final dates = _data.habitData.keys.toList()..sort();
    int streak = 0;
    
    // Count backwards from most recent date
    for (int i = dates.length - 1; i >= 0; i--) {
      final date = dates[i];
      
      // Skip dates outside habit's active period
      if (startDate != null && date.compareTo(startDate) < 0) continue;
      if (endDate != null && date.compareTo(endDate) >= 0) continue;
      
      if (_data.habitData[date]?[habitName] == true) {
        streak++;
      } else {
        // If this date is in the active period and not completed, break streak
        if (startDate != null && date.compareTo(startDate) >= 0) {
          break;
        }
      }
    }
    
    return streak;
  }

  // Holiday operations
  void toggleHoliday(String date) {
    if (!canToggleVacationForDate(date)) return;

    final updatedHolidayDates = Set<String>.from(_data.holidayDates);
    
    if (updatedHolidayDates.contains(date)) {
      updatedHolidayDates.remove(date);
    } else {
      updatedHolidayDates.add(date);
    }
    
    _data = _data.copyWith(holidayDates: updatedHolidayDates);
    notifyListeners();
    _saveData();
  }

  bool isHoliday(String date) {
    return _data.holidayDates.contains(date);
  }

  // Challenge operations
  void updateChallenge(String challenge) {
    _data = _data.copyWith(challenge: challenge);
    notifyListeners();
    _saveData();
  }

  // Reflection operations
  void saveReflection(String date, String reflection) {
    final updatedReflections = Map<String, String>.from(_data.reflections);
    final existingReflection = updatedReflections[date] ?? '';
    final hasContent = reflection.trim().isNotEmpty;
    final isNewEntry = existingReflection.trim().isEmpty && hasContent;
    updatedReflections[date] = reflection;
    
    _data = _data.copyWith(reflections: updatedReflections);
    notifyListeners();
    _saveData();

    if (hasContent) {
      unawaited(_emitGamificationEvent('reflection_saved', {
        'date': date,
        'isNewEntry': isNewEntry,
        'hasContent': hasContent,
      }));
    }
  }

  String getReflection(String date) {
    return _data.reflections[date] ?? '';
  }

  // Goals operations
  void updateGoals(String goals) {
    _data = _data.copyWith(goals: goals);
    notifyListeners();
    _saveData();
  }

  void updateDailyNotes(String notes) {
    _data = _data.copyWith(dailyNotes: notes);
    notifyListeners();
    _saveData();
  }

  // Daily Tasks operations
  List<Map<String, dynamic>> getDailyTasks(String date) {
    return _data.dailyTasks[date] ?? [];
  }

  void addDailyTask(String date, String taskName) {
    if (taskName.trim().isEmpty) return;

    if (!canEditTasksForDate(date)) return;
    
    final updatedDailyTasks = Map<String, List<Map<String, dynamic>>>.from(_data.dailyTasks);
    
    if (!updatedDailyTasks.containsKey(date)) {
      updatedDailyTasks[date] = [];
    }
    
    updatedDailyTasks[date]!.add({
      'name': taskName.trim(),
      'completed': false,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    
    _data = _data.copyWith(dailyTasks: updatedDailyTasks);
    notifyListeners();
    _saveData();
  }

  void updateDailyTask(String date, String taskId, String newTaskName) {
    if (newTaskName.trim().isEmpty) return;

    if (!canEditTasksForDate(date)) return;
    
    final updatedDailyTasks = Map<String, List<Map<String, dynamic>>>.from(_data.dailyTasks);
    
    if (updatedDailyTasks.containsKey(date)) {
      updatedDailyTasks[date] = updatedDailyTasks[date]!.map((task) {
        if (task['id'] == taskId) {
          return {
            ...task,
            'name': newTaskName.trim(),
          };
        }
        return task;
      }).toList();
    }
    
    _data = _data.copyWith(dailyTasks: updatedDailyTasks);
    notifyListeners();
    _saveData();
  }

  void removeDailyTask(String date, String taskId) {
    if (!canEditTasksForDate(date)) return;

    final updatedDailyTasks = Map<String, List<Map<String, dynamic>>>.from(_data.dailyTasks);
    
    if (updatedDailyTasks.containsKey(date)) {
      updatedDailyTasks[date] = updatedDailyTasks[date]!
          .where((task) => task['id'] != taskId)
          .toList();
      
      if (updatedDailyTasks[date]!.isEmpty) {
        updatedDailyTasks.remove(date);
      }
    }
    
    _data = _data.copyWith(dailyTasks: updatedDailyTasks);
    notifyListeners();
    _saveData();
  }

  void toggleDailyTask(String date, String taskId) {
    if (!canEditTasksForDate(date)) return;

    final updatedDailyTasks = Map<String, List<Map<String, dynamic>>>.from(_data.dailyTasks);
    bool toggledToCompleted = false;
    
    if (updatedDailyTasks.containsKey(date)) {
      updatedDailyTasks[date] = updatedDailyTasks[date]!.map((task) {
        if (task['id'] == taskId) {
          final currentCompleted = task['completed'] as bool? ?? false;
          final nextCompleted = !currentCompleted;
          if (nextCompleted) {
            toggledToCompleted = true;
          }
          return {
            ...task,
            'completed': nextCompleted,
          };
        }
        return task;
      }).toList();
    }
    
    _data = _data.copyWith(dailyTasks: updatedDailyTasks);
    notifyListeners();
    _saveData();

    if (toggledToCompleted) {
      unawaited(_emitGamificationEvent('task_completed', {
        'taskId': taskId,
        'date': date,
      }));
    }
  }

  // Work Session operations
  void startWorkSession(DateTime startTime) {
    _data = _data.copyWith(
      activeWorkSession: {
        'startTime': startTime.toIso8601String(),
        'date': getBusinessDateString(),
      },
    );
    notifyListeners();
    _saveData();
  }

  void updateActiveWorkSessionStartTime(DateTime newStartTime) {
    if (_data.activeWorkSession == null) return;

    final activeDate = _data.activeWorkSession!['date'] as String?;
    if (activeDate != null && !canEditWorkSessionForDate(activeDate)) return;
    
    _data = _data.copyWith(
      activeWorkSession: {
        'startTime': newStartTime.toIso8601String(),
        'date': activeDate ?? getBusinessDateString(),
      },
    );
    notifyListeners();
    _saveData();
  }

  void stopWorkSession(Map<String, dynamic> sessionData) {
    final isStoppingActiveSession = _data.activeWorkSession != null;
    final sessionDate = (_data.activeWorkSession?['date'] as String?) ??
        (sessionData['date'] as String?) ??
        getBusinessDateString();
    if (!isStoppingActiveSession && !canEditWorkSessionForDate(sessionDate)) {
      return;
    }

    final normalizedSessionData = {
      ...sessionData,
      'date': sessionDate,
    };

    final updatedSessions = List<Map<String, dynamic>>.from(_data.workSessions);
    updatedSessions.add(normalizedSessionData);
    
    _data = _data.copyWith(
      workSessions: updatedSessions,
      clearActiveSession: true,
    );
    notifyListeners();
    _saveData();

    final endTimeString = sessionData['endTime'] as String?;
    final endHour = DateTime.tryParse(endTimeString ?? '')?.hour ?? DateTime.now().hour;
    unawaited(_emitGamificationEvent('work_session_completed', {
      'date': sessionDate,
      'duration': (normalizedSessionData['duration'] as num?)?.toInt() ?? 0,
      'endHour': endHour,
    }));
  }

  Map<String, dynamic>? getActiveWorkSession() {
    return _data.activeWorkSession;
  }

  List<Map<String, dynamic>> getWorkSessionsForDate(String date) {
    return _data.workSessions
        .where((session) => session['date'] == date)
        .toList();
  }

  int getTotalWorkTimeForDate(String date) {
    final sessions = getWorkSessionsForDate(date);
    return sessions.fold<int>(0, (sum, session) => sum + (session['duration'] as int? ?? 0));
  }

  void deleteWorkSession(Map<String, dynamic> sessionToDelete) {
    final sessionDate = sessionToDelete['date'] as String?;
    if (sessionDate == null || !canEditWorkSessionForDate(sessionDate)) return;

    final updatedSessions = _data.workSessions
        .where((session) => 
        session['startTime'] != sessionToDelete['startTime'] || 
        session['endTime'] != sessionToDelete['endTime'])
        .toList();
    
    _data = _data.copyWith(workSessions: updatedSessions);
    notifyListeners();
    _saveData();
  }

  void updateWorkSession(Map<String, dynamic> oldSession, Map<String, dynamic> newSession) {
    final oldDate = oldSession['date'] as String?;
    final newDate = newSession['date'] as String?;
    if (oldDate == null || newDate == null) return;
    if (!canEditWorkSessionForDate(oldDate) ||
        !canEditWorkSessionForDate(newDate)) {
      return;
    }

    final updatedSessions = _data.workSessions.map((session) {
      // Match by startTime and endTime to find the session to update
      if (session['startTime'] == oldSession['startTime'] && 
          session['endTime'] == oldSession['endTime']) {
        return newSession;
      }
      return session;
    }).toList();
    
    _data = _data.copyWith(workSessions: updatedSessions);
    notifyListeners();
    _saveData();
  }

  // Get work time statistics for last 30 days
  Map<String, int> getWorkTimeByDate() {
    Map<String, int> workTimeByDate = {};
    
    for (var session in _data.workSessions) {
      final date = session['date'] as String;
      final duration = session['duration'] as int? ?? 0;
      workTimeByDate[date] = (workTimeByDate[date] ?? 0) + duration;
    }
    
    return workTimeByDate;
  }

  // Statistics
  Statistics getStatistics({String timePeriod = '30d'}) {
    return StatisticsCalculator.calculate(_data.habits, _data.habitData, _data.dailyTasks, _data.workSessions, _data.holidayDates, timePeriod: timePeriod);
  }

  double getDayCompletionRate(String date) {
    final activeHabits = getActiveHabitsForDate(date);
    final dayData = _data.habitData[date] ?? {};
    return StatisticsCalculator.calculateDayCompletionRate(activeHabits, dayData);
  }

  // Data management
  Future<String> exportData() async {
    return await _storageService.exportData(_data);
  }

  Future<void> importData(String filePath) async {
    final importedData = await _storageService.importData(filePath);
    _data = importedData;
    notifyListeners();
    await _saveData();
  }

  // Reset all data
  Future<void> resetAllData() async {
    _data = AppData.empty();
    notifyListeners();
    await _saveData();
  }

  // Import from JSON map (for cloud sync)
  Future<void> importFromJson(Map<String, dynamic> json) async {
    _data = AppData.fromJson(json);
    notifyListeners();
    await _saveData();
  }

  // Import AppData directly (for cloud sync)
  Future<void> importAppData(AppData data) async {
    _data = data;
    notifyListeners();
    await _saveData();
  }

  Future<void> updateGamificationData({
    int? xp,
    int? level,
    List<Map<String, dynamic>>? achievements,
    List<Map<String, dynamic>>? xpTransactions,
    Map<String, dynamic>? disciplineScore,
    Map<String, dynamic>? gamificationMeta,
    Map<String, int>? gamificationCounters,
    Map<String, int>? dailyXp,
  }) async {
    _data = _data.copyWith(
      xp: xp,
      level: level,
      achievements: achievements,
      xpTransactions: xpTransactions,
      disciplineScore: disciplineScore,
      gamificationMeta: gamificationMeta,
      gamificationCounters: gamificationCounters,
      dailyXp: dailyXp,
    );
    notifyListeners();
    await _saveData();
  }

  Future<void> updateAiCoachData({
    List<Map<String, dynamic>>? aiHistory,
    Map<String, dynamic>? aiCoachMeta,
    Map<String, dynamic>? dailyMotivation,
  }) async {
    _data = _data.copyWith(
      aiHistory: aiHistory,
      aiCoachMeta: aiCoachMeta,
      dailyMotivation: dailyMotivation,
    );
    notifyListeners();
    await _saveData();
  }

  List<String> getRecentReflectionEntries({int limit = 5}) {
    final sorted = _data.reflections.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sorted
        .map((entry) => entry.value.trim())
        .where((text) => text.isNotEmpty)
        .take(limit)
        .toList();
  }

  String? getWeakestHabitName({String timePeriod = '30d'}) {
    final stats = getStatistics(timePeriod: timePeriod);
    if (stats.habitCompletionCounts.isEmpty) return null;

    String? weakestHabit;
    int? minCount;

    for (final entry in stats.habitCompletionCounts.entries) {
      final value = entry.value;
      if (minCount == null || value < minCount) {
        minCount = value;
        weakestHabit = entry.key;
      }
    }

    return weakestHabit;
  }

  void recordAiCoachConversation() {
    unawaited(_emitGamificationEvent('ai_conversation', {
      'date': getTodayDateString(),
    }));
  }

  void recordWeeklyChallengeCompletion({int bonusXp = 200}) {
    unawaited(_emitGamificationEvent('weekly_challenge_completed', {
      'date': getTodayDateString(),
      'bonusXp': bonusXp,
    }));
  }

  // Get current data for cloud sync
  AppData getCurrentData() => _data;

  Future<String?> getLastBackupTime() async {
    return await _storageService.getLastBackupTime();
  }
}
