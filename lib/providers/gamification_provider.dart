import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/achievement.dart';
import '../models/discipline_score.dart';
import '../models/user_level.dart';
import '../models/xp_transaction.dart';
import 'app_data_provider.dart';

class GamificationProvider extends ChangeNotifier {
  static const int _habitCompletionXp = 10;
  static const int _taskCompletionXp = 5;
  static const int _workSessionChunkXp = 25;
  static const int _workSessionChunkSeconds = 25 * 60;

  static const int _dailyTargetXp = 20;
  static const int _dailyDecayPenalty = 10;
  static const int _weeklyDecayCap = 50;
  static const int _streakBreakPenalty = 25;
  static const int _recoveryBonusXp = 50;

  static const List<Map<String, dynamic>> _dailyChallengeTemplates = [
    {
      'id': 'daily_tasks_5',
      'type': 'tasks_completed_today',
      'title': 'Complete 5 tasks today',
      'description': 'Finish at least 5 daily tasks to earn a bonus.',
      'target': 5.0,
      'rewardXp': 50,
    },
    {
      'id': 'daily_habits_3',
      'type': 'habits_completed_today',
      'title': 'Complete 3 habits today',
      'description': 'Lock in at least 3 habit checkmarks today.',
      'target': 3.0,
      'rewardXp': 50,
    },
    {
      'id': 'daily_focus_25m',
      'type': 'focused_minutes_today',
      'title': 'Focus for 25 minutes today',
      'description': 'Log one focused 25-minute session.',
      'target': 25.0,
      'rewardXp': 50,
    },
  ];

  static const List<Map<String, dynamic>> _weeklyChallengeTemplates = [
    {
      'id': 'weekly_work_10h',
      'type': 'focused_hours_week',
      'title': 'Log 10 focused hours this week',
      'description': 'Build deep momentum with 10 total focus hours.',
      'target': 10.0,
      'rewardXp': 200,
    },
    {
      'id': 'weekly_tasks_30',
      'type': 'tasks_completed_week',
      'title': 'Complete 30 tasks this week',
      'description': 'Close out 30 tasks before the week ends.',
      'target': 30.0,
      'rewardXp': 200,
    },
    {
      'id': 'weekly_active_5',
      'type': 'active_days_week',
      'title': 'Hit 20+ XP on 5 days',
      'description': 'Stay active at least 5 days this week.',
      'target': 5.0,
      'rewardXp': 200,
    },
  ];

  static const Uuid _uuid = Uuid();

  AppDataProvider? _appDataProvider;
  bool _maintenanceRunning = false;
  bool _bindInitializationScheduled = false;
  XpTransaction? _lastTransaction;

  XpTransaction? get lastTransaction => _lastTransaction;

  int get currentXp => _appDataProvider?.data.xp ?? 0;
  int get currentLevel => _appDataProvider?.data.level ?? 1;
  double get levelProgress => UserLevelSystem.progressToNextLevel(currentXp);
  int get xpToNextLevel => UserLevelSystem.xpToNextLevel(currentXp);
  int get currentLevelMinXp => UserLevelSystem.minXpForLevel(currentLevel);
  int? get currentLevelMaxXp => UserLevelSystem.maxXpForLevel(currentLevel);

  Map<String, int> get dailyXpMap {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return {};
    return Map<String, int>.from(provider.data.dailyXp);
  }

