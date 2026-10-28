import 'package:flutter/material.dart';

import 'card_model.dart';
import 'listing_model.dart';

/// Status pesanan dalam sistem rekber (escrow) HoloDex
enum OrderStatus {
  reserved,
  completed,
  cancelled,
  expired;

  static OrderStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'expired':
        return OrderStatus.expired;
      case 'reserved':
      default:
        return OrderStatus.reserved;
    }
  }

  String toDbString() {
    switch (this) {
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.expired:
        return 'expired';
      case OrderStatus.reserved:
        return 'reserved';
    }
  }
}

/// Model data Pesanan Rekber (Escrow Order) HoloDex
class OrderModel {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String cardId;
  final double amountIdr;
  final OrderStatus status;
  final DateTime reservedAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelReason;

  // Joined information
  final bool isBuyer;
  final String? otherPartyUsername;
  final String? otherPartyPhotoUrl;
  final CardModel? card;
  final ListingModel? listing;

  const OrderModel({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.cardId,
    required this.amountIdr,
    required this.status,
    required this.reservedAt,
    required this.expiresAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    this.isBuyer = true,
    this.otherPartyUsername,
    this.otherPartyPhotoUrl,
    this.card,
    this.listing,
  });

  bool get isReserved => status == OrderStatus.reserved;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isExpiredStatus => status == OrderStatus.expired;

  /// Memeriksa apakah waktu saat ini telah melewati batas expiresAt
  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.isAfter(expiresAt);
  }

  /// Menghitung sisa durasi sebelum pesanan kedaluwarsa
  Duration remainingDuration([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (current.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(current);
  }

  /// Format teks hitung mundur sisa waktu (cth: "2h 14m", "45m 12s", "Kedaluwarsa")
  String remainingTimeFormatted([DateTime? now]) {
    if (status != OrderStatus.reserved) {
      return OrderActions.statusLabel(status);
    }

    final diff = remainingDuration(now);
    if (diff == Duration.zero) {
      return 'Kedaluwarsa';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (hours > 24) {
      final days = diff.inDays;
      final remHours = hours.remainder(24);
      return '${days}h ${remHours}j';
    } else if (hours > 0) {
      return '${hours}j ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}d';
    } else {
      return '${seconds}d';
    }
  }

  OrderModel copyWith({
    String? id,
    String? listingId,
    String? buyerId,
    String? sellerId,
    String? cardId,
    double? amountIdr,
    OrderStatus? status,
    DateTime? reservedAt,
    DateTime? expiresAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancelReason,
    bool? isBuyer,
    String? otherPartyUsername,
    String? otherPartyPhotoUrl,
    CardModel? card,
    ListingModel? listing,
  }) {
    return OrderModel(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      cardId: cardId ?? this.cardId,
      amountIdr: amountIdr ?? this.amountIdr,
      status: status ?? this.status,
      reservedAt: reservedAt ?? this.reservedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelReason: cancelReason ?? this.cancelReason,
      isBuyer: isBuyer ?? this.isBuyer,
      otherPartyUsername: otherPartyUsername ?? this.otherPartyUsername,
      otherPartyPhotoUrl: otherPartyPhotoUrl ?? this.otherPartyPhotoUrl,
      card: card ?? this.card,
      listing: listing ?? this.listing,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    CardModel? cardObj;
    if (json['card'] != null && json['card'] is Map) {
      cardObj = CardModel.fromJson(Map<String, dynamic>.from(json['card'] as Map));
    }

    ListingModel? listingObj;
    if (json['listing'] != null && json['listing'] is Map) {
      final lMap = Map<String, dynamic>.from(json['listing'] as Map);
      listingObj = ListingModel(
        id: lMap['id']?.toString() ?? json['listing_id']?.toString() ?? '',
        cardId: json['card_id']?.toString() ?? '',
        sellerId: json['seller_id']?.toString() ?? '',
        priceIdr: (json['amount_idr'] as num?)?.toDouble() ?? 0,
        condition: lMap['condition'] as String? ?? 'near_mint',
        description: lMap['description'] as String?,
        lat: (lMap['lat'] as num?)?.toDouble(),
        lng: (lMap['lng'] as num?)?.toDouble(),
        status: lMap['status'] as String? ?? 'active',
        card: cardObj,
      );
    }

    return OrderModel(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      cardId: json['card_id'] as String,
      amountIdr: (json['amount_idr'] as num).toDouble(),
      status: OrderStatus.fromString(json['status'] as String?),
      reservedAt: DateTime.parse(json['reserved_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelledBy: json['cancelled_by'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      isBuyer: json['is_buyer'] as bool? ?? true,
      otherPartyUsername: json['other_party_username'] as String?,
      otherPartyPhotoUrl: json['other_party_photo_url'] as String?,
      card: cardObj,
      listing: listingObj,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'card_id': cardId,
        'amount_idr': amountIdr,
        'status': status.toDbString(),
        'reserved_at': reservedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
        if (cancelledBy != null) 'cancelled_by': cancelledBy,
        if (cancelReason != null) 'cancel_reason': cancelReason,
        'is_buyer': isBuyer,
        if (otherPartyUsername != null)
          'other_party_username': otherPartyUsername,
        if (otherPartyPhotoUrl != null)
          'other_party_photo_url': otherPartyPhotoUrl,
        if (card != null) 'card': card!.toJson(),
      };

  factory OrderModel.fromMap(Map<String, dynamic> map) => OrderModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();
}

/// Fungsi-fungsi murni penentu aksi yang tersedia per Peran dan Status
class OrderActions {
  const OrderActions._();

  /// Pembeli berhak konfirmasi serah terima HANYA jika status 'reserved' dan belum expired
  static bool canConfirm({
    required OrderModel order,
    required bool isBuyer,
    DateTime? now,
  }) {
    if (!isBuyer) return false;
    if (order.status != OrderStatus.reserved) return false;
    if (order.isExpired(now)) return false;
    return true;
  }

  /// Pembeli atau penjual berhak membatalkan HANYA jika status 'reserved' dan belum expired
  static bool canCancel({
    required OrderModel order,
    required bool isBuyer,
    DateTime? now,
  }) {
    if (order.status != OrderStatus.reserved) return false;
    if (order.isExpired(now)) return false;
    return true;
  }

  /// Menentukan daftar teks aksi yang tersedia untuk ditampilkan pada UI
  static List<String> availableActions({
    required OrderModel order,
    required bool isBuyer,
    DateTime? now,
  }) {
    final actions = <String>[];
    if (canConfirm(order: order, isBuyer: isBuyer, now: now)) {
      actions.add('Sudah Kuterima');
    }
    if (canCancel(order: order, isBuyer: isBuyer, now: now)) {
      actions.add('Batalkan Pesanan');
    }
    return actions;
  }

  /// Label nama status untuk tampilan UI
  static String statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.reserved:
        return 'Dipesan';
      case OrderStatus.completed:
        return 'Selesai';
      case OrderStatus.cancelled:
        return 'Dibatalkan';
      case OrderStatus.expired:
        return 'Kedaluwarsa';
    }
  }

  /// Warna badge status
  static Color statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.reserved:
        return const Color(0xFFF59E0B); // Amber / Kuning
      case OrderStatus.completed:
        return const Color(0xFF10B981); // Emerald Hijau
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444); // Merah
      case OrderStatus.expired:
        return const Color(0xFF6B7280); // Abu-abu
    }
  }
}

