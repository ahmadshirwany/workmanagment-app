class DisciplineScore {
  final double value;
  final double streakComponent;
  final double completionComponent;
  final double workTimeComponent;
  final DateTime updatedAt;

  const DisciplineScore({
    required this.value,
    required this.streakComponent,
    required this.completionComponent,
    required this.workTimeComponent,
    required this.updatedAt,
  });

  factory DisciplineScore.empty() {
    return DisciplineScore(
      value: 0,
      streakComponent: 0,
      completionComponent: 0,
      workTimeComponent: 0,
      updatedAt: DateTime.now(),
    );
  }

  factory DisciplineScore.fromJson(Map<String, dynamic> json) {
    return DisciplineScore(
      value: (json['value'] as num?)?.toDouble() ?? 0,
      streakComponent: (json['streak_component'] as num?)?.toDouble() ?? 0,
      completionComponent: (json['completion_component'] as num?)?.toDouble() ?? 0,
      workTimeComponent: (json['work_time_component'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'streak_component': streakComponent,
      'completion_component': completionComponent,
      'work_time_component': workTimeComponent,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
