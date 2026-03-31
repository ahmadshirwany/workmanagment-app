class AIChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? type;

  const AIChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.type,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
    };
  }

  AIChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    String? type,
  }) {
    return AIChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }
}
