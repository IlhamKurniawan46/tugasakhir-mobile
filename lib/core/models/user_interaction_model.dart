/// Model interaksi pengguna untuk mesin rekomendasi personalisasi lokal HoloDex.
/// Disimpan secara privat di SQLite lokal perangkat (tanpa sinkronisasi ke Supabase).
class UserInteraction {
  final int? id;
  final String userId;
  final String eventType;
  final String? cardId;
  final String? queryText;
  final DateTime createdAt;

  const UserInteraction({
    this.id,
    required this.userId,
    required this.eventType,
    this.cardId,
    this.queryText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'event_type': eventType,
        'card_id': cardId,
        'query_text': queryText,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory UserInteraction.fromMap(Map<String, dynamic> map) => UserInteraction(
        id: map['id'] as int?,
        userId: map['user_id'] as String,
        eventType: map['event_type'] as String,
        cardId: map['card_id'] as String?,
        queryText: map['query_text'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      );
}
