import 'card_model.dart';

/// Model item kartu di Koleksi Saya (koleksi fisik pengguna yang diperoleh dari pembelian).
class CollectionItemModel {
  final String cardId;
  final String userId;
  final String acquiredVia;
  final DateTime? acquiredAt;
  final CardModel? card;

  const CollectionItemModel({
    required this.cardId,
    required this.userId,
    this.acquiredVia = 'purchase',
    this.acquiredAt,
    this.card,
  });

  factory CollectionItemModel.fromJson(Map<String, dynamic> json, {String? userId}) {
    final cardJson = json['card'] as Map<String, dynamic>?;
    DateTime? parsedAcquiredAt;
    if (json['acquired_at'] != null) {
      if (json['acquired_at'] is int) {
        parsedAcquiredAt =
            DateTime.fromMillisecondsSinceEpoch(json['acquired_at'] as int);
      } else if (json['acquired_at'] is String) {
        parsedAcquiredAt = DateTime.tryParse(json['acquired_at'] as String);
      }
    }

    return CollectionItemModel(
      cardId: (json['card_id'] ?? json['id'] ?? '') as String,
      userId: userId ?? (json['user_id'] as String? ?? ''),
      acquiredVia: (json['acquired_via'] as String?) ?? 'purchase',
      acquiredAt: parsedAcquiredAt,
      card: cardJson != null ? CardModel.fromJson(cardJson) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'card_id': cardId,
        'user_id': userId,
        'acquired_via': acquiredVia,
        'acquired_at': acquiredAt?.toIso8601String(),
        if (card != null) 'card': card!.toJson(),
      };

  factory CollectionItemModel.fromMap(Map<String, dynamic> map, {CardModel? card}) {
    DateTime? parsedAcquiredAt;
    if (map['acquired_at'] != null) {
      if (map['acquired_at'] is int) {
        parsedAcquiredAt =
            DateTime.fromMillisecondsSinceEpoch(map['acquired_at'] as int);
      } else if (map['acquired_at'] is String) {
        parsedAcquiredAt = DateTime.tryParse(map['acquired_at'] as String);
      }
    }

    return CollectionItemModel(
      cardId: map['card_id'] as String,
      userId: map['user_id'] as String,
      acquiredVia: (map['acquired_via'] as String?) ?? 'purchase',
      acquiredAt: parsedAcquiredAt,
      card: card,
    );
  }

  Map<String, dynamic> toMap() => {
        'card_id': cardId,
        'user_id': userId,
        'acquired_via': acquiredVia,
        'acquired_at': acquiredAt?.millisecondsSinceEpoch,
      };

  CollectionItemModel copyWith({
    String? cardId,
    String? userId,
    String? acquiredVia,
    DateTime? acquiredAt,
    CardModel? card,
  }) =>
      CollectionItemModel(
        cardId: cardId ?? this.cardId,
        userId: userId ?? this.userId,
        acquiredVia: acquiredVia ?? this.acquiredVia,
        acquiredAt: acquiredAt ?? this.acquiredAt,
        card: card ?? this.card,
      );
}
