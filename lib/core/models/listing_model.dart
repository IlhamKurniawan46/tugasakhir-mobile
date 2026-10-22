import 'package:flutter/material.dart';
import 'card_model.dart';

/// Model data listing untuk Marketplace Peer-to-Peer HoloDex.
/// Ditulis manual tanpa code generation sesuai konvensi AGENTS.md.
class ListingModel {
  final String id;
  final String cardId;
  final String sellerId;
  final double priceIdr;
  final String condition; // 'mint', 'near_mint', 'excellent', 'good', 'poor'
  final String? description;
  final double? lat;
  final double? lng;
  final String status; // 'active', 'sold', 'cancelled'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields (dari relasi cards & users)
  final CardModel? card;
  final String? sellerUsername;
  final String? sellerPhotoUrl;

  const ListingModel({
    required this.id,
    required this.cardId,
    required this.sellerId,
    required this.priceIdr,
    this.condition = 'near_mint',
    this.description,
    this.lat,
    this.lng,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.card,
    this.sellerUsername,
    this.sellerPhotoUrl,
  });

  bool get isActive => status == 'active';
  bool get isSold => status == 'sold';
  bool get isCancelled => status == 'cancelled';

  /// Label teks kondisi kartu yang rapi untuk ditampilkan di UI
  String get conditionLabel {
    switch (condition.toLowerCase()) {
      case 'mint':
        return 'Mint (Sempurna)';
      case 'near_mint':
        return 'Near Mint (Mulus)';
      case 'excellent':
        return 'Excellent (Bagus)';
      case 'good':
        return 'Good (Terawat)';
      case 'poor':
        return 'Poor (Ada Minus)';
      default:
        return condition.toUpperCase();
    }
  }

  /// Warna badge berdasarkan kondisi kartu
  Color get conditionBadgeColor {
    switch (condition.toLowerCase()) {
      case 'mint':
        return const Color(0xFF10B981); // Emerald Green
      case 'near_mint':
        return const Color(0xFF06B6D4); // Cyan
      case 'excellent':
        return const Color(0xFF3B82F6); // Blue
      case 'good':
        return const Color(0xFFF59E0B); // Amber
      case 'poor':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280);
    }
  }

  ListingModel copyWith({
    String? id,
    String? cardId,
    String? sellerId,
    double? priceIdr,
    String? condition,
    String? description,
    double? lat,
    double? lng,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    CardModel? card,
    String? sellerUsername,
    String? sellerPhotoUrl,
  }) =>
      ListingModel(
        id: id ?? this.id,
        cardId: cardId ?? this.cardId,
        sellerId: sellerId ?? this.sellerId,
        priceIdr: priceIdr ?? this.priceIdr,
        condition: condition ?? this.condition,
        description: description ?? this.description,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        card: card ?? this.card,
        sellerUsername: sellerUsername ?? this.sellerUsername,
        sellerPhotoUrl: sellerPhotoUrl ?? this.sellerPhotoUrl,
      );

  factory ListingModel.fromJson(Map<String, dynamic> json) => ListingModel(
        id: json['id'] as String,
        cardId: json['card_id'] as String,
        sellerId: json['seller_id'] as String,
        priceIdr: (json['price_idr'] as num?)?.toDouble() ?? 0,
        condition: json['condition'] as String? ?? 'near_mint',
        description: json['description'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'active',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
        card: json['card'] != null
            ? CardModel.fromJson(Map<String, dynamic>.from(json['card'] as Map))
            : null,
        sellerUsername: json['seller_username'] as String?,
        sellerPhotoUrl: json['seller_photo_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'seller_id': sellerId,
        'price_idr': priceIdr,
        'condition': condition,
        'description': description,
        'lat': lat,
        'lng': lng,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        if (card != null) 'card': card!.toJson(),
        if (sellerUsername != null) 'seller_username': sellerUsername,
        if (sellerPhotoUrl != null) 'seller_photo_url': sellerPhotoUrl,
      };

  factory ListingModel.fromMap(Map<String, dynamic> map) =>
      ListingModel.fromJson(map);

  Map<String, dynamic> toMap() => toJson();
}
