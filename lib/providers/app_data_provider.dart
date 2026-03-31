import 'package:flutter/material.dart';
import '../models/app_data.dart';
import '../services/storage_service.dart';
import '../services/statistics_calculator.dart';
import '../models/statistics.dart';

class AppDataProvider extends ChangeNotifier {
  AppData _data = AppData.empty();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;

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

  // Habit operations
  String getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    
    final today = getTodayDateString();
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
    
    final today = getTodayDateString();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayString = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    
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
    // Set end date to yesterday so the habit disappears from today
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayString = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    
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
    final updatedHabitData = Map<String, Map<String, bool>>.from(_data.habitData);
    
    if (!updatedHabitData.containsKey(date)) {
      updatedHabitData[date] = {};
    }
    
    final currentValue = updatedHabitData[date]![habitName] ?? false;
    updatedHabitData[date]![habitName] = !currentValue;
    
    _data = _data.copyWith(habitData: updatedHabitData);
    notifyListeners();
    _saveData();
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
    updatedReflections[date] = reflection;
    
    _data = _data.copyWith(reflections: updatedReflections);
    notifyListeners();
    _saveData();
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
    final updatedDailyTasks = Map<String, List<Map<String, dynamic>>>.from(_data.dailyTasks);
    
    if (updatedDailyTasks.containsKey(date)) {
      updatedDailyTasks[date] = updatedDailyTasks[date]!.map((task) {
        if (task['id'] == taskId) {
          return {
            ...task,
            'completed': !(task['completed'] as bool),
          };
        }
        return task;
      }).toList();
    }
    
    _data = _data.copyWith(dailyTasks: updatedDailyTasks);
    notifyListeners();
    _saveData();
  }

  // Work Session operations
  void startWorkSession(DateTime startTime) {
    _data = _data.copyWith(
      activeWorkSession: {
        'startTime': startTime.toIso8601String(),
        'date': getTodayDateString(),
      },
    );
    notifyListeners();
    _saveData();
  }

  void updateActiveWorkSessionStartTime(DateTime newStartTime) {
    if (_data.activeWorkSession == null) return;
    
    _data = _data.copyWith(
      activeWorkSession: {
        'startTime': newStartTime.toIso8601String(),
        'date': getTodayDateString(),
      },
    );
    notifyListeners();
    _saveData();
  }

  void stopWorkSession(Map<String, dynamic> sessionData) {
    final updatedSessions = List<Map<String, dynamic>>.from(_data.workSessions);
    updatedSessions.add(sessionData);
    
    _data = _data.copyWith(
      workSessions: updatedSessions,
      clearActiveSession: true,
    );
    notifyListeners();
    _saveData();
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
    final updatedSessions = _data.workSessions
        .where((session) => 
            session['start'] != sessionToDelete['start'] || 
            session['end'] != sessionToDelete['end'])
        .toList();
    
    _data = _data.copyWith(workSessions: updatedSessions);
    notifyListeners();
    _saveData();
  }

  void updateWorkSession(Map<String, dynamic> oldSession, Map<String, dynamic> newSession) {
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

  // Get current data for cloud sync
  AppData getCurrentData() => _data;

  Future<String?> getLastBackupTime() async {
    return await _storageService.getLastBackupTime();
  }
}
