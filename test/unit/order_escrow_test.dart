import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/order_model.dart';
import 'package:holodex/core/services/order_repository.dart';

void main() {
  group('OrderModel & Serialization Unit Tests', () {
    final now = DateTime.parse('2026-10-25T10:00:00Z');
    final expires = now.add(const Duration(hours: 72));

    const sampleCard = CardModel(
      id: 'swsh3-19',
      localId: '19',
      name: 'Charizard V',
      setId: 'swsh3',
      setName: 'Darkness Ablaze',
      rarity: 'Ultra Rare',
      priceIdr: 250000,
      hasPrice: true,
    );

    final sampleOrder = OrderModel(
      id: 'order-101',
      listingId: 'list-501',
      buyerId: 'user-buyer-1',
      sellerId: 'user-seller-2',
      cardId: 'swsh3-19',
      amountIdr: 250000,
      status: OrderStatus.reserved,
      reservedAt: now,
      expiresAt: expires,
      isBuyer: true,
      otherPartyUsername: 'kolektor_bandung',
      card: sampleCard,
    );

    test('OrderModel fromJson and toJson serialization roundtrip', () {
      final json = sampleOrder.toJson();
      final parsed = OrderModel.fromJson(json);

      expect(parsed.id, 'order-101');
      expect(parsed.listingId, 'list-501');
      expect(parsed.buyerId, 'user-buyer-1');
      expect(parsed.sellerId, 'user-seller-2');
      expect(parsed.cardId, 'swsh3-19');
      expect(parsed.amountIdr, 250000);
      expect(parsed.status, OrderStatus.reserved);
      expect(parsed.isReserved, true);
      expect(parsed.isBuyer, true);
      expect(parsed.otherPartyUsername, 'kolektor_bandung');
      expect(parsed.card?.name, 'Charizard V');
    });

    test('Hitung sisa waktu dan format countdown tepat', () {
      // 1. Tepat 2 hari 10 jam tersisa
      final testTime1 = now.add(const Duration(hours: 24 + 14)); // 38 jam berlalu, sisa 34 jam
      final diff = sampleOrder.remainingDuration(testTime1);
      expect(diff.inHours, 34);
      expect(sampleOrder.isExpired(testTime1), false);
      expect(sampleOrder.remainingTimeFormatted(testTime1), '1h 10j');

      // 2. Sisa 45 menit 30 detik
      final testTime2 = expires.subtract(const Duration(minutes: 45, seconds: 30));
      expect(sampleOrder.remainingTimeFormatted(testTime2), '45m 30d');

      // 3. Waktu sudah lewat (kedaluwarsa)
      final testTime3 = expires.add(const Duration(minutes: 1));
      expect(sampleOrder.isExpired(testTime3), true);
      expect(sampleOrder.remainingDuration(testTime3), Duration.zero);
      expect(sampleOrder.remainingTimeFormatted(testTime3), 'Kedaluwarsa');
    });

    test('OrderStatus parsing dari berbagai string', () {
      expect(OrderStatus.fromString('reserved'), OrderStatus.reserved);
      expect(OrderStatus.fromString('completed'), OrderStatus.completed);
      expect(OrderStatus.fromString('cancelled'), OrderStatus.cancelled);
      expect(OrderStatus.fromString('expired'), OrderStatus.expired);
      expect(OrderStatus.fromString('unknown_state'), OrderStatus.reserved);
    });
  });

  group('OrderActions Pure Functions Unit Tests', () {
    final now = DateTime.parse('2026-10-25T10:00:00Z');
    final expires = now.add(const Duration(hours: 72));

    final reservedOrder = OrderModel(
      id: 'ord-1',
      listingId: 'list-1',
      buyerId: 'buyer-1',
      sellerId: 'seller-1',
      cardId: 'card-1',
      amountIdr: 100000,
      status: OrderStatus.reserved,
      reservedAt: now,
      expiresAt: expires,
    );

    test('canConfirm HANYA true untuk pembeli pada order reserved yang belum kedaluwarsa', () {
      // Pembeli saat reserved -> true
      expect(
        OrderActions.canConfirm(order: reservedOrder, isBuyer: true, now: now),
        true,
      );

      // Penjual saat reserved -> false (penjual TIDAK boleh konfirmasi serah terima)
      expect(
        OrderActions.canConfirm(order: reservedOrder, isBuyer: false, now: now),
        false,
      );

      // Pembeli saat waktu sudah lewat -> false
      final expiredTime = expires.add(const Duration(minutes: 5));
      expect(
        OrderActions.canConfirm(order: reservedOrder, isBuyer: true, now: expiredTime),
        false,
      );

      // Pembeli saat order sudah completed / cancelled / expired -> false
      final completedOrder = reservedOrder.copyWith(status: OrderStatus.completed);
      final cancelledOrder = reservedOrder.copyWith(status: OrderStatus.cancelled);
      final expiredOrder = reservedOrder.copyWith(status: OrderStatus.expired);

      expect(OrderActions.canConfirm(order: completedOrder, isBuyer: true), false);
      expect(OrderActions.canConfirm(order: cancelledOrder, isBuyer: true), false);
      expect(OrderActions.canConfirm(order: expiredOrder, isBuyer: true), false);
    });

    test('canCancel berlaku untuk pembeli DAN penjual selama status reserved & belum kedaluwarsa', () {
      // Pembeli -> true
      expect(
        OrderActions.canCancel(order: reservedOrder, isBuyer: true, now: now),
        true,
      );

      // Penjual -> true
      expect(
        OrderActions.canCancel(order: reservedOrder, isBuyer: false, now: now),
        true,
      );

      // Setelah kedaluwarsa -> false
      final expiredTime = expires.add(const Duration(minutes: 5));
      expect(
        OrderActions.canCancel(order: reservedOrder, isBuyer: true, now: expiredTime),
        false,
      );

      // Status completed / cancelled / expired -> false
      expect(
        OrderActions.canCancel(
          order: reservedOrder.copyWith(status: OrderStatus.completed),
          isBuyer: true,
        ),
        false,
      );
      expect(
        OrderActions.canCancel(
          order: reservedOrder.copyWith(status: OrderStatus.cancelled),
          isBuyer: false,
        ),
        false,
      );
    });

    test('availableActions menghasilkan daftar teks aksi tepat per peran dan status', () {
      // Pembeli + Reserved: "Sudah Kuterima" & "Batalkan Pesanan"
      final buyerActions = OrderActions.availableActions(
        order: reservedOrder,
        isBuyer: true,
        now: now,
      );
      expect(buyerActions, ['Sudah Kuterima', 'Batalkan Pesanan']);

      // Penjual + Reserved: HANYA "Batalkan Pesanan"
      final sellerActions = OrderActions.availableActions(
        order: reservedOrder,
        isBuyer: false,
        now: now,
      );
      expect(sellerActions, ['Batalkan Pesanan']);

      // Status Selesai / Dibatalkan: Kosong tanpa aksi
      final completedActions = OrderActions.availableActions(
        order: reservedOrder.copyWith(status: OrderStatus.completed),
        isBuyer: true,
        now: now,
      );
      expect(completedActions, isEmpty);
    });

    test('statusLabel dan statusColor merender representasi yang konsisten', () {
      expect(OrderActions.statusLabel(OrderStatus.reserved), 'Dipesan');
      expect(OrderActions.statusLabel(OrderStatus.completed), 'Selesai');
      expect(OrderActions.statusLabel(OrderStatus.cancelled), 'Dibatalkan');
      expect(OrderActions.statusLabel(OrderStatus.expired), 'Kedaluwarsa');

      expect(OrderActions.statusColor(OrderStatus.reserved), isA<Color>());
      expect(OrderActions.statusColor(OrderStatus.completed), isA<Color>());
      expect(OrderActions.statusColor(OrderStatus.cancelled), isA<Color>());
      expect(OrderActions.statusColor(OrderStatus.expired), isA<Color>());
    });
  });

  group('OrderRepository Error Code Mapping Unit Tests', () {
    test('Memetakan kode galat RPC ke pesan ramah bahasa Indonesia', () {
      expect(
        OrderRepository.mapErrorCodeToMessage('INSUFFICIENT_BALANCE'),
        contains('Saldo virtual Anda tidak mencukupi'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('ALREADY_RESERVED'),
        contains('sedang dipesan oleh kolektor lain'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('CANNOT_BUY_OWN_LISTING'),
        contains('tidak dapat memesan kartu dari listing milik sendiri'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('ORDER_EXPIRED'),
        contains('telah melewati batas 72 jam'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('UNAUTHORIZED'),
        contains('tidak memiliki hak'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('UNKNOWN_CODE', 'Custom fallback'),
        'Custom fallback',
      );
    });
  });
}

