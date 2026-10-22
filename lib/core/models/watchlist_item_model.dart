import 'card_model.dart';

/// Model item watchlist kartu (tersimpan di SQLite lokal per user).
class WatchlistItemModel {
  final String cardId;
  final String userId;
  final double? alertPriceIdr;
  final DateTime? addedAt;
  final CardModel? card;

  const WatchlistItemModel({
    required this.cardId,
    required this.userId,
    this.alertPriceIdr,
    this.addedAt,
    this.card,
  });

  factory WatchlistItemModel.fromMap(Map<String, dynamic> map, {CardModel? card}) {
    DateTime? parsedAddedAt;
    if (map['added_at'] != null) {
      if (map['added_at'] is int) {
        parsedAddedAt =
            DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int);
      } else if (map['added_at'] is String) {
        parsedAddedAt = DateTime.tryParse(map['added_at'] as String);
      }
    }

    return WatchlistItemModel(
      cardId: map['card_id'] as String,
      userId: map['user_id'] as String,
      alertPriceIdr: (map['alert_price_idr'] as num?)?.toDouble(),
      addedAt: parsedAddedAt,
      card: card,
    );
  }

  Map<String, dynamic> toMap() => {
        'card_id': cardId,
        'user_id': userId,
        'alert_price_idr': alertPriceIdr,
        'added_at': addedAt?.millisecondsSinceEpoch,
      };

  factory WatchlistItemModel.fromJson(Map<String, dynamic> json, {String? userId}) {
    final cardJson = json['card'] as Map<String, dynamic>?;
    DateTime? parsedAddedAt;
    if (json['added_at'] != null) {
      if (json['added_at'] is int) {
        parsedAddedAt =
            DateTime.fromMillisecondsSinceEpoch(json['added_at'] as int);
      } else if (json['added_at'] is String) {
        parsedAddedAt = DateTime.tryParse(json['added_at'] as String);
      }
    }

    return WatchlistItemModel(
      cardId: (json['card_id'] ?? json['id'] ?? '') as String,
      userId: userId ?? (json['user_id'] as String? ?? ''),
      alertPriceIdr: (json['alert_price_idr'] as num?)?.toDouble(),
      addedAt: parsedAddedAt,
      card: cardJson != null ? CardModel.fromJson(cardJson) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'card_id': cardId,
        'user_id': userId,
        'alert_price_idr': alertPriceIdr,
        'added_at': addedAt?.toIso8601String(),
        if (card != null) 'card': card!.toJson(),
      };

  WatchlistItemModel copyWith({
    String? cardId,
    String? userId,
    double? alertPriceIdr,
    DateTime? addedAt,
    CardModel? card,
  }) =>
      WatchlistItemModel(
        cardId: cardId ?? this.cardId,
        userId: userId ?? this.userId,
        alertPriceIdr: alertPriceIdr ?? this.alertPriceIdr,
        addedAt: addedAt ?? this.addedAt,
        card: card ?? this.card,
      );
}
