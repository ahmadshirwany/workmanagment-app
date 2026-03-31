class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconAsset;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress;
  final double target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.isUnlocked,
    this.unlockedAt,
    required this.progress,
    required this.target,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconAsset: json['icon_asset'] as String? ?? '',
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: DateTime.tryParse(json['unlocked_at'] as String? ?? ''),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      target: (json['target'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon_asset': iconAsset,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'progress': progress,
      'target': target,
    };
  }

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progress,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      iconAsset: iconAsset,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      target: target,
    );
  }

  static List<Achievement> defaults() {
    return const [
      Achievement(
        id: 'first_blood',
        title: 'First Blood',
        description: 'Complete first habit',
        iconAsset: 'assets/badges/first_blood.svg',
        isUnlocked: false,
        progress: 0,
        target: 1,
      ),
      Achievement(
        id: 'task_master',
        title: 'Task Master',
        description: 'Complete 50 tasks',
        iconAsset: 'assets/badges/task_master.svg',
        isUnlocked: false,
        progress: 0,
        target: 50,
      ),
      Achievement(
        id: 'work_horse',
        title: 'Work Horse',
        description: '100 hours of focused work',
        iconAsset: 'assets/badges/work_horse.svg',
        isUnlocked: false,
        progress: 0,
        target: 100,
      ),
      Achievement(
        id: 'reflection_master',
        title: 'Reflection Master',
        description: 'Write 30 journal entries',
        iconAsset: 'assets/badges/reflection_master.svg',
        isUnlocked: false,
        progress: 0,
        target: 30,
      ),
      Achievement(
        id: 'streak_god',
        title: 'Streak God',
        description: 'Reach a 30-day streak',
        iconAsset: 'assets/badges/streak_god.svg',
        isUnlocked: false,
        progress: 0,
        target: 30,
      ),
      Achievement(
        id: 'consistency_king',
        title: 'Consistency King',
        description: '90%+ weekly completion for 4 weeks',
        iconAsset: 'assets/badges/consistency_king.svg',
        isUnlocked: false,
        progress: 0,
        target: 4,
      ),
      Achievement(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Complete 10 morning habits before 8 AM',
        iconAsset: 'assets/badges/early_bird.svg',
        isUnlocked: false,
        progress: 0,
        target: 10,
      ),
      Achievement(
        id: 'night_owl',
        title: 'Night Owl',
        description: 'Complete 10 evening work sessions',
        iconAsset: 'assets/badges/night_owl.svg',
        isUnlocked: false,
        progress: 0,
        target: 10,
      ),
      Achievement(
        id: 'ai_apprentice',
        title: 'AI Apprentice',
        description: 'Start 20 AI coach conversations',
        iconAsset: 'assets/badges/ai_apprentice.svg',
        isUnlocked: false,
        progress: 0,
        target: 20,
      ),
      Achievement(
        id: 'level_10_legend',
        title: 'Level 10 Legend',
        description: 'Reach Level 10',
        iconAsset: 'assets/badges/level_10_legend.svg',
        isUnlocked: false,
        progress: 0,
        target: 10,
      ),
      Achievement(
        id: 'challenge_champion',
        title: 'Challenge Champion',
        description: 'Complete 10 weekly challenges',
        iconAsset: 'assets/badges/challenge_champion.svg',
        isUnlocked: false,
        progress: 0,
        target: 10,
      ),
      Achievement(
        id: 'perfect_week',
        title: 'Perfect Week',
        description: '100% completion for 7 consecutive days',
        iconAsset: 'assets/badges/perfect_week.svg',
        isUnlocked: false,
        progress: 0,
        target: 1,
      ),
    ];
  }
}