  List<XpTransaction> get xpHistory {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return const [];

    return provider.data.xpTransactions
        .map(XpTransaction.fromJson)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int getMaintenanceActiveDays({int days = 7}) {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading || days <= 0) return 0;

    final now = _dateOnly(DateTime.now());
    final start = now.subtract(Duration(days: days - 1));
    final dailyXp = provider.data.dailyXp;
    int activeDays = 0;

    DateTime cursor = start;
    while (!cursor.isAfter(now)) {
      final dateKey = _formatDate(cursor);
      if (!provider.isHoliday(dateKey) && (dailyXp[dateKey] ?? 0) >= _dailyTargetXp) {
        activeDays++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return activeDays;
  }

  double getMaintenanceRate({int days = 7}) {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading || days <= 0) return 0;

    final now = _dateOnly(DateTime.now());
    final start = now.subtract(Duration(days: days - 1));
    int eligibleDays = 0;
    DateTime cursor = start;

    while (!cursor.isAfter(now)) {
      final dateKey = _formatDate(cursor);
      if (!provider.isHoliday(dateKey)) {
        eligibleDays++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (eligibleDays == 0) return 1.0;
    return getMaintenanceActiveDays(days: days) / eligibleDays;
  }

  String get todayDateKey => _formatDate(DateTime.now());

  DisciplineScore get currentDisciplineScore => DisciplineScore.fromJson(
        _appDataProvider?.data.disciplineScore ?? const {},
      );

  List<Achievement> get achievements =>
      _hydrateAchievements(_appDataProvider?.data.achievements ?? const []);

  Map<String, dynamic> getDailyChallengeData() {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return _emptyChallengeData('daily');
    }

    final today = _dateOnly(DateTime.now());
    final dateKey = _formatDate(today);
    final template = _dailyChallengeTemplates[
        _dayOfYear(today) % _dailyChallengeTemplates.length];

    final target = (template['target'] as num).toDouble();
    final progress = _calculateDailyChallengeProgress(
      template['type'] as String,
      dateKey,
    );
    final claimed = _readClaimMap('dailyChallengeClaims')[dateKey] == true;
    final completed = progress >= target;

    return {
      ...template,
      'scope': 'daily',
      'dateKey': dateKey,
      'progress': progress,
      'progressLabel': _challengeProgressLabel(
        template['type'] as String,
        progress,
        target,
      ),
      'isCompleted': completed,
      'isClaimed': claimed,
    };
  }

  Map<String, dynamic> getWeeklyChallengeData() {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return _emptyChallengeData('weekly');
    }

    final today = _dateOnly(DateTime.now());
    final weekKey = _weekKey(today);
    final template = _weeklyChallengeTemplates[
        _weekOfYear(today) % _weeklyChallengeTemplates.length];

    final target = (template['target'] as num).toDouble();
    final progress = _calculateWeeklyChallengeProgress(
      template['type'] as String,
      today,
    );
    final claimed = _readClaimMap('weeklyChallengeClaims')[weekKey] == true;
    final completed = progress >= target;

    return {
      ...template,
      'scope': 'weekly',
      'weekKey': weekKey,
      'progress': progress,
      'progressLabel': _challengeProgressLabel(
        template['type'] as String,
        progress,
        target,
      ),
      'isCompleted': completed,
      'isClaimed': claimed,
    };
  }

  Future<(bool, String)> claimDailyChallengeReward() async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return (false, 'Challenge data is not ready yet.');
    }

    final challenge = getDailyChallengeData();
    final dateKey = challenge['dateKey'] as String? ?? todayDateKey;

    if (challenge['isClaimed'] == true) {
      return (false, 'Daily challenge reward already claimed.');
    }

    if (challenge['isCompleted'] != true) {
      return (false, 'Complete the daily challenge before claiming reward.');
    }

    final rewardXp = (challenge['rewardXp'] as num?)?.toInt() ?? 0;

    await awardXp(
      rewardXp,
      reason: 'Daily challenge reward claimed',
      type: 'daily_challenge_reward',
      applyStreakMultiplier: false,
      eventDate: dateKey,
    );

    final claimMap = _readClaimMap('dailyChallengeClaims');
    claimMap[dateKey] = true;
    await _updateClaimMap('dailyChallengeClaims', claimMap);

