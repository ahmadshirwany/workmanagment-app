class Statistics {
  final int daysTracked;
  final double overallCompletionRate;
  final int currentStreak;
  final int longestStreak;
  final Map<String, int> habitCompletionCounts;
  
  // Daily task statistics
  final int totalDailyTasks;
  final int completedDailyTasks;
  final double dailyTaskCompletionRate;
  final double avgTasksPerDay;
  
  // Work time statistics
  final int totalWorkTimeSeconds;
  final double avgWorkTimePerDay;
  final int maxWorkTimeSeconds;
  final String? mostProductiveWorkDay;
  final int workDaysCount;
  
  // Insights
  final String? bestPerformingHabit;
  final String? mostProductiveDay;
  final double consistencyScore;
  final Map<String, int> weeklyBreakdown; // Day of week -> completion count

  Statistics({
    required this.daysTracked,
    required this.overallCompletionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.habitCompletionCounts,
    required this.totalDailyTasks,
    required this.completedDailyTasks,
    required this.dailyTaskCompletionRate,
    required this.avgTasksPerDay,
    required this.totalWorkTimeSeconds,
    required this.avgWorkTimePerDay,
    required this.maxWorkTimeSeconds,
    this.mostProductiveWorkDay,
    required this.workDaysCount,
    this.bestPerformingHabit,
    this.mostProductiveDay,
    required this.consistencyScore,
    required this.weeklyBreakdown,
  });
}
