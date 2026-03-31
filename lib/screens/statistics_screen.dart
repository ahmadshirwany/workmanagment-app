import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_data_provider.dart';
import '../providers/gamification_provider.dart';
import '../services/shareable_wins_service.dart';
import 'achievements_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = '30d';
  final ShareableWinsService _shareableWinsService = ShareableWinsService();
  bool _isGeneratingShare = false;

  void _openAchievementsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AchievementsScreen(),
      ),
    );
  }

  void _openShareWinsSheet() {
    if (_isGeneratingShare) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shareable Wins',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate a social-ready PNG card and open native share sheet.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                ...ShareWinCardType.values.map((type) {
                  return ListTile(
                    leading: Icon(type.icon),
                    title: Text(type.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _generateShareCard(type);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateShareCard(ShareWinCardType type) async {
    if (_isGeneratingShare) return;

    setState(() {
      _isGeneratingShare = true;
    });

    try {
      final provider = context.read<AppDataProvider>();
      final gamificationProvider = context.read<GamificationProvider>();
      final monthlyStats = provider.getStatistics(timePeriod: '30d');
      final weeklyStats = provider.getStatistics(timePeriod: '7d');

      final data = ShareWinCardData(
        streakDays: monthlyStats.currentStreak,
        level: gamificationProvider.currentLevel,
        xp: gamificationProvider.currentXp,
        disciplineScore: gamificationProvider.currentDisciplineScore.value,
        weeklyCompletedTasks: weeklyStats.completedDailyTasks,
        weeklyTotalTasks: weeklyStats.totalDailyTasks,
        weeklyTaskCompletionRate: weeklyStats.dailyTaskCompletionRate,
        weeklyWorkHours: weeklyStats.totalWorkTimeSeconds / 3600.0,
        weeklyMaintenanceDays:
            gamificationProvider.getMaintenanceActiveDays(days: 7),
      );

      final filePath = await _shareableWinsService.generateWinCard(
        type: type,
        data: data,
      );

      if (!mounted) return;
      await _openNativeShareSheet(type, filePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate share card: $e'),
          backgroundColor: const Color(0xFFE65100),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingShare = false;
        });
      }
    }
  }

  Future<void> _openNativeShareSheet(
    ShareWinCardType type,
    String filePath,
  ) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Discipline Tracker • ${type.title}',
        text: _shareCaption(type),
      );

      if (!mounted) return;
      _showShareOpenedMessage(type, filePath);
    } catch (_) {
      if (!mounted) return;
      _showShareUnavailableMessage(type, filePath);
    }
  }

  String _shareCaption(ShareWinCardType type) {
    switch (type) {
      case ShareWinCardType.streakWin:
        return 'Consistency mode: ON. Sharing my latest streak win.';
      case ShareWinCardType.levelUp:
        return 'Level up unlocked. Sharing my discipline progress.';
      case ShareWinCardType.disciplineScore:
        return 'Here is my latest discipline score snapshot.';
      case ShareWinCardType.weeklyReport:
        return 'Weekly report generated. Momentum keeps building.';
    }
  }

  void _showShareOpenedMessage(ShareWinCardType type, String filePath) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(
            '${type.title} card ready. Share sheet opened.\nSaved at: $filePath',
          ),
        ),
      );
  }

  void _showShareUnavailableMessage(ShareWinCardType type, String filePath) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          backgroundColor: const Color(0xFFEF6C00),
          content: Text(
            'Share sheet unavailable. ${type.title} card saved at:\n$filePath',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isGeneratingShare
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.ios_share),
            onPressed: _isGeneratingShare ? null : _openShareWinsSheet,
            tooltip: 'Share Wins',
          ),
          IconButton(
            icon: const Icon(Icons.military_tech),
            onPressed: _openAchievementsScreen,
            tooltip: 'Achievements',
          ),
        ],
      ),
      body: Consumer2<AppDataProvider, GamificationProvider>(
        builder: (context, provider, gamificationProvider, child) {
          final stats = provider.getStatistics(timePeriod: _selectedPeriod);
          final score = gamificationProvider.currentDisciplineScore;
          final currentXp = gamificationProvider.currentXp;
          final currentLevel = gamificationProvider.currentLevel;
          final levelProgress = gamificationProvider.levelProgress;
          final xpToNext = gamificationProvider.xpToNextLevel;
          final maintenanceRate = gamificationProvider.getMaintenanceRate(days: 7);
          final maintenanceDays = gamificationProvider.getMaintenanceActiveDays(days: 7);
          final xpDailyData = _buildDailyXpSeries(gamificationProvider.dailyXpMap, days: 14);
          final trend = _computeTrend(xpDailyData);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Period Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: '7d',
                        label: Text('7 Days'),
                        icon: Icon(Icons.calendar_view_week),
                      ),
                      ButtonSegment<String>(
                        value: '30d',
                        label: Text('30 Days'),
                        icon: Icon(Icons.calendar_view_month),
                      ),
                      ButtonSegment<String>(
                        value: '90d',
                        label: Text('90 Days'),
                        icon: Icon(Icons.calendar_today),
                      ),
                      ButtonSegment<String>(
                        value: 'all',
                        label: Text('All Time'),
                        icon: Icon(Icons.history),
                      ),
                    ],
                    selected: <String>{_selectedPeriod},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedPeriod = newSelection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                _buildGamificationOverview(
                  scorePercent: score.value,
                  level: currentLevel,
                  xp: currentXp,
                  levelProgress: levelProgress,
                  xpToNext: xpToNext,
                  maintenanceRate: maintenanceRate,
                  maintenanceDays: maintenanceDays,
                  trendLabel: trend.$1,
                  trendIcon: trend.$2,
                  trendColor: trend.$3,
                ),
                const SizedBox(height: 16),

                _buildXpHistoryChart(xpDailyData),
                const SizedBox(height: 24),
                
                const Icon(
                  Icons.bar_chart,
                  size: 60,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),
                Text(
                  _getPeriodLabel(_selectedPeriod),
                  style: const TextStyle(
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
                  subtitle: 'Last 30 days',
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

  String _getPeriodLabel(String period) {
    switch (period) {
      case '7d':
        return '7-Day Statistics';
      case '90d':
        return '90-Day Statistics';
      case 'all':
        return 'All-Time Statistics';
      case '30d':
      default:
        return '30-Day Statistics';
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

  Widget _buildGamificationOverview({
    required double scorePercent,
    required int level,
    required int xp,
    required double levelProgress,
    required int xpToNext,
    required double maintenanceRate,
    required int maintenanceDays,
    required String trendLabel,
    required IconData trendIcon,
    required Color trendColor,
  }) {
    final safeScore = scorePercent.clamp(0, 100).toDouble();

    return Card(
      elevation: 3,
      shadowColor: const Color(0xFF1E88E5).withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Discipline XP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level $level  •  $xp XP',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildScoreRing(
                  scorePercent: safeScore,
                  size: 88,
                  strokeWidth: 12,
                  centerTextSize: 14,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              xpToNext > 0 ? '$xpToNext XP to next level' : 'Max level reached',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: levelProgress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFBBDEFB),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1E88E5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  trendLabel,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A69A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Maintenance $maintenanceDays/7',
                    style: const TextStyle(
                      color: Color(0xFF00796B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: maintenanceRate.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE0F2F1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF26A69A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpHistoryChart(List<MapEntry<String, int>> points) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'XP History (Last 14 Days)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track momentum and recovery over time',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: _chartMaxY(points),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: const Color(0xFFE0E0E0),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                      left: BorderSide(color: Colors.grey.shade300),
                      right: BorderSide.none,
                      top: BorderSide.none,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 34,
                        getTitlesWidget: (value, _) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 3,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }

                          final date = DateTime.tryParse(points[index].key);
                          final label = date == null
                              ? ''
                              : DateFormat('MM/dd').format(date);

                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.value.toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: const Color(0xFF1E88E5),
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF26A69A),
                            strokeColor: Colors.white,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E88E5).withOpacity(0.25),
                            const Color(0xFF1E88E5).withOpacity(0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRing({
    required double scorePercent,
    required double size,
    required double strokeWidth,
    required double centerTextSize,
  }) {
    final ratio = (scorePercent / 100).clamp(0.0, 1.0);
    final ringColor = scorePercent >= 90
        ? const Color(0xFF00C853)
        : scorePercent >= 70
            ? const Color(0xFF4CAF50)
            : scorePercent >= 50
                ? const Color(0xFFFFB300)
                : const Color(0xFFFF7043);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              centerSpaceRadius: (size / 2) - strokeWidth,
              sectionsSpace: 0,
              borderData: FlBorderData(show: false),
              sections: [
                PieChartSectionData(
                  value: ratio * 100,
                  color: ringColor,
                  radius: strokeWidth,
                  title: '',
                ),
                PieChartSectionData(
                  value: (1 - ratio) * 100,
                  color: const Color(0xFFE0E0E0),
                  radius: strokeWidth,
                  title: '',
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 700),
          ),
          Text(
            '${scorePercent.round()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: centerTextSize,
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _buildDailyXpSeries(
    Map<String, int> dailyXp, {
    required int days,
  }) {
    final now = DateTime.now();
    final list = <MapEntry<String, int>>[];

    for (int i = days - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      list.add(MapEntry(key, dailyXp[key] ?? 0));
    }

    return list;
  }

  (String, IconData, Color) _computeTrend(List<MapEntry<String, int>> points) {
    if (points.length < 14) {
      return ('Trend unavailable', Icons.trending_flat, Colors.grey);
    }

    final firstHalf = points.take(7).fold<int>(0, (sum, item) => sum + item.value);
    final secondHalf = points.skip(7).take(7).fold<int>(0, (sum, item) => sum + item.value);

    if (secondHalf > firstHalf) {
      return ('Momentum is rising', Icons.trending_up, const Color(0xFF2E7D32));
    }
    if (secondHalf < firstHalf) {
      return ('Momentum dipped this week', Icons.trending_down, const Color(0xFFD84315));
    }

    return ('Momentum is steady', Icons.trending_flat, const Color(0xFF546E7A));
  }

  double _chartMaxY(List<MapEntry<String, int>> points) {
    int maxY = 0;
    for (final point in points) {
      if (point.value > maxY) {
        maxY = point.value;
      }
    }

    if (maxY <= 20) return 20;
    return (maxY + 20).toDouble();
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
