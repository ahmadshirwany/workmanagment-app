import 'ai_chat_message.dart';

class AIConversation {
  final String id;
  final String title;
  final List<AIChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AIConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  String get preview {
    if (messages.isEmpty) return 'No messages yet';
    final text = messages.last.content.trim();
    if (text.length <= 90) return text;
    return '${text.substring(0, 90)}...';
  }

  factory AIConversation.fromJson(Map<String, dynamic> json) {
    return AIConversation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Conversation',
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AIChatMessage.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AIConversation copyWith({
    String? id,
    String? title,
    List<AIChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AIConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
