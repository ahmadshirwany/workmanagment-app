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
    );
  }
}
