import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          final stats = provider.getStatistics();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.bar_chart,
                  size: 60,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),
                const Text(
                  '30-Day Statistics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Overview Section
                const Text(
                  '📊 Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Days Tracked
                _buildStatCard(
                  context,
                  icon: Icons.calendar_today,
                  title: 'Days Tracked',
                  value: '${stats.daysTracked}',
                  color: const Color(0xFF2196F3),
                ),
                const SizedBox(height: 12),
                
                // Consistency Score
                _buildStatCard(
                  context,
                  icon: Icons.trending_up,
                  title: 'Consistency Score',
                  value: '${(stats.consistencyScore * 100).toStringAsFixed(1)}%',
                  subtitle: '${(stats.consistencyScore * stats.daysTracked).round()} days with activity',
                  color: const Color(0xFF00BCD4),
                ),
                const SizedBox(height: 12),
                
                // Overall Completion Rate
                _buildStatCard(
                  context,
                  icon: Icons.check_circle,
                  title: 'Habit Completion Rate',
                  value: '${(stats.overallCompletionRate * 100).toStringAsFixed(1)}%',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 24),
                
                // Streaks Section
                const Text(
                  '🔥 Streaks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.local_fire_department,
                        title: 'Current',
                        value: '${stats.currentStreak}',
                        subtitle: 'days',
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.emoji_events,
                        title: 'Longest',
                        value: '${stats.longestStreak}',
                        subtitle: 'days',
                        color: const Color(0xFF9C27B0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Daily Tasks Section
                const Text(
                  '✅ Daily Tasks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildStatCard(
                  context,
                  icon: Icons.task_alt,
                  title: 'Tasks Completed',
                  value: '${stats.completedDailyTasks}/${stats.totalDailyTasks}',
                  subtitle: '${(stats.dailyTaskCompletionRate * 100).toStringAsFixed(1)}% completion rate',
                  color: const Color(0xFF9C27B0),
                ),
                const SizedBox(height: 12),
                
                _buildStatCard(
                  context,
                  icon: Icons.assignment,
                  title: 'Average Tasks Per Day',
                  value: stats.avgTasksPerDay.toStringAsFixed(1),
                  color: const Color(0xFF673AB7),
                ),
                const SizedBox(height: 24),
                
                // Work Time Section
                const Text(
                  '⏰ Work Time',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                _buildStatCard(
                  context,
                  icon: Icons.access_time,
                  title: 'Total Work Time',
                  value: _formatWorkTime(stats.totalWorkTimeSeconds),
                  subtitle: 'Across ${stats.workDaysCount} work days',
                  color: const Color(0xFF00BCD4),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.schedule,
                        title: 'Daily Average',
                        value: _formatWorkTime(stats.avgWorkTimePerDay.round()),
                        color: const Color(0xFF26C6DA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.timer,
                        title: 'Best Day',
                        value: _formatWorkTime(stats.maxWorkTimeSeconds),
                        color: const Color(0xFF00ACC1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Insights Section
                const Text(
                  '💡 Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                if (stats.bestPerformingHabit != null)
                  _buildInsightCard(
                    context,
                    icon: Icons.star,
                    title: 'Best Performing Habit',
                    value: stats.bestPerformingHabit!,
                    detail: '${stats.habitCompletionCounts[stats.bestPerformingHabit!]} completions',
                    color: const Color(0xFFFFD700),
                  ),
                const SizedBox(height: 12),
                
                if (stats.mostProductiveDay != null)
                  _buildInsightCard(
                    context,
                    icon: Icons.celebration,
                    title: 'Most Productive Day',
                    value: _formatDate(stats.mostProductiveDay!),
                    color: const Color(0xFFFF6B6B),
                  ),
                const SizedBox(height: 24),
                
                // Weekly Breakdown
                const Text(
                  '📅 Weekly Breakdown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...stats.weeklyBreakdown.entries.map((entry) {
                          final maxValue = stats.weeklyBreakdown.values.fold<int>(0, (a, b) => a > b ? a : b);
                          final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Container(
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: percentage,
                                            child: Container(
                                              height: 24,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF4CAF50),
                                                    Color(0xFF2196F3),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${entry.value}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Per-Habit Completion
                const Text(
                  '🔄 Habit Performance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                if (stats.habitCompletionCounts.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No habit data yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                  )
                else
                  ...stats.habitCompletionCounts.entries.map(
                    (entry) {
                      final maxValue = stats.habitCompletionCounts.values.fold<int>(0, (a, b) => a > b ? a : b);
                      final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${entry.value}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: percentage,
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMM d').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatWorkTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? detail,
    required Color color,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
