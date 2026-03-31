class UserLevel {
  final int level;
  final int minXp;
  final int? maxXp;

  const UserLevel({
    required this.level,
    required this.minXp,
    required this.maxXp,
  });
}

class UserLevelSystem {
  static const List<UserLevel> levels = [
    UserLevel(level: 1, minXp: 0, maxXp: 99),
    UserLevel(level: 2, minXp: 100, maxXp: 299),
    UserLevel(level: 3, minXp: 300, maxXp: 599),
    UserLevel(level: 4, minXp: 600, maxXp: 999),
    UserLevel(level: 5, minXp: 1000, maxXp: 1499),
    UserLevel(level: 6, minXp: 1500, maxXp: 2199),
    UserLevel(level: 7, minXp: 2200, maxXp: 2999),
    UserLevel(level: 8, minXp: 3000, maxXp: 3999),
    UserLevel(level: 9, minXp: 4000, maxXp: 4999),
    UserLevel(level: 10, minXp: 5000, maxXp: null),
  ];

  static int levelForXp(int xp) {
    final safeXp = xp < 0 ? 0 : xp;
    for (final level in levels) {
      final maxXp = level.maxXp;
      if (safeXp >= level.minXp && (maxXp == null || safeXp <= maxXp)) {
        return level.level;
      }
    }
    return 1;
  }

  static int minXpForLevel(int level) {
    final selected = levels.where((item) => item.level == level).toList();
    if (selected.isEmpty) return 0;
    return selected.first.minXp;
  }

  static int? maxXpForLevel(int level) {
    final selected = levels.where((item) => item.level == level).toList();
    if (selected.isEmpty) return null;
    return selected.first.maxXp;
  }

  static double progressToNextLevel(int xp) {
    final currentLevel = levelForXp(xp);
    final minXp = minXpForLevel(currentLevel);
    final maxXp = maxXpForLevel(currentLevel);

    if (maxXp == null) {
      return 1.0;
    }

    final span = maxXp - minXp + 1;
    if (span <= 0) {
      return 0.0;
    }

    final progressed = xp - minXp;
    final value = progressed / span;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static int xpToNextLevel(int xp) {
    final currentLevel = levelForXp(xp);
    final maxXp = maxXpForLevel(currentLevel);
    if (maxXp == null) {
      return 0;
    }
    final remaining = maxXp - xp + 1;
    return remaining < 0 ? 0 : remaining;
  }
}