    notifyListeners();
    return (true, '+$rewardXp XP claimed from daily challenge!');
  }

  Future<(bool, String)> claimWeeklyChallengeReward() async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return (false, 'Challenge data is not ready yet.');
    }

    final challenge = getWeeklyChallengeData();
    final weekKey = challenge['weekKey'] as String? ?? _weekKey(DateTime.now());

    if (challenge['isClaimed'] == true) {
      return (false, 'Weekly challenge reward already claimed.');
    }

    if (challenge['isCompleted'] != true) {
      return (false, 'Complete the weekly challenge before claiming reward.');
    }

    final rewardXp = (challenge['rewardXp'] as num?)?.toInt() ?? 0;

    await awardXp(
      rewardXp,
      reason: 'Weekly challenge reward claimed',
      type: 'weekly_challenge_reward',
      applyStreakMultiplier: false,
      eventDate: todayDateKey,
      counterDeltas: const {'weeklyChallengesCompleted': 1},
    );

    final claimMap = _readClaimMap('weeklyChallengeClaims');
    claimMap[weekKey] = true;
    await _updateClaimMap('weeklyChallengeClaims', claimMap);

    notifyListeners();
    return (true, '+$rewardXp XP claimed from weekly challenge!');
  }

  void bind(AppDataProvider provider) {
    final providerChanged = !identical(_appDataProvider, provider);
    _appDataProvider = provider;
    provider.setGamificationEventHandler(_handleActivityEvent);

    if (providerChanged) {
      _bindInitializationScheduled = false;
    }

    if (_bindInitializationScheduled || provider.isLoading) return;

    _bindInitializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentProvider = _appDataProvider;
      if (currentProvider == null) {
        _bindInitializationScheduled = false;
        return;
      }

      if (currentProvider.isLoading) {
        _bindInitializationScheduled = false;
        return;
      }

      unawaited(_initializeAndMaintain());
    });
  }

  Future<void> _initializeAndMaintain() async {
    await _ensureDefaults();
    await runMaintenanceCheck(trigger: 'provider_bind');
  }

  Future<void> _ensureDefaults() async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return;

    final data = provider.data;
    final today = _formatDate(DateTime.now());
    final stats = provider.getStatistics(timePeriod: '30d');

    bool updateNeeded = false;

    final normalizedLevel = UserLevelSystem.levelForXp(data.xp);
    if (normalizedLevel != data.level) {
      updateNeeded = true;
    }

    final hydratedAchievements = _hydrateAchievements(data.achievements);
    if (data.achievements.length != hydratedAchievements.length) {
      updateNeeded = true;
    }

    final normalizedCounters = _normalizeCounterMap(data.gamificationCounters);
    if (normalizedCounters.length != data.gamificationCounters.length) {
      updateNeeded = true;
    }

    final normalizedDailyXp = _normalizeCounterMap(data.dailyXp);
    if (normalizedDailyXp.length != data.dailyXp.length) {
      updateNeeded = true;
    }

    final updatedMeta = Map<String, dynamic>.from(data.gamificationMeta);
    if (!updatedMeta.containsKey('onboardingDate')) {
      updatedMeta['onboardingDate'] = today;
      updateNeeded = true;
    }
    if (!updatedMeta.containsKey('lastMaintenanceDate')) {
      updatedMeta['lastMaintenanceDate'] = today;
      updateNeeded = true;
    }
    if (!updatedMeta.containsKey('consecutiveInactiveDays')) {
      updatedMeta['consecutiveInactiveDays'] = 0;
      updateNeeded = true;
    }
    if (!updatedMeta.containsKey('weeklyDecayApplied')) {
      updatedMeta['weeklyDecayApplied'] = <String, int>{};
      updateNeeded = true;
    }
    if (!updatedMeta.containsKey('currentStreakSnapshot')) {
      updatedMeta['currentStreakSnapshot'] = stats.currentStreak;
      updateNeeded = true;
    }

    final score = calculateDisciplineScore();
    if (data.disciplineScore.isEmpty) {
      updateNeeded = true;
    }

    if (!updateNeeded) return;

    await provider.updateGamificationData(
      xp: data.xp,
      level: normalizedLevel,
      achievements: hydratedAchievements.map((item) => item.toJson()).toList(),
      disciplineScore: score.toJson(),
      gamificationMeta: updatedMeta,
      gamificationCounters: normalizedCounters,
      dailyXp: normalizedDailyXp,
    );
  }

  Future<void> runMaintenanceCheck({String trigger = 'manual'}) async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading || _maintenanceRunning) return;

    _maintenanceRunning = true;
    try {
      await _ensureDefaults();

      final data = provider.data;
      final meta = Map<String, dynamic>.from(data.gamificationMeta);
      final onboardingDate = _parseDate(meta['onboardingDate'] as String?) ??
          _dateOnly(DateTime.now());
      final lastMaintenanceDate =
          _parseDate(meta['lastMaintenanceDate'] as String?);

      final today = _dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final startDate = lastMaintenanceDate ?? onboardingDate;

      if (startDate.isAfter(yesterday)) {
        return;
      }

      final initialLevel = provider.data.level;
      final minAllowedLevel = initialLevel > 1 ? initialLevel - 1 : 1;

      int consecutiveInactiveDays =
          (meta['consecutiveInactiveDays'] as num?)?.toInt() ?? 0;
      final weeklyDecayApplied = _normalizeWeekDecayMap(meta['weeklyDecayApplied']);
      final dailyXp = _normalizeCounterMap(provider.data.dailyXp);

      DateTime cursor = startDate;
      while (!cursor.isAfter(yesterday)) {
        final dateKey = _formatDate(cursor);
        final daysSinceOnboarding =
            _dateOnly(cursor).difference(_dateOnly(onboardingDate)).inDays;

        if (daysSinceOnboarding < 7) {
          cursor = cursor.add(const Duration(days: 1));
          continue;
        }

        final earnedXp = dailyXp[dateKey] ?? 0;
        if (earnedXp < _dailyTargetXp) {
          consecutiveInactiveDays += 1;

          final weekKey = _weekKey(cursor);
          final alreadyApplied = weeklyDecayApplied[weekKey] ?? 0;
          final remaining = _weeklyDecayCap - alreadyApplied;

          if (remaining > 0) {
            final penalty = remaining < _dailyDecayPenalty
                ? remaining
                : _dailyDecayPenalty;
            if (penalty > 0) {
              await subtractXp(
                penalty,
                reason: 'Low activity on $dateKey (under $_dailyTargetXp XP)',
                type: 'daily_decay',
                applyStreakMultiplier: false,
                eventDate: dateKey,
                minLevelAllowed: minAllowedLevel,
              );
              weeklyDecayApplied[weekKey] = alreadyApplied + penalty;
            }
          }
        } else {
          if (consecutiveInactiveDays >= 3) {
            await awardXp(
              _recoveryBonusXp,
              reason:
                  'Recovery bonus after $consecutiveInactiveDays low-activity days',
              type: 'recovery_bonus',
              applyStreakMultiplier: false,
              eventDate: dateKey,
              metadata: {'inactiveDays': consecutiveInactiveDays},
            );
            meta['lastRecoveryBonusDate'] = dateKey;
          }
          consecutiveInactiveDays = 0;
        }

        cursor = cursor.add(const Duration(days: 1));
      }

      final refreshedStats = provider.getStatistics(timePeriod: '30d');
      final previousStreakSnapshot =
          (meta['currentStreakSnapshot'] as num?)?.toInt() ?? 0;
      final currentStreak = refreshedStats.currentStreak;

      if (previousStreakSnapshot > 0 && currentStreak == 0) {
        final lastStreakPenaltyDate = meta['lastStreakPenaltyDate'] as String?;
        final todayKey = _formatDate(today);
        if (lastStreakPenaltyDate != todayKey) {
          await subtractXp(
            _streakBreakPenalty,
            reason: 'Streak break penalty',
            type: 'streak_break_penalty',
            applyStreakMultiplier: false,
            eventDate: todayKey,
            minLevelAllowed: minAllowedLevel,
          );
          meta['lastStreakPenaltyDate'] = todayKey;
        }
      }

      if (currentStreak > 0) {
        meta['lastStreakPenaltyDate'] = null;
      }

      meta['lastMaintenanceDate'] = _formatDate(today);
      meta['lastMaintenanceTrigger'] = trigger;
      meta['consecutiveInactiveDays'] = consecutiveInactiveDays;
      meta['currentStreakSnapshot'] = currentStreak;
      meta['weeklyDecayApplied'] = weeklyDecayApplied;
      meta['lastActiveDate'] = _resolveLastActiveDate(provider.data.dailyXp);

      await provider.updateGamificationData(
        gamificationMeta: meta,
        level: UserLevelSystem.levelForXp(provider.data.xp),
        disciplineScore: calculateDisciplineScore().toJson(),
      );

      notifyListeners();
    } finally {
      _maintenanceRunning = false;
    }
  }

  Future<void> awardXp(
    int baseAmount, {
    required String reason,
    required String type,
    bool applyStreakMultiplier = true,
    String? eventDate,
    Map<String, dynamic> metadata = const {},
    Map<String, int> counterDeltas = const {},
  }) async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading || baseAmount <= 0) return;

    await _ensureDefaults();

    final multiplier = applyStreakMultiplier ? _getStreakMultiplier() : 1.0;
    final amount = (baseAmount * multiplier).round();
    if (amount <= 0) return;

    final data = provider.data;
    final dateKey = eventDate ?? _formatDate(DateTime.now());
    final newXp = data.xp + amount;
    final newLevel = UserLevelSystem.levelForXp(newXp);

    final transaction = XpTransaction(
      id: _uuid.v4(),
      amount: amount,
      reason: reason,
      type: type,
      date: dateKey,
      createdAt: DateTime.now(),
      metadata: {
        ...metadata,
        'baseAmount': baseAmount,
        'multiplier': multiplier,
      },
    );

    final updatedDailyXp = _normalizeCounterMap(data.dailyXp);
    updatedDailyXp[dateKey] = (updatedDailyXp[dateKey] ?? 0) + amount;

    final updatedCounters =
        _applyCounterDeltas(data.gamificationCounters, counterDeltas);
    final updatedAchievements = _evaluateAchievements(updatedCounters, newLevel);

    final updatedMeta = Map<String, dynamic>.from(data.gamificationMeta)
      ..['lastXpChangeDate'] = dateKey
      ..['lastXpReason'] = reason;

    await provider.updateGamificationData(
      xp: newXp,
      level: newLevel,
      xpTransactions: _appendTransaction(data.xpTransactions, transaction),
      achievements: updatedAchievements.map((item) => item.toJson()).toList(),
      dailyXp: updatedDailyXp,
      gamificationCounters: updatedCounters,
      disciplineScore: calculateDisciplineScore().toJson(),
      gamificationMeta: updatedMeta,
    );

    _lastTransaction = transaction;
    notifyListeners();
  }

  Future<void> subtractXp(
    int amount, {
    required String reason,
    required String type,
    bool applyStreakMultiplier = false,
    String? eventDate,
    int? minLevelAllowed,
    Map<String, dynamic> metadata = const {},
  }) async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading || amount <= 0) return;

    await _ensureDefaults();

    final data = provider.data;
    final dateKey = eventDate ?? _formatDate(DateTime.now());

    int nextXp = data.xp - amount;
    if (nextXp < 0) {
      nextXp = 0;
    }

    if (minLevelAllowed != null && minLevelAllowed >= 1) {
      final minAllowedXp = UserLevelSystem.minXpForLevel(minLevelAllowed);
      if (nextXp < minAllowedXp) {
        nextXp = minAllowedXp;
      }
    }

    final nextLevel = UserLevelSystem.levelForXp(nextXp);

    final transaction = XpTransaction(
      id: _uuid.v4(),
      amount: -amount,
      reason: reason,
      type: type,
      date: dateKey,
      createdAt: DateTime.now(),
      metadata: {
        ...metadata,
        'multiplierApplied': applyStreakMultiplier,
      },
    );

    final updatedAchievements = _evaluateAchievements(
      data.gamificationCounters,
      nextLevel,
    );

    final updatedMeta = Map<String, dynamic>.from(data.gamificationMeta)
      ..['lastXpChangeDate'] = dateKey
      ..['lastXpReason'] = reason;

    await provider.updateGamificationData(
      xp: nextXp,
      level: nextLevel,
      xpTransactions: _appendTransaction(data.xpTransactions, transaction),
      achievements: updatedAchievements.map((item) => item.toJson()).toList(),
      disciplineScore: calculateDisciplineScore().toJson(),
      gamificationMeta: updatedMeta,
    );

    _lastTransaction = transaction;
    notifyListeners();
  }

  DisciplineScore calculateDisciplineScore() {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return DisciplineScore.empty();
    }

    final monthly = provider.getStatistics(timePeriod: '30d');
    final weekly = provider.getStatistics(timePeriod: '7d');

    final streakScore = _clamp01(monthly.currentStreak / 30);
    final completionScore = _clamp01(monthly.overallCompletionRate);
    final weeklyFocusedHours = weekly.totalWorkTimeSeconds / 3600.0;
    final workTimeScore = _clamp01(weeklyFocusedHours / 10.0);

    final total = (streakScore * 0.4) +
        (completionScore * 0.3) +
        (workTimeScore * 0.3);

    return DisciplineScore(
      value: total * 100,
      streakComponent: streakScore,
      completionComponent: completionScore,
      workTimeComponent: workTimeScore,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _handleActivityEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    switch (eventType) {
      case 'habit_completed':
        final date = payload['date'] as String? ?? _formatDate(DateTime.now());
        final hour = (payload['hour'] as num?)?.toInt() ?? DateTime.now().hour;
        final deltas = <String, int>{'habitCompletions': 1};
        if (hour < 8) {
          deltas['morningHabitCompletions'] = 1;
        }
        await awardXp(
          _habitCompletionXp,
          reason: 'Habit completed',
          type: 'habit_completion',
          eventDate: date,
          counterDeltas: deltas,
        );
        break;
      case 'task_completed':
        await awardXp(
          _taskCompletionXp,
          reason: 'Task completed',
          type: 'task_completion',
          eventDate: payload['date'] as String? ?? _formatDate(DateTime.now()),
          counterDeltas: const {'taskCompletions': 1},
        );
        break;
      case 'work_session_completed':
        final duration = (payload['duration'] as num?)?.toInt() ?? 0;
        final date = payload['date'] as String? ?? _formatDate(DateTime.now());
        final endHour =
            (payload['endHour'] as num?)?.toInt() ?? DateTime.now().hour;

        if (duration <= 0) return;

        final chunks = duration ~/ _workSessionChunkSeconds;
        final deltas = <String, int>{'workTimeSeconds': duration};
        if (endHour >= 20) {
          deltas['eveningWorkSessions'] = 1;
        }

        if (chunks <= 0) {
          await _updateCountersOnly(deltas);
          return;
        }

        await awardXp(
          _workSessionChunkXp * chunks,
          reason: 'Focused work session completed',
          type: 'work_session_completion',
          eventDate: date,
          counterDeltas: deltas,
          metadata: {
            'durationSeconds': duration,
            'chunks': chunks,
          },
        );
        break;
      case 'reflection_saved':
        final isNewEntry = payload['isNewEntry'] == true;
        if (isNewEntry) {
          await _updateCountersOnly(const {'reflectionEntries': 1});
        }
        break;
      case 'ai_conversation':
        await _updateCountersOnly(const {'aiConversations': 1});
        break;
      case 'weekly_challenge_completed':
        await awardXp(
          (payload['bonusXp'] as num?)?.toInt() ?? 200,
          reason: 'Weekly challenge completed',
          type: 'weekly_challenge_completion',
          applyStreakMultiplier: false,
          eventDate: payload['date'] as String? ?? _formatDate(DateTime.now()),
          counterDeltas: const {'weeklyChallengesCompleted': 1},
        );
        break;
      default:
        break;
    }
  }

  Future<void> _updateCountersOnly(Map<String, int> counterDeltas) async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading || counterDeltas.isEmpty) return;

    await _ensureDefaults();

    final data = provider.data;
    final updatedCounters =
        _applyCounterDeltas(data.gamificationCounters, counterDeltas);
    final updatedAchievements = _evaluateAchievements(updatedCounters, data.level);

    await provider.updateGamificationData(
      gamificationCounters: updatedCounters,
      achievements: updatedAchievements.map((item) => item.toJson()).toList(),
      disciplineScore: calculateDisciplineScore().toJson(),
    );

    notifyListeners();
  }

  Map<String, int> _applyCounterDeltas(
    Map<String, int> current,
    Map<String, int> deltas,
  ) {
    final next = _normalizeCounterMap(current);
    for (final entry in deltas.entries) {
      next[entry.key] = (next[entry.key] ?? 0) + entry.value;
    }
    return next;
  }

  List<Achievement> _evaluateAchievements(
    Map<String, int> counters,
    int level,
  ) {
    final provider = _appDataProvider;
    if (provider == null) return _hydrateAchievements(const []);

    final baseAchievements = _hydrateAchievements(provider.data.achievements);
    final stats = provider.getStatistics(timePeriod: '30d');

    final progressMap = <String, double>{
      'first_blood': (counters['habitCompletions'] ?? 0).toDouble(),
      'task_master': (counters['taskCompletions'] ?? 0).toDouble(),
      'work_horse': (counters['workTimeSeconds'] ?? 0) / 3600.0,
      'reflection_master': (counters['reflectionEntries'] ?? 0).toDouble(),
      'streak_god': stats.longestStreak.toDouble(),
      'consistency_king': _countHighConsistencyWeeks().toDouble(),
      'early_bird': (counters['morningHabitCompletions'] ?? 0).toDouble(),
      'night_owl': (counters['eveningWorkSessions'] ?? 0).toDouble(),
      'ai_apprentice': (counters['aiConversations'] ?? 0).toDouble(),
      'level_10_legend': level.toDouble(),
      'challenge_champion':
          (counters['weeklyChallengesCompleted'] ?? 0).toDouble(),
      'perfect_week': _hasPerfectWeek() ? 1 : 0,
    };

    final now = DateTime.now();

    return baseAchievements.map((achievement) {
      final rawProgress = progressMap[achievement.id] ?? 0;
      final clampedProgress = rawProgress > achievement.target
          ? achievement.target
          : rawProgress;
      final mergedProgress = achievement.isUnlocked
          ? (achievement.progress > clampedProgress
              ? achievement.progress
              : clampedProgress)
          : clampedProgress;
      final shouldUnlock = achievement.isUnlocked ||
          mergedProgress >= achievement.target;

      return achievement.copyWith(
        progress: mergedProgress,
        isUnlocked: shouldUnlock,
        unlockedAt: achievement.unlockedAt ?? (shouldUnlock ? now : null),
      );
    }).toList();
  }

  List<Achievement> _hydrateAchievements(List<Map<String, dynamic>> raw) {
    final defaults = Achievement.defaults();
    final existingById = <String, Achievement>{};

    for (final item in raw) {
      final id = item['id'] as String?;
      if (id == null || id.isEmpty) continue;
      existingById[id] = Achievement.fromJson(item);
    }

    return defaults.map((defaultAchievement) {
      final existing = existingById[defaultAchievement.id];
      if (existing == null) {
        return defaultAchievement;
      }

      return Achievement(
        id: defaultAchievement.id,
        title: defaultAchievement.title,
        description: defaultAchievement.description,
        iconAsset: defaultAchievement.iconAsset,
        isUnlocked: existing.isUnlocked,
        unlockedAt: existing.unlockedAt,
        progress: existing.progress,
        target: defaultAchievement.target,
      );
    }).toList();
  }

  int _countHighConsistencyWeeks() {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return 0;

    final dailyXp = provider.data.dailyXp;
    final today = _dateOnly(DateTime.now());
    int qualifiedWeeks = 0;

    for (int weekIndex = 0; weekIndex < 4; weekIndex++) {
      final weekEnd = today.subtract(Duration(days: weekIndex * 7));
      final weekStart = weekEnd.subtract(const Duration(days: 6));

      int activeDays = 0;
      int totalDays = 0;
      DateTime cursor = weekStart;

      while (!cursor.isAfter(weekEnd)) {
        final dateKey = _formatDate(cursor);
        if (!provider.isHoliday(dateKey)) {
          totalDays++;
          if ((dailyXp[dateKey] ?? 0) >= _dailyTargetXp) {
            activeDays++;
          }
        }
        cursor = cursor.add(const Duration(days: 1));
      }

      if (totalDays > 0 && (activeDays / totalDays) >= 0.9) {
        qualifiedWeeks++;
      }
    }

    return qualifiedWeeks;
  }

  bool _hasPerfectWeek() {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return false;

    final today = _dateOnly(DateTime.now());
    DateTime cursor = today.subtract(const Duration(days: 6));
    int consideredDays = 0;

    while (!cursor.isAfter(today)) {
      final dateKey = _formatDate(cursor);

      if (provider.isHoliday(dateKey)) {
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }

      consideredDays++;

      final activeHabits = provider.getActiveHabitsForDate(dateKey);
      if (activeHabits.isNotEmpty) {
        final allHabitsComplete =
            activeHabits.every((habit) => provider.isHabitCompleted(habit, dateKey));
        if (!allHabitsComplete) {
          return false;
        }
      }

      final dailyTasks = provider.getDailyTasks(dateKey);
      final hasIncompleteTask =
          dailyTasks.any((task) => task['completed'] != true);
      if (hasIncompleteTask) {
        return false;
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    return consideredDays >= 7;
  }

  double _getStreakMultiplier() {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return 1.0;

    final streak = provider.getStatistics(timePeriod: '30d').currentStreak;
    if (streak >= 30) return 2.0;
    if (streak >= 14) return 1.5;
    if (streak >= 7) return 1.2;
    return 1.0;
  }

  List<Map<String, dynamic>> _appendTransaction(
    List<Map<String, dynamic>> existing,
    XpTransaction transaction,
  ) {
    final transactions = [...existing, transaction.toJson()];
    const maxTransactions = 500;
    if (transactions.length > maxTransactions) {
      return transactions.sublist(transactions.length - maxTransactions);
    }
    return transactions;
  }

  Map<String, int> _normalizeCounterMap(Map<String, int> source) {
    final normalized = <String, int>{};
    for (final entry in source.entries) {
      normalized[entry.key] = entry.value;
    }
    return normalized;
  }

  Map<String, int> _normalizeWeekDecayMap(dynamic raw) {
    if (raw is! Map) {
      return {};
    }

    final output = <String, int>{};
    for (final entry in raw.entries) {
      output[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
    }
    return output;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String? _resolveLastActiveDate(Map<String, int> dailyXp) {
    final activeDates = dailyXp.entries
        .where((entry) => entry.value >= _dailyTargetXp)
        .map((entry) => entry.key)
        .toList()
      ..sort();

    if (activeDates.isEmpty) return null;
    return activeDates.last;
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  String _weekKey(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOffset = date.difference(firstDayOfYear).inDays;
    final weekNumber = ((dayOffset + firstDayOfYear.weekday - 1) ~/ 7) + 1;
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  int _dayOfYear(DateTime date) {
    final first = DateTime(date.year, 1, 1);
    return date.difference(first).inDays + 1;
  }

  int _weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOffset = date.difference(firstDayOfYear).inDays;
    return ((dayOffset + firstDayOfYear.weekday - 1) ~/ 7) + 1;
  }

  Map<String, bool> _readClaimMap(String key) {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return {};
    }

    final raw = provider.data.gamificationMeta[key];
    if (raw is! Map) {
      return {};
    }

    final claims = <String, bool>{};
    for (final entry in raw.entries) {
      claims[entry.key.toString()] = entry.value == true;
    }
    return claims;
  }

  Future<void> _updateClaimMap(String key, Map<String, bool> claims) async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return;

    final updatedMeta = Map<String, dynamic>.from(provider.data.gamificationMeta);
    updatedMeta[key] = claims;

    await provider.updateGamificationData(gamificationMeta: updatedMeta);
  }

  double _calculateDailyChallengeProgress(String type, String dateKey) {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return 0;

    switch (type) {
      case 'tasks_completed_today':
        return provider
            .getDailyTasks(dateKey)
            .where((task) => task['completed'] == true)
            .length
            .toDouble();
      case 'habits_completed_today':
        final activeHabits = provider.getActiveHabitsForDate(dateKey);
        return activeHabits
            .where((habit) => provider.isHabitCompleted(habit, dateKey))
            .length
            .toDouble();
      case 'focused_minutes_today':
        return provider.getTotalWorkTimeForDate(dateKey) / 60.0;
      default:
        return 0;
    }
  }

  double _calculateWeeklyChallengeProgress(String type, DateTime today) {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return 0;

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final days = <String>[];
    DateTime cursor = startOfWeek;
    while (!cursor.isAfter(today)) {
      days.add(_formatDate(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }

    switch (type) {
      case 'focused_hours_week':
        int totalSeconds = 0;
        for (final date in days) {
          totalSeconds += provider.getTotalWorkTimeForDate(date);
        }
        return totalSeconds / 3600.0;
      case 'tasks_completed_week':
        int completed = 0;
        for (final date in days) {
          completed += provider
              .getDailyTasks(date)
              .where((task) => task['completed'] == true)
              .length;
        }
        return completed.toDouble();
      case 'active_days_week':
        int activeDays = 0;
        final xpMap = provider.data.dailyXp;
        for (final date in days) {
          if (!provider.isHoliday(date) && (xpMap[date] ?? 0) >= _dailyTargetXp) {
            activeDays++;
          }
        }
        return activeDays.toDouble();
      default:
        return 0;
    }
  }

  String _challengeProgressLabel(String type, double progress, double target) {
    switch (type) {
      case 'focused_minutes_today':
        return '${progress.toStringAsFixed(0)}m / ${target.toStringAsFixed(0)}m';
      case 'focused_hours_week':
        return '${progress.toStringAsFixed(1)}h / ${target.toStringAsFixed(0)}h';
      default:
        return '${progress.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}';
    }
  }

  Map<String, dynamic> _emptyChallengeData(String scope) {
    return {
      'id': '${scope}_unavailable',
      'type': 'unavailable',
      'title': scope == 'daily' ? 'Daily challenge loading' : 'Weekly challenge loading',
      'description': 'Please wait while challenge data is loading.',
      'target': 1.0,
      'rewardXp': 0,
      'progress': 0.0,
      'progressLabel': '0 / 1',
      'isCompleted': false,
      'isClaimed': false,
      'scope': scope,
    };
  }
}
