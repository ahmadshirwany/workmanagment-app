import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_data_provider.dart';
import '../providers/gamification_provider.dart';
import '../services/gemini_service.dart';
import '../services/shareable_wins_service.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late TextEditingController _challengeController;
  late ConfettiController _confettiController;
  final GeminiService _geminiService = GeminiService();
  final ShareableWinsService _shareableWinsService = ShareableWinsService();
  bool _isGeneratingAi = false;
  bool _isClaimingDaily = false;
  bool _isClaimingWeekly = false;
  bool _isGeneratingShare = false;

  @override
  void initState() {
    super.initState();
    _challengeController = TextEditingController();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _challengeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
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
        ],
      ),
      body: Stack(
        children: [
          Consumer2<AppDataProvider, GamificationProvider>(
            builder: (context, provider, gamificationProvider, child) {
              if (_challengeController.text != provider.data.challenge) {
                _challengeController.text = provider.data.challenge;
                _challengeController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _challengeController.text.length),
                );
              }

              final dailyChallenge = gamificationProvider.getDailyChallengeData();
              final weeklyChallenge = gamificationProvider.getWeeklyChallengeData();
                final privilegedModeConfig =
                  gamificationProvider.getPrivilegedModeConfig();
                final privilegedModeStatus =
                  gamificationProvider.getPrivilegedModeStatus();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emoji_events, size: 60, color: Color(0xFFFF9800)),
                    const SizedBox(height: 16),
                    const Text(
                      'Daily and Weekly Rewards',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Finish challenge goals, claim XP, and keep your momentum high.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPrivilegedModeCard(
                      status: privilegedModeStatus,
                      config: privilegedModeConfig,
                    ),
                    const SizedBox(height: 16),
                    _buildChallengeCard(
                      challengeData: dailyChallenge,
                      isClaiming: _isClaimingDaily,
                      onClaim: _claimDailyReward,
                    ),
                    const SizedBox(height: 16),
                    _buildChallengeCard(
                      challengeData: weeklyChallenge,
                      isClaiming: _isClaimingWeekly,
                      onClaim: _claimWeeklyReward,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingAi ? null : _askAiForChallenge,
                        icon: _isGeneratingAi
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isGeneratingAi
                            ? 'Creating personalized challenge...'
                            : 'Ask AI Coach for Personalized Challenge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'My 30-Day Challenge',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define one long-form challenge and stay consistent for 30 days.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _challengeController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText: 'Example: Complete all my habits every day for 30 days',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFF5F5F5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          provider.updateChallenge(_challengeController.text);
                          _showMessage('Challenge saved!', isSuccess: true);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Challenge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  maxBlastForce: 28,
                  minBlastForce: 14,
                  emissionFrequency: 0.06,
                  numberOfParticles: 22,
                  gravity: 0.18,
                  colors: const [
                    Color(0xFF42A5F5),
                    Color(0xFFAB47BC),
                    Color(0xFFFFB300),
                    Color(0xFF26A69A),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard({
    required Map<String, dynamic> challengeData,
    required bool isClaiming,
    required VoidCallback onClaim,
  }) {
    final scope = challengeData['scope'] == 'weekly' ? 'WEEKLY' : 'DAILY';
    final title = challengeData['title'] as String? ?? 'Challenge';
    final description = challengeData['description'] as String? ?? '';
    final progress = (challengeData['progress'] as num?)?.toDouble() ?? 0;
    final target = (challengeData['target'] as num?)?.toDouble() ?? 1;
    final progressLabel = challengeData['progressLabel'] as String? ?? '0 / 1';
    final rewardXp = (challengeData['rewardXp'] as num?)?.toInt() ?? 0;
    final isCompleted = challengeData['isCompleted'] == true;
    final isClaimed = challengeData['isClaimed'] == true;

    final progressRatio =
        target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0).toDouble();

    String buttonLabel;
    VoidCallback? onPressed;

    if (isClaimed) {
      buttonLabel = 'Reward Claimed';
      onPressed = null;
    } else if (isCompleted) {
      buttonLabel = 'Claim Reward';
      onPressed = isClaiming ? null : onClaim;
    } else {
      buttonLabel = 'In Progress';
      onPressed = null;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scope == 'WEEKLY'
                        ? const Color(0xFF0D47A1).withOpacity(0.12)
                        : const Color(0xFF2E7D32).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    scope,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scope == 'WEEKLY'
                          ? const Color(0xFF0D47A1)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
                if (isClaimed)
                  const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progressRatio,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '+$rewardXp XP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF6C00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClaimed
                      ? Colors.grey[400]
                      : const Color(0xFFEF6C00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isClaiming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivilegedModeCard({
    required Map<String, dynamic> status,
    required Map<String, dynamic> config,
  }) {
    final isOn = status['isOn'] == true;
    final isDailyOnTrack = status['isDailyOnTrack'] == true;
    final isRollingSevenOnTrack =
      status['isRollingSevenOnTrack'] == true ||
      status['isWeeklyOnTrack'] == true;
    final dailyCompletedHabits =
      (status['dailyCompletedHabits'] as num?)?.toInt() ??
        (status['dailyCompletedTasks'] as num?)?.toInt() ??
        0;
    final rollingSevenCompletedHabits =
      (status['rollingSevenCompletedHabits'] as num?)?.toInt() ??
        (status['weeklyCompletedTasks'] as num?)?.toInt() ??
        0;
    final dailyRequiredHabitsByNow =
      (status['dailyRequiredHabitsByNow'] as num?)?.toInt() ??
        (status['dailyRequiredByNow'] as num?)?.toInt() ??
        0;
    final rollingSevenRequiredHabits =
      (status['rollingSevenRequiredHabits'] as num?)?.toInt() ??
        (status['weeklyRequiredByNow'] as num?)?.toInt() ??
        0;
    final dailyTargetHabits =
      (status['dailyTargetHabits'] as num?)?.toInt() ??
        (status['dailyTargetTasks'] as num?)?.toInt() ??
        0;
    final rollingSevenTargetHabits =
      (status['rollingSevenTargetHabits'] as num?)?.toInt() ??
        (status['weeklyTargetTasks'] as num?)?.toInt() ??
        0;
    final dayProgressPercent =
        (status['dayProgressPercent'] as num?)?.toDouble() ?? 0;
    final rollingWindowStartDateKey =
      status['rollingWindowStartDateKey'] as String? ??
        status['weekStartDateKey'] as String? ??
        '';
    final todayDateKey = status['todayDateKey'] as String? ?? '';
    final dataReady = status['dataReady'] != false;
    final allowedActivities = (status['allowedActivities'] as List?)
            ?.map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];

    final dailyTrackRatio = dailyRequiredHabitsByNow <= 0
        ? 1.0
      : (dailyCompletedHabits / dailyRequiredHabitsByNow)
        .clamp(0.0, 1.0)
        .toDouble();
    final rollingSevenTrackRatio = rollingSevenRequiredHabits <= 0
        ? 1.0
      : (rollingSevenCompletedHabits / rollingSevenRequiredHabits)
            .clamp(0.0, 1.0)
            .toDouble();
    final rollingWindowLabel =
      rollingWindowStartDateKey.isNotEmpty && todayDateKey.isNotEmpty
        ? '$rollingWindowStartDateKey to $todayDateKey'
        : 'Rolling window: last 7 days';

    final statusColor = isOn ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final statusLabel = !dataReady ? 'SYNCING' : (isOn ? 'ON' : 'OFF');
    final gradientColors = isOn
        ? const [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF26A69A),
          ]
        : const [
            Color(0xFF8E1B1B),
            Color(0xFFC62828),
            Color(0xFFD84315),
          ];
    final cardShadowColor = isOn ? const Color(0xFF1B5E20) : const Color(0xFF8E1B1B);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: cardShadowColor.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Privileged Mode',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Privileged mode is automatic. It turns ON only when both your current-day habit progress and your last 7 days completed habits are on track.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Mode control: Automatic',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _openPrivilegedModeCustomizeDialog(config),
                    icon: const Icon(Icons.tune),
                    label: const Text('Customize'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.92),
                      foregroundColor: statusColor,
                      side: BorderSide(color: Colors.white.withOpacity(0.95)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (!dataReady)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Syncing progress data... status will update shortly.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _buildPrivilegedProgressSection(
                title: 'Today',
                currentValue: dailyCompletedHabits,
                requiredByNow: dailyRequiredHabitsByNow,
                target: dailyTargetHabits,
                isOnTrack: isDailyOnTrack,
                timelineLabel:
                    'Day elapsed: ${dayProgressPercent.toStringAsFixed(0)}%',
                ratio: dailyTrackRatio,
              ),
              const SizedBox(height: 12),
              _buildPrivilegedProgressSection(
                title: 'Last 7 days',
                currentValue: rollingSevenCompletedHabits,
                requiredByNow: rollingSevenRequiredHabits,
                target: rollingSevenTargetHabits,
                isOnTrack: isRollingSevenOnTrack,
                timelineLabel: rollingWindowLabel,
                ratio: rollingSevenTrackRatio,
              ),
              const SizedBox(height: 12),
              const Text(
                'Allowed when ON',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (allowedActivities.isEmpty)
                const Text(
                  'No allowed activities configured.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allowedActivities
                      .map(
                        (activity) => Chip(
                          label: Text(
                            activity,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.9),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivilegedProgressSection({
    required String title,
    required int currentValue,
    required int requiredByNow,
    required int target,
    required bool isOnTrack,
    required String timelineLabel,
    required double ratio,
  }) {
    final progressLabel = isOnTrack ? 'On track' : 'Behind';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$title habit progress',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isOnTrack ? 0.22 : 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.24)),
              ),
              child: Text(
                progressLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFFFF176),
          backgroundColor: Colors.white.withOpacity(0.28),
        ),
        const SizedBox(height: 6),
        Text(
          '$currentValue done now • need $requiredByNow by now • target $target',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          timelineLabel,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Future<void> _openPrivilegedModeCustomizeDialog(
    Map<String, dynamic> currentConfig,
  ) async {
    final dailyTargetController = TextEditingController(
      text: ((currentConfig['dailyTargetTasks'] as num?)?.toInt() ?? 5)
          .toString(),
    );
    final weeklyTargetController = TextEditingController(
      text: ((currentConfig['weeklyTargetTasks'] as num?)?.toInt() ?? 25)
          .toString(),
    );
    final allowedActivitiesController = TextEditingController(
      text: (currentConfig['allowedActivities'] as List?)
              ?.map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .join('\n') ??
          '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Customize Privileged Mode'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dailyTargetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily target habits',
                    hintText: 'e.g. 5',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weeklyTargetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Last 7 days target habits',
                    hintText: 'e.g. 25',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: allowedActivitiesController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Allowed activities',
                    hintText: 'One activity per line',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last 7 days target will be adjusted to at least the daily target.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final dailyTargetTasks =
                    int.tryParse(dailyTargetController.text.trim());
                final weeklyTargetTasks =
                    int.tryParse(weeklyTargetController.text.trim());
                final allowedActivities = allowedActivitiesController.text
                    .split('\n')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList();

                if (dailyTargetTasks == null ||
                    weeklyTargetTasks == null ||
                    dailyTargetTasks <= 0 ||
                    weeklyTargetTasks <= 0) {
                  _showMessage(
                    'Please enter valid positive numbers for daily and last-7-days habit targets.',
                    isSuccess: false,
                  );
                  return;
                }

                if (allowedActivities.isEmpty) {
                  _showMessage(
                    'Please enter at least one allowed activity.',
                    isSuccess: false,
                  );
                  return;
                }

                try {
                  await context
                      .read<GamificationProvider>()
                      .updatePrivilegedModeConfig(
                        dailyTargetTasks: dailyTargetTasks,
                        weeklyTargetTasks: weeklyTargetTasks,
                        allowedActivities: allowedActivities,
                      );
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showMessage(
                    'Privileged mode settings saved.',
                    isSuccess: true,
                  );
                } catch (e) {
                  if (!mounted) return;
                  _showMessage(
                    'Could not save privileged mode settings: $e',
                    isSuccess: false,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    dailyTargetController.dispose();
    weeklyTargetController.dispose();
    allowedActivitiesController.dispose();
  }

  Future<void> _claimDailyReward() async {
    setState(() => _isClaimingDaily = true);
    final (success, message) =
        await context.read<GamificationProvider>().claimDailyChallengeReward();
    if (!mounted) return;
    setState(() => _isClaimingDaily = false);
    if (success) {
      _showXpRewardToast(message);
      _confettiController.play();
      return;
    }
    _showMessage(message, isSuccess: false);
  }

  Future<void> _claimWeeklyReward() async {
    setState(() => _isClaimingWeekly = true);
    final (success, message) =
        await context.read<GamificationProvider>().claimWeeklyChallengeReward();
    if (!mounted) return;
    setState(() => _isClaimingWeekly = false);
    if (success) {
      _showXpRewardToast(message);
      _confettiController.play();
      return;
    }
    _showMessage(message, isSuccess: false);
  }

  Future<void> _askAiForChallenge() async {
    setState(() => _isGeneratingAi = true);
    try {
      final provider = context.read<AppDataProvider>();
      final stats = provider.getStatistics(timePeriod: '30d');

      final suggestion = await _geminiService.generatePersonalizedChallenge(
        habitNames: provider.getAllHabitNames(),
        currentStreak: stats.currentStreak,
        habitCompletionRate: stats.overallCompletionRate,
        weeklyWorkHours: stats.totalWorkTimeSeconds / 3600 / 4,
        taskCompletionRate: stats.dailyTaskCompletionRate,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('AI Challenge Suggestion'),
            content: SingleChildScrollView(child: Text(suggestion.trim())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () {
                  _challengeController.text = suggestion.trim();
                  provider.updateChallenge(_challengeController.text);
                  Navigator.of(context).pop();
                  _showMessage('AI challenge applied and saved!', isSuccess: true);
                },
                child: const Text('Use This'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Could not generate challenge: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAi = false);
      }
    }
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
      _showMessage('Could not generate share card: $e', isSuccess: false);
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

  void _showMessage(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
      ),
    );
  }

  void _showXpRewardToast(String message) {
    final xpMatch = RegExp(r'\+?(\d+)\s*XP', caseSensitive: false)
        .firstMatch(message);
    final xpValue = int.tryParse(xpMatch?.group(1) ?? '') ?? 0;
    final toastMessage = xpValue > 0
        ? 'Reward claimed! +$xpValue XP'
        : 'Reward claimed!';

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  toastMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
