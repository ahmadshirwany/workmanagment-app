import '../models/statistics.dart';

class StatisticsCalculator {
  static Statistics calculate(
    List<Map<String, dynamic>> habits,
    Map<String, Map<String, bool>> habitData,
    Map<String, List<Map<String, dynamic>>> dailyTasks,
    List<Map<String, dynamic>> workSessions,
    Set<String> holidayDates, {
    String timePeriod = '30d', // '7d', '30d', '90d', 'all'
  }) {
    if (habits.isEmpty && habitData.isEmpty && dailyTasks.isEmpty && workSessions.isEmpty) {
      return Statistics(
        daysTracked: 0,
        overallCompletionRate: 0.0,
        currentStreak: 0,
        longestStreak: 0,
        habitCompletionCounts: {},
        totalDailyTasks: 0,
        completedDailyTasks: 0,
        dailyTaskCompletionRate: 0.0,
        avgTasksPerDay: 0.0,
        totalWorkTimeSeconds: 0,
        avgWorkTimePerDay: 0.0,
        maxWorkTimeSeconds: 0,
        workDaysCount: 0,
        consistencyScore: 0.0,
        weeklyBreakdown: {},
      );
    }

    // Get list of all calendar dates within the selected time period
    final now = DateTime.now();
    
    // Determine number of days based on timePeriod
    int numDays = 30; // default
    DateTime periodStart;
    
    switch (timePeriod) {
      case '7d':
        numDays = 7;
        periodStart = now.subtract(Duration(days: numDays));
        break;
      case '90d':
        numDays = 90;
        periodStart = now.subtract(Duration(days: numDays));
        break;
      case 'all':
        // For "all", use the earliest date from the data
        final dates = habitData.keys.toList()..sort();
        if (dates.isEmpty) {
          periodStart = now; // No data, use today
        } else {
          periodStart = DateTime.parse(dates.first);
        }
        numDays = now.difference(periodStart).inDays + 1;
        break;
      case '30d':
      default:
        numDays = 30;
        periodStart = now.subtract(Duration(days: numDays));
    }
    
    final allPeriodDays = <String>[];
    
    // If 'all', generate from earliest data to today
    if (timePeriod == 'all') {
      DateTime current = periodStart;
      while (current.isBefore(now) || current.isAtSameMomentAs(now)) {
        final dateString = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
        allPeriodDays.add(dateString);
        current = current.add(const Duration(days: 1));
      }
    } else {
      // For fixed periods, generate all dates in range
      for (int i = 0; i < numDays; i++) {
        final date = periodStart.add(Duration(days: i));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        allPeriodDays.add(dateString);
      }
    }

    // Filter out holidays from the period days
    final periodDays = allPeriodDays
        .where((date) => !holidayDates.contains(date))
        .toList();
    
    // Days tracked = only days in period where we have tracked data
    final dates = habitData.keys.toList()..sort();
    final trackedDatesInPeriod = dates
        .where((date) => periodDays.contains(date))
        .toList();
    final daysTracked = trackedDatesInPeriod.length;

    // Calculate overall completion rate
    int totalChecked = 0;
    int totalPossible = 0;
    
    for (final date in periodDays) {
      final dayData = habitData[date] ?? {};
      // Get only habits that were active on this date
      final activeHabits = _getActiveHabitsForDate(habits, date);
      
      for (final habitName in activeHabits) {
        totalPossible++;
        if (dayData[habitName] == true) {
          totalChecked++;
        }
      }
    }
    
    final overallCompletionRate = totalPossible > 0 ? totalChecked / totalPossible : 0.0;

    // Calculate per-habit completion counts
    final habitCompletionCounts = <String, int>{};
    for (final habit in habits) {
      final habitName = habit['name'] as String;
      int count = 0;
      for (final date in periodDays) {
        // Only count if habit was active on this date
        if (_isHabitActiveOnDate(habit, date) && habitData[date]?[habitName] == true) {
          count++;
        }
      }
      habitCompletionCounts[habitName] = count;
    }

    // Calculate daily task statistics
    int totalDailyTasks = 0;
    int completedDailyTasks = 0;
    
    for (final date in periodDays) {
      final tasks = dailyTasks[date] ?? [];
      totalDailyTasks += tasks.length;
      completedDailyTasks += tasks.where((task) => task['completed'] == true).length;
    }
    
    final dailyTaskCompletionRate = totalDailyTasks > 0 ? completedDailyTasks / totalDailyTasks : 0.0;
    final avgTasksPerDay = daysTracked > 0 ? totalDailyTasks / daysTracked : 0.0;

    // Find best performing habit
    String? bestPerformingHabit;
    int maxCompletions = 0;
    for (final entry in habitCompletionCounts.entries) {
      if (entry.value > maxCompletions) {
        maxCompletions = entry.value;
        bestPerformingHabit = entry.key;
      }
    }

    // Find most productive day (most habits + tasks completed)
    String? mostProductiveDay;
    int maxProductivity = 0;
    for (final date in periodDays) {
      final dayData = habitData[date] ?? {};
      final activeHabits = _getActiveHabitsForDate(habits, date);
      final habitCompletion = activeHabits.where((h) => dayData[h] == true).length;
      
      final tasks = dailyTasks[date] ?? [];
      final taskCompletion = tasks.where((task) => task['completed'] == true).length;
      
      final totalProductivity = habitCompletion + taskCompletion;
      if (totalProductivity > maxProductivity) {
        maxProductivity = totalProductivity;
        mostProductiveDay = date;
      }
    }

    // Calculate weekly breakdown (0=Monday, 6=Sunday)
    final weeklyBreakdown = <String, int>{
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
    };
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    for (final date in periodDays) {
      final dateTime = DateTime.parse(date);
      final dayOfWeek = dateTime.weekday - 1; // 0=Monday, 6=Sunday
      
      final dayData = habitData[date] ?? {};
      final activeHabits = _getActiveHabitsForDate(habits, date);
      final habitCompletion = activeHabits.where((h) => dayData[h] == true).length;
      
      final tasks = dailyTasks[date] ?? [];
      final taskCompletion = tasks.where((task) => task['completed'] == true).length;
      
      weeklyBreakdown[dayNames[dayOfWeek]] = (weeklyBreakdown[dayNames[dayOfWeek]] ?? 0) + habitCompletion + taskCompletion;
    }

    // Calculate consistency score (percentage of all period calendar days with at least one completion - excluding holidays)
    int daysWithActivity = 0;
    for (final date in periodDays) {
      final dayData = habitData[date] ?? {};
      final activeHabits = _getActiveHabitsForDate(habits, date);
      final hasHabitCompletion = activeHabits.isNotEmpty && activeHabits.any((h) => dayData[h] == true);
      
      final tasks = dailyTasks[date] ?? [];
      final hasTaskCompletion = tasks.any((task) => task['completed'] == true);
      
      if (hasHabitCompletion || hasTaskCompletion) {
        daysWithActivity++;
      }
    }
    // Consistency score is based on % of period calendar days (excluding holidays) with ANY activity
    final consistencyScore = periodDays.isNotEmpty ? daysWithActivity / periodDays.length : 0.0;

    // Calculate streaks (excluding holidays)
    final sortedDates = habitData.keys.toList()..sort();
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    for (int i = sortedDates.length - 1; i >= 0; i--) {
      final date = sortedDates[i];
      
      // Skip holiday dates in streak calculation
      if (holidayDates.contains(date)) continue;
      
      final dayData = habitData[date] ?? {};
      final activeHabits = _getActiveHabitsForDate(habits, date);
      
      if (activeHabits.isEmpty) continue;
      
      // Check if all active habits are completed
      bool allCompleted = activeHabits.every((habitName) => dayData[habitName] == true);
      
      if (allCompleted) {
        tempStreak++;
        // Update current streak if this is the most recent non-holiday date
        if (tempStreak > currentStreak && 
            sortedDates.sublist(i + 1).every((d) => holidayDates.contains(d) || d == date)) {
          currentStreak = tempStreak;
        }
      } else {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 0;
      }
    }
    
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }
    
