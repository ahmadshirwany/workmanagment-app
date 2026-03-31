class XpTransaction {
  final String id;
  final int amount;
  final String reason;
  final String type;
  final String date;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const XpTransaction({
    required this.id,
    required this.amount,
    required this.reason,
    required this.type,
    required this.date,
    required this.createdAt,
    this.metadata = const {},
  });

  bool get isPositive => amount >= 0;

  factory XpTransaction.fromJson(Map<String, dynamic> json) {
    return XpTransaction(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      date: json['date'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'reason': reason,
      'type': type,
      'date': date,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
