import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../providers/gamification_provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<GamificationProvider>(
        builder: (context, gamificationProvider, child) {
          final achievements = gamificationProvider.achievements;
          final safeAchievements =
              achievements.isEmpty ? Achievement.defaults() : achievements;

          final unlockedCount =
              safeAchievements.where((item) => item.isUnlocked).length;
          final progressRatio = safeAchievements.isEmpty
              ? 0.0
              : unlockedCount / safeAchievements.length;

          return Column(
            children: [
              _buildSummaryCard(
                context,
                unlockedCount: unlockedCount,
                totalCount: safeAchievements.length,
                progressRatio: progressRatio,
                level: gamificationProvider.currentLevel,
                xp: gamificationProvider.currentXp,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900
                        ? 4
                        : width > 620
                            ? 3
                            : 2;

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: safeAchievements.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final achievement = safeAchievements[index];
                        return _buildAchievementCard(achievement);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required int unlockedCount,
    required int totalCount,
    required double progressRatio,
    required int level,
    required int xp,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3949AB),
            Color(0xFF00897B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Text(
                'Badge Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Level $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$unlockedCount of $totalCount unlocked  •  $xp XP total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressRatio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFF176),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked;
    final ratio = achievement.target <= 0
        ? 0.0
        : (achievement.progress / achievement.target).clamp(0.0, 1.0);

    final cardColor = isUnlocked ? Colors.white : const Color(0xFFF5F5F5);
    final borderColor = isUnlocked
        ? const Color(0xFF90CAF9)
        : const Color(0xFFE0E0E0);

    final progressText = achievement.target == achievement.target.roundToDouble()
        ? '${achievement.progress.toInt()}/${achievement.target.toInt()}'
        : '${achievement.progress.toStringAsFixed(1)}/${achievement.target.toStringAsFixed(1)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Icon(
              isUnlocked ? Icons.verified : Icons.lock_outline,
              size: 18,
              color: isUnlocked
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF9E9E9E),
            ),
          ),
          Center(
            child: SvgPicture.asset(
              achievement.iconAsset,
              width: 62,
              height: 62,
              colorFilter: isUnlocked
                  ? null
                  : const ColorFilter.mode(
                      Color(0xFF9E9E9E),
                      BlendMode.srcIn,
                    ),
              placeholderBuilder: (context) => const SizedBox(
                width: 62,
                height: 62,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            achievement.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUnlocked
                  ? const Color(0xFF263238)
                  : const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              achievement.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isUnlocked
                    ? const Color(0xFF546E7A)
                    : const Color(0xFF9E9E9E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: isUnlocked
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUnlocked
                    ? const Color(0xFF42A5F5)
                    : const Color(0xFFBDBDBD),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUnlocked
                  ? const Color(0xFF1E88E5)
                  : const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _unlockLabel(achievement),
            style: TextStyle(
              fontSize: 11,
              color: isUnlocked
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF9E9E9E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _unlockLabel(Achievement achievement) {
    if (!achievement.isUnlocked) {
      return 'Locked';
    }

    if (achievement.unlockedAt == null) {
      return 'Unlocked';
    }

    return 'Unlocked ${DateFormat('MMM d').format(achievement.unlockedAt!)}';
  }
}