    // Set current streak if we're still in a streak
    if (tempStreak > 0) {
      currentStreak = tempStreak;
    }

    // Calculate work time statistics (excluding holidays)
    int totalWorkTimeSeconds = 0;
    int maxWorkTimeSeconds = 0;
    String? mostProductiveWorkDay;
    Map<String, int> workTimeByDate = {};
    
    for (var session in workSessions) {
      // Get date from session, or extract from startTime if not available
      String? date = session['date'] as String?;
      if (date == null && session['startTime'] != null) {
        try {
          final startTime = DateTime.parse(session['startTime'] as String);
          date = '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
        } catch (e) {
          continue; // Skip sessions with invalid dates
        }
      }
      
      if (date == null || holidayDates.contains(date)) continue; // Skip sessions without dates or on holidays
      
      final duration = session['duration'] as int? ?? 0;
      totalWorkTimeSeconds += duration;
      
      workTimeByDate[date] = (workTimeByDate[date] ?? 0) + duration;
      
      if (workTimeByDate[date]! > maxWorkTimeSeconds) {
        maxWorkTimeSeconds = workTimeByDate[date]!;
        mostProductiveWorkDay = date;
      }
    }
    
    final workDaysCount = workTimeByDate.length;
    final avgWorkTimePerDay = workDaysCount > 0 ? totalWorkTimeSeconds / workDaysCount : 0.0;

    return Statistics(
      daysTracked: daysTracked,
      overallCompletionRate: overallCompletionRate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      habitCompletionCounts: habitCompletionCounts,
      totalDailyTasks: totalDailyTasks,
      completedDailyTasks: completedDailyTasks,
      dailyTaskCompletionRate: dailyTaskCompletionRate,
      avgTasksPerDay: avgTasksPerDay,
      totalWorkTimeSeconds: totalWorkTimeSeconds,
      avgWorkTimePerDay: avgWorkTimePerDay,
      maxWorkTimeSeconds: maxWorkTimeSeconds,
      mostProductiveWorkDay: mostProductiveWorkDay,
      workDaysCount: workDaysCount,
      bestPerformingHabit: bestPerformingHabit,
      mostProductiveDay: mostProductiveDay,
      consistencyScore: consistencyScore,
      weeklyBreakdown: weeklyBreakdown,
    );
  }

  static List<String> _getActiveHabitsForDate(List<Map<String, dynamic>> habits, String date) {
    return habits
        .where((habit) => _isHabitActiveOnDate(habit, date))
        .map((habit) => habit['name'] as String)
        .toList();
  }

  static bool _isHabitActiveOnDate(Map<String, dynamic> habit, String date) {
    final startDate = habit['startDate'] as String?;
    final endDate = habit['endDate'] as String?;
    
    // Habit must have started before or on this date
    if (startDate != null && startDate.compareTo(date) > 0) {
      return false;
    }
    
    // If habit has an end date, it must be after this date
    if (endDate != null && endDate.compareTo(date) <= 0) {
      return false;
    }
    
    return true;
  }

  static double calculateDayCompletionRate(
    List<String> activeHabits,
    Map<String, bool> dayData,
  ) {
    if (activeHabits.isEmpty) return 0.0;
    
    int completed = 0;
    for (final habit in activeHabits) {
      if (dayData[habit] == true) {
        completed++;
      }
    }
    
    return completed / activeHabits.length;
  }
}
