import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_data_provider.dart';
import '../providers/ai_coach_provider.dart';
import '../providers/gamification_provider.dart';
import '../providers/home_navigation_provider.dart';
import '../services/shareable_wins_service.dart';
import 'achievements_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final TextEditingController _habitController = TextEditingController();
  final TextEditingController _taskController = TextEditingController();
  final ShareableWinsService _shareableWinsService = ShareableWinsService();
  Timer? _businessDayBoundaryTimer;
  late DateTime _selectedDate;
  bool _isGeneratingShare = false;
  String? _lastMotivationRequestDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = context.read<AppDataProvider>().getBusinessTodayDate();
    _scheduleBusinessDayBoundaryRefresh();
  }

  @override
  void dispose() {
    _businessDayBoundaryTimer?.cancel();
    _habitController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  void _scheduleBusinessDayBoundaryRefresh() {
    _businessDayBoundaryTimer?.cancel();
    final now = DateTime.now();
    var nextBoundary = DateTime(now.year, now.month, now.day, 6);
    if (!now.isBefore(nextBoundary)) {
      nextBoundary = nextBoundary.add(const Duration(days: 1));
    }

    _businessDayBoundaryTimer = Timer(nextBoundary.difference(now), () {
      if (!mounted) return;
      setState(() {
        _selectedDate = context.read<AppDataProvider>().getBusinessTodayDate();
      });
      _scheduleBusinessDayBoundaryRefresh();
    });
  }

  void _showRestrictionMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFE65100),
        ),
      );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _showAddHabitDialog() {
    final provider = context.read<AppDataProvider>();
    final selectedDateString = _formatDate(_selectedDate);
    if (!provider.canEditHabitsForDate(selectedDateString)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'habits', date: selectedDateString),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Habit'),
          content: TextField(
            controller: _habitController,
            decoration: const InputDecoration(
              hintText: 'Enter habit name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _addHabit(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _habitController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addHabit,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addHabit() {
    final provider = context.read<AppDataProvider>();
    final selectedDateString = _formatDate(_selectedDate);
    if (!provider.canEditHabitsForDate(selectedDateString)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'habits', date: selectedDateString),
      );
      return;
    }

    if (_habitController.text.trim().isNotEmpty) {
      provider.addHabit(_habitController.text.trim());
      _habitController.clear();
      Navigator.pop(context);
    }
  }

  void _showAddTaskDialog() {
    final provider = context.read<AppDataProvider>();
    final selectedDateString = _formatDate(_selectedDate);
    if (!provider.canEditTasksForDate(selectedDateString)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'tasks', date: selectedDateString),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Daily Task'),
          content: TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              hintText: 'Enter task name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _addTask(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addTask() {
    if (_taskController.text.trim().isNotEmpty) {
      final dateString = _formatDate(_selectedDate);
      final provider = context.read<AppDataProvider>();
      if (!provider.canEditTasksForDate(dateString)) {
        _showRestrictionMessage(
          provider.getRestrictionMessage(domain: 'tasks', date: dateString),
        );
        return;
      }

      provider.addDailyTask(dateString, _taskController.text.trim());
      _taskController.clear();
      Navigator.pop(context);
    }
  }

  void _showEditHabitDialog(String oldHabitName) {
    final provider = context.read<AppDataProvider>();
    final selectedDateString = _formatDate(_selectedDate);
    if (!provider.canEditHabitsForDate(selectedDateString)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'habits', date: selectedDateString),
      );
      return;
    }

    _habitController.text = oldHabitName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Habit'),
          content: TextField(
            controller: _habitController,
            decoration: const InputDecoration(
              hintText: 'Enter new habit name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _updateHabit(oldHabitName),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _habitController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _updateHabit(oldHabitName),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateHabit(String oldHabitName) {
    final provider = context.read<AppDataProvider>();
    final selectedDateString = _formatDate(_selectedDate);
    if (!provider.canEditHabitsForDate(selectedDateString)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'habits', date: selectedDateString),
      );
      return;
    }

    if (_habitController.text.trim().isNotEmpty) {
      provider.updateHabit(oldHabitName, _habitController.text.trim());
      _habitController.clear();
      Navigator.pop(context);
    }
  }

  void _showEditTaskDialog(String date, String taskId, String oldTaskName) {
    final provider = context.read<AppDataProvider>();
    if (!provider.canEditTasksForDate(date)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'tasks', date: date),
      );
      return;
    }

    _taskController.text = oldTaskName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              hintText: 'Enter new task name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _updateTask(date, taskId),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _updateTask(date, taskId),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateTask(String date, String taskId) {
    final provider = context.read<AppDataProvider>();
    if (!provider.canEditTasksForDate(date)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'tasks', date: date),
      );
      return;
    }

    if (_taskController.text.trim().isNotEmpty) {
      provider.updateDailyTask(date, taskId, _taskController.text.trim());
      _taskController.clear();
      Navigator.pop(context);
    }
  }

  void _confirmDeleteHabit(String habit) {
    final provider = context.read<AppDataProvider>();
    final selectedDateString = _formatDate(_selectedDate);
    if (!provider.canEditHabitsForDate(selectedDateString)) {
      _showRestrictionMessage(
        provider.getRestrictionMessage(domain: 'habits', date: selectedDateString),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Habit'),
          content: Text('Are you sure you want to delete "$habit"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<AppDataProvider>(context, listen: false)
                    .removeHabit(habit);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

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
        return 'Daily grind update: another streak win unlocked.';
      case ShareWinCardType.levelUp:
        return 'Level up unlocked. Sharing my progress today.';
      case ShareWinCardType.disciplineScore:
        return 'Latest discipline score snapshot from my tracker.';
      case ShareWinCardType.weeklyReport:
        return 'Weekly report generated. Small actions, big momentum.';
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

  void _maybeEnsureDailyMotivation(
    AppDataProvider appDataProvider,
    AICoachProvider aiCoachProvider,
  ) {
    if (!aiCoachProvider.isInitialized || aiCoachProvider.isLoading) return;

    final today = appDataProvider.getTodayDateString();
    final currentDate = aiCoachProvider.dailyMotivation['date'] as String?;

    if (currentDate == today) {
      _lastMotivationRequestDate = today;
      return;
    }

    if (_lastMotivationRequestDate == today) return;
    _lastMotivationRequestDate = today;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AICoachProvider>().ensureDailyMotivationForToday();
    });
  }

  Future<void> _openCoachFromMotivation(
    AppDataProvider appDataProvider,
    AICoachProvider aiCoachProvider,
  ) async {
    final weakHabit = appDataProvider.getWeakestHabitName(timePeriod: '30d') ??
        'my weakest habit';
    final motivation =
        (aiCoachProvider.dailyMotivation['message'] as String? ?? '').trim();

    final contextPrompt = motivation.isEmpty
        ? 'Help me build a practical plan for today to improve $weakHabit.'
        : 'My daily motivation says: "$motivation". Turn this into a concrete plan for today focused on $weakHabit.';

    aiCoachProvider.setPendingCoachContext(contextPrompt);
    await aiCoachProvider.markDailyMotivationSeen();

    if (!mounted) return;
    context.read<HomeNavigationProvider>().requestTab(2);
  }

  Future<void> _dismissMotivationCard(AICoachProvider aiCoachProvider) async {
    await aiCoachProvider.markDailyMotivationSeen();
  }

  Widget _buildDailyMotivationCard(
    AppDataProvider appDataProvider,
    AICoachProvider aiCoachProvider,
  ) {
    final data = aiCoachProvider.dailyMotivation;
    final message = (data['message'] as String? ?? '').trim();
    final isPositive = data['isPositive'] == true;
    final source = (data['source'] as String? ?? 'local').toUpperCase();

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? const [Color(0xFF1E88E5), Color(0xFF26A69A)]
              : const [Color(0xFF6D4C41), Color(0xFF8D6E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daily Motivation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  source,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              height: 1.35,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _openCoachFromMotivation(
                  appDataProvider,
                  aiCoachProvider,
                ),
                icon: const Icon(Icons.psychology_alt, size: 18),
                label: const Text('Ask Coach'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1565C0),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _dismissMotivationCard(aiCoachProvider),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
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
        title: const Text('Daily Tasks'),
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
      body: Consumer3<AppDataProvider, GamificationProvider, AICoachProvider>(
        builder: (context, provider, gamificationProvider, aiCoachProvider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          _maybeEnsureDailyMotivation(provider, aiCoachProvider);

          final selectedDateString = _formatDate(_selectedDate);
            final canEditHabits = provider.canEditHabitsForDate(selectedDateString);
            final canEditTasks = provider.canEditTasksForDate(selectedDateString);
            final canToggleVacation =
              provider.canToggleVacationForDate(selectedDateString);
          final activeHabitNames = provider.getActiveHabitsForDate(selectedDateString);
          final dailyTasks = provider.getDailyTasks(selectedDateString);
          final disciplineScore = gamificationProvider.currentDisciplineScore.value;
          final level = gamificationProvider.currentLevel;
          final currentXp = gamificationProvider.currentXp;
          final xpToNext = gamificationProvider.xpToNextLevel;
          final levelProgress = gamificationProvider.levelProgress;
          final maintenanceRate = gamificationProvider.getMaintenanceRate(days: 7);
          final maintenanceDays = gamificationProvider.getMaintenanceActiveDays(days: 7);

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildGamificationPanel(
                context,
                disciplineScore: disciplineScore,
                level: level,
                currentXp: currentXp,
                xpToNext: xpToNext,
                levelProgress: levelProgress,
                maintenanceRate: maintenanceRate,
                maintenanceDays: maintenanceDays,
              ),

              if (aiCoachProvider.shouldShowDailyMotivationCard)
                _buildDailyMotivationCard(provider, aiCoachProvider),

              // Date Selector
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2196F3)),
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
                                  const Icon(Icons.calendar_today, color: Color(0xFF2196F3), size: 20),
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
                        icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF2196F3)),
                        onPressed: _nextDay,
                        tooltip: 'Next Day',
                      ),
                    ],
                  ),
                ),
              ),

              // Holiday Toggle
              Consumer<AppDataProvider>(
                builder: (context, provider, child) {
                  final isHoliday = provider.isHoliday(selectedDateString);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: isHoliday ? Colors.orange[50] : null,
                    child: InkWell(
                      onTap: canToggleVacation
                          ? () {
                              provider.toggleHoliday(selectedDateString);
                            }
                          : () {
                              _showRestrictionMessage(
                                provider.getRestrictionMessage(
                                  domain: 'vacation',
                                  date: selectedDateString,
                                ),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isHoliday ? Icons.beach_access : Icons.work_outline,
                                  color: isHoliday ? Colors.orange : Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isHoliday ? 'Holiday/Vacation Day' : 'Mark as Holiday/Vacation',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isHoliday ? FontWeight.w600 : FontWeight.normal,
                                      color: isHoliday ? Colors.orange[800] : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isHoliday,
                                  onChanged: canToggleVacation
                                      ? (_) {
                                          provider.toggleHoliday(
                                            selectedDateString,
                                          );
                                        }
                                      : null,
                                  activeColor: Colors.orange,
                                ),
                              ],
                            ),
                            if (isHoliday)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 36),
                                child: Text(
                                  'This day will not be included in statistics',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            if (!canToggleVacation)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 36),
                                child: Text(
                                  provider.getRestrictionMessage(
                                    domain: 'vacation',
                                    date: selectedDateString,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // HABITS Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🔄 Recurring Habits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF2196F3)),
                          onPressed: canEditHabits
                              ? _showAddHabitDialog
                              : () {
                                  _showRestrictionMessage(
                                    provider.getRestrictionMessage(
                                      domain: 'habits',
                                      date: selectedDateString,
                                    ),
                                  );
                                },
                          tooltip: 'Add Habit',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!canEditHabits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          provider.getRestrictionMessage(
                            domain: 'habits',
                            date: selectedDateString,
                          ),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),

                    if (activeHabitNames.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No recurring habits yet. Tap + to add one!',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...activeHabitNames.map((habit) {
                        final isCompleted = provider.isHabitCompleted(habit, selectedDateString);
                        final streak = provider.getHabitStreak(habit);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: canEditHabits
                                  ? (_) {
                                      provider.toggleHabit(
                                        habit,
                                        selectedDateString,
                                      );
                                    }
                                  : null,
                              activeColor: const Color(0xFF4CAF50),
                            ),
                            title: Text(
                              habit,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            subtitle: streak > 0
                                ? Row(
                                    children: [
                                      const Text('🔥'),
                                      const SizedBox(width: 4),
                                      Text('$streak day${streak > 1 ? 's' : ''} streak'),
                                    ],
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                                  onPressed: canEditHabits
                                      ? () => _showEditHabitDialog(habit)
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: canEditHabits
                                      ? () => _confirmDeleteHabit(habit)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // DAILY TASKS Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📝 Daily Tasks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF9C27B0)),
                          onPressed: canEditTasks
                              ? _showAddTaskDialog
                              : () {
                                  _showRestrictionMessage(
                                    provider.getRestrictionMessage(
                                      domain: 'tasks',
                                      date: selectedDateString,
                                    ),
                                  );
                                },
                          tooltip: 'Add Task',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!canEditTasks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          provider.getRestrictionMessage(
                            domain: 'tasks',
                            date: selectedDateString,
                          ),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ),

                    if (dailyTasks.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No tasks for this day. Tap + to add one!',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...dailyTasks.map((task) {
                        final taskId = task['id'] as String;
                        final taskName = task['name'] as String;
                        final isCompleted = task['completed'] as bool;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.purple[50],
                          child: ListTile(
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: canEditTasks
                                  ? (_) {
                                      provider.toggleDailyTask(
                                        selectedDateString,
                                        taskId,
                                      );
                                    }
                                  : null,
                              activeColor: const Color(0xFF9C27B0),
                            ),
                            title: Text(
                              taskName,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF9C27B0)),
                                  onPressed: canEditTasks
                                      ? () => _showEditTaskDialog(
                                            selectedDateString,
                                            taskId,
                                            taskName,
                                          )
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: canEditTasks
                                      ? () {
                                          provider.removeDailyTask(
                                            selectedDateString,
                                            taskId,
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGamificationPanel(
    BuildContext context, {
    required double disciplineScore,
    required int level,
    required int currentXp,
    required int xpToNext,
    required double levelProgress,
    required double maintenanceRate,
    required int maintenanceDays,
  }) {
    final safeScore = disciplineScore.clamp(0, 100).toDouble();
    final scoreColor = safeScore >= 90
        ? const Color(0xFF00C853)
        : safeScore >= 70
            ? const Color(0xFF4CAF50)
            : safeScore >= 50
                ? const Color(0xFFFFB300)
                : const Color(0xFFFF7043);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF26A69A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.military_tech, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                '$currentXp XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discipline Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${safeScore.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (safeScore > 90)
                      const Text(
                        'Elite momentum!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      xpToNext > 0
                          ? '$xpToNext XP to next level'
                          : 'Max level reached',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: levelProgress.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFF176),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildScoreRing(
                score: safeScore,
                ringColor: scoreColor,
                size: 118,
                strokeWidth: 14,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMaintenanceRing(
                value: maintenanceRate,
                size: 54,
                strokeWidth: 9,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '7-Day Maintenance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$maintenanceDays active days hitting 20+ XP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRing({
    required double score,
    required Color ringColor,
    required double size,
    required double strokeWidth,
  }) {
    final ratio = (score / 100).clamp(0.0, 1.0);

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
                  color: const Color(0x33FFFFFF),
                  radius: strokeWidth,
                  title: '',
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 700),
          ),
          Text(
            '${score.round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceRing({
    required double value,
    required double size,
    required double strokeWidth,
  }) {
    final ratio = value.clamp(0.0, 1.0);

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
                  color: const Color(0xFFFFF176),
                  radius: strokeWidth,
                  title: '',
                ),
                PieChartSectionData(
                  value: (1 - ratio) * 100,
                  color: const Color(0x33FFFFFF),
                  radius: strokeWidth,
                  title: '',
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 700),
          ),
          Text(
            '${(ratio * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
