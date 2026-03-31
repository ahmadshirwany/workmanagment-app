class AppData {
  List<Map<String, dynamic>> habits; // Changed to store habit objects with dates
  Map<String, Map<String, bool>> habitData;
  Map<String, List<Map<String, dynamic>>> dailyTasks;
  String challenge;
  Map<String, String> reflections;
  String goals;
  String dailyNotes;
  List<Map<String, dynamic>> workSessions; // Work time tracking sessions
  Map<String, dynamic>? activeWorkSession; // Currently running session
  Set<String> holidayDates; // Dates marked as holidays/vacations
  int xp;
  int level;
  List<Map<String, dynamic>> achievements;
  List<Map<String, dynamic>> xpTransactions;
  Map<String, dynamic> disciplineScore;
  Map<String, dynamic> gamificationMeta;
  Map<String, int> gamificationCounters;
  Map<String, int> dailyXp;
  List<Map<String, dynamic>> aiHistory;
  Map<String, dynamic> aiCoachMeta;
  Map<String, dynamic> dailyMotivation;

  AppData({
    required this.habits,
    required this.habitData,
    required this.dailyTasks,
    this.challenge = '',
    required this.reflections,
    this.goals = '',
    this.dailyNotes = '',
    required this.workSessions,
    this.activeWorkSession,
    required this.holidayDates,
    this.xp = 0,
    this.level = 1,
    this.achievements = const [],
    this.xpTransactions = const [],
    this.disciplineScore = const {},
    this.gamificationMeta = const {},
    this.gamificationCounters = const {},
    this.dailyXp = const {},
    this.aiHistory = const [],
    this.aiCoachMeta = const {},
    this.dailyMotivation = const {},
  });

  factory AppData.empty() {
    return AppData(
      habits: [],
      habitData: {},
      dailyTasks: {},
      challenge: '',
      reflections: {},
      goals: '',
      dailyNotes: '',
      workSessions: [],
      activeWorkSession: null,
      holidayDates: {},
      xp: 0,
      level: 1,
      achievements: [],
      xpTransactions: [],
      disciplineScore: {},
      gamificationMeta: {},
      gamificationCounters: {},
      dailyXp: {},
      aiHistory: [],
      aiCoachMeta: {},
      dailyMotivation: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habits': habits,
      'habit_data': habitData,
      'daily_tasks': dailyTasks,
      'challenge': challenge,
      'reflections': reflections,
      'goals': goals,
      'daily_notes': dailyNotes,
      'work_sessions': workSessions,
      'active_work_session': activeWorkSession,
      'holiday_dates': holidayDates.toList(),
      'xp': xp,
      'level': level,
      'achievements': achievements,
      'xp_transactions': xpTransactions,
      'discipline_score': disciplineScore,
      'gamification_meta': gamificationMeta,
      'gamification_counters': gamificationCounters,
      'daily_xp': dailyXp,
      'ai_history': aiHistory,
      'ai_coach_meta': aiCoachMeta,
      'daily_motivation': dailyMotivation,
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    // Handle both old format (List<String>) and new format (List<Map>)
    var habitsJson = json['habits'] ?? [];
    List<Map<String, dynamic>> habits;
    
    if (habitsJson is List && habitsJson.isNotEmpty && habitsJson[0] is String) {
      // Old format: convert strings to habit objects
      habits = habitsJson.map((h) => {
        'name': h as String,
        'startDate': '2020-01-01', // Default start date for old habits
        'endDate': null,
      }).toList().cast<Map<String, dynamic>>();
    } else {
      // New format
      habits = List<Map<String, dynamic>>.from(habitsJson);
    }

    final rawCounters = json['gamification_counters'] as Map<String, dynamic>?;
    final rawDailyXp = json['daily_xp'] as Map<String, dynamic>?;
    
    return AppData(
      habits: habits,
      habitData: (json['habit_data'] as Map<String, dynamic>?)?.map(
            (date, habits) => MapEntry(
              date,
              Map<String, bool>.from(habits as Map),
            ),
          ) ??
          {},
      dailyTasks: (json['daily_tasks'] as Map<String, dynamic>?)?.map(
            (date, tasks) => MapEntry(
              date,
              List<Map<String, dynamic>>.from(tasks as List),
            ),
          ) ??
          {},
      challenge: json['challenge'] ?? '',
      reflections: Map<String, String>.from(json['reflections'] ?? {}),
      goals: json['goals'] ?? '',
      dailyNotes: json['daily_notes'] ?? '',
      workSessions: List<Map<String, dynamic>>.from(json['work_sessions'] ?? []),
      activeWorkSession: json['active_work_session'] as Map<String, dynamic>?,
      holidayDates: Set<String>.from(json['holiday_dates'] ?? []),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      achievements: List<Map<String, dynamic>>.from(json['achievements'] ?? []),
      xpTransactions: List<Map<String, dynamic>>.from(json['xp_transactions'] ?? []),
      disciplineScore: Map<String, dynamic>.from(json['discipline_score'] ?? {}),
      gamificationMeta: Map<String, dynamic>.from(json['gamification_meta'] ?? {}),
      gamificationCounters: rawCounters == null
          ? {}
          : rawCounters.map(
              (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
            ),
      dailyXp: rawDailyXp == null
          ? {}
          : rawDailyXp.map(
              (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
            ),
      aiHistory: List<Map<String, dynamic>>.from(json['ai_history'] ?? []),
      aiCoachMeta: Map<String, dynamic>.from(json['ai_coach_meta'] ?? {}),
      dailyMotivation: Map<String, dynamic>.from(json['daily_motivation'] ?? {}),
    );
  }

  AppData copyWith({
    List<Map<String, dynamic>>? habits,
    Map<String, Map<String, bool>>? habitData,
    Map<String, List<Map<String, dynamic>>>? dailyTasks,
    String? challenge,
    Map<String, String>? reflections,
    String? goals,
    String? dailyNotes,
    List<Map<String, dynamic>>? workSessions,
    Map<String, dynamic>? activeWorkSession,
    bool clearActiveSession = false,
    Set<String>? holidayDates,
    int? xp,
    int? level,
    List<Map<String, dynamic>>? achievements,
    List<Map<String, dynamic>>? xpTransactions,
    Map<String, dynamic>? disciplineScore,
    Map<String, dynamic>? gamificationMeta,
    Map<String, int>? gamificationCounters,
    Map<String, int>? dailyXp,
    List<Map<String, dynamic>>? aiHistory,
    Map<String, dynamic>? aiCoachMeta,
    Map<String, dynamic>? dailyMotivation,
  }) {
    return AppData(
      habits: habits ?? this.habits,
      habitData: habitData ?? this.habitData,
      dailyTasks: dailyTasks ?? this.dailyTasks,
      challenge: challenge ?? this.challenge,
      reflections: reflections ?? this.reflections,
      goals: goals ?? this.goals,
      dailyNotes: dailyNotes ?? this.dailyNotes,
      workSessions: workSessions ?? this.workSessions,
      activeWorkSession: clearActiveSession ? null : (activeWorkSession ?? this.activeWorkSession),
      holidayDates: holidayDates ?? this.holidayDates,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      achievements: achievements ?? this.achievements,
      xpTransactions: xpTransactions ?? this.xpTransactions,
      disciplineScore: disciplineScore ?? this.disciplineScore,
      gamificationMeta: gamificationMeta ?? this.gamificationMeta,
      gamificationCounters: gamificationCounters ?? this.gamificationCounters,
      dailyXp: dailyXp ?? this.dailyXp,
      aiHistory: aiHistory ?? this.aiHistory,
      aiCoachMeta: aiCoachMeta ?? this.aiCoachMeta,
      dailyMotivation: dailyMotivation ?? this.dailyMotivation,
    );
  }
}
