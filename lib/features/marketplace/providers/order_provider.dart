import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_db.dart';
import '../../../core/models/card_certificate_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/blockchain_repository.dart';
import '../../../core/services/interaction_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/services/web3_blockchain_service.dart';
import '../../../core/utils/env_loader.dart';
import '../../../core/utils/price_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/collection_provider.dart';
import 'marketplace_provider.dart';

/// State pesanan rekber pengguna
class OrderState {
  final bool isLoading;
  final String? errorMessage;
  final List<OrderModel> orders;

  const OrderState({
    this.isLoading = false,
    this.errorMessage,
    this.orders = const [],
  });

  /// Daftar pesanan di mana pengguna bertindak sebagai pembeli
  List<OrderModel> get buyerOrders =>
      orders.where((o) => o.isBuyer).toList();

  /// Daftar pesanan di mana pengguna bertindak sebagai penjual
  List<OrderModel> get sellerOrders =>
      orders.where((o) => !o.isBuyer).toList();

  /// Total saldo pembeli yang sedang ditahan di sistem rekber
  double get totalReservedAmount {
    double total = 0;
    for (final o in orders) {
      if (o.isBuyer && o.status == OrderStatus.reserved && !o.isExpired()) {
        total += o.amountIdr;
      }
    }
    return total;
  }

  /// Jumlah pesanan yang butuh tindakan pengguna (untuk lencana badge di UI)
  /// - Pembeli: order 'reserved' siap serah terima
  /// - Penjual: order 'reserved' baru yang perlu disiapkan
  int get actionRequiredCount {
    return orders
        .where((o) => o.status == OrderStatus.reserved && !o.isExpired())
        .length;
  }

  OrderState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<OrderModel>? orders,
  }) {
    return OrderState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      orders: orders ?? this.orders,
    );
  }
}

/// Notifier pengelola pesanan rekber, polling berkala, dan notifikasi lokal
class OrderNotifier extends StateNotifier<OrderState> {
  final Ref ref;
  Timer? _pollingTimer;

  OrderNotifier(this.ref) : super(const OrderState());

  /// Memuat daftar pesanan pengguna dari backend Supabase
  Future<void> loadOrders({bool silent = false}) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = state.copyWith(isLoading: false, orders: []);
      return;
    }

    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final orders = await OrderRepository.getMyOrders(user.id);
      state = state.copyWith(isLoading: false, orders: orders, errorMessage: null);

      // Cek perubahan status dan picu notifikasi lokal
      await _checkAndTriggerLocalNotifications(user.id, orders);
    } catch (e) {
      debugPrint('[HoloDex Error] loadOrders exception: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat pesanan. Silakan periksa koneksi internet.',
      );
    }
  }

  /// Memulai polling periodik (setiap 35 detik) saat layar Pasar atau Pesanan Saya aktif
  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 35), (_) {
      loadOrders(silent: true);
    });
  }

  /// Menghentikan polling saat layar ditinggalkan (dispose)
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Membandingkan status pesanan dengan catatan lokal SQLite `order_seen`
  /// dan memicu notifikasi lokal HANYA untuk perubahan baru
  Future<void> _checkAndTriggerLocalNotifications(
    String userId,
    List<OrderModel> currentOrders,
  ) async {
    try {
      final db = await LocalDb.instance;
      final seenRows = await db.query(
        'order_seen',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final Map<String, String> seenStatusMap = {
        for (final row in seenRows)
          row['order_id'] as String: row['last_status'] as String,
      };

      for (final order in currentOrders) {
        final lastStatus = seenStatusMap[order.id];
        final currentStatusStr = order.status.toDbString();

        if (lastStatus == null) {
          // Pesanan baru dideteksi pertama kali
          if (!order.isBuyer && order.status == OrderStatus.reserved) {
            // Notifikasi untuk Penjual: Ada pesanan baru
            _notify(
              id: order.id.hashCode.abs() % 100000,
              title: '📦 Pesanan Baru Masuk!',
              body:
                  'Kolektor @${order.otherPartyUsername ?? 'Pembeli'} memesan kartu ${order.card?.name ?? 'Pokémon'}. Siapkan kartu untuk serah terima COD.',
            );
          }
        } else if (lastStatus != currentStatusStr) {
          // Status pesanan telah berubah sejak terakhir kali dilihat
          if (lastStatus == 'reserved') {
            if (!order.isBuyer && order.status == OrderStatus.completed) {
              // Notifikasi Penjual: Pembeli telah konfirmasi penerimaan
              _notify(
                id: (order.id.hashCode + 1).abs() % 100000,
                title: '💰 Saldo Berhasil Masuk!',
                body:
                    'Pembeli telah mengonfirmasi penerimaan kartu ${order.card?.name ?? 'Pokémon'}. Saldo +${PriceFormatter.formatIdr(order.amountIdr)} telah masuk.',
              );
            } else if (order.isBuyer && order.status == OrderStatus.cancelled) {
              // Notifikasi Pembeli: Pesanan dibatalkan
              _notify(
                id: (order.id.hashCode + 2).abs() % 100000,
                title: '⚠️ Pesanan Dibatalkan',
                body:
                    'Pesanan kartu ${order.card?.name ?? 'Pokémon'} telah dibatalkan. Saldo ${PriceFormatter.formatIdr(order.amountIdr)} telah dikembalikan.',
              );
            } else if (order.isBuyer && order.status == OrderStatus.expired) {
              // Notifikasi Pembeli: Pesanan kedaluwarsa 72 jam
              _notify(
                id: (order.id.hashCode + 3).abs() % 100000,
                title: '⌛ Pesanan Kedaluwarsa',
                body:
                    'Batas waktu 72 jam kartu ${order.card?.name ?? 'Pokémon'} telah terlewati. Saldo ${PriceFormatter.formatIdr(order.amountIdr)} telah dikembalikan.',
              );
            }
          }
        }

        // Perbarui status yang telah dilihat di SQLite
        await db.insert(
          'order_seen',
          {
            'order_id': order.id,
            'user_id': userId,
            'last_status': currentStatusStr,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal cek order_seen: $e');
    }
  }

  void _notify({
    required int id,
    required String title,
    required String body,
  }) {
    NotificationService.instance.showInstantNotification(
      id: id,
      title: title,
      body: body,
      channelId: NotificationService.channelMarketplace,
      payload: jsonEncode({'type': 'orders'}),
    );
  }

  /// Memesan listing & menahan saldo
  Future<Map<String, dynamic>> reserveListing({
    required String listingId,
    required String buyerId,
  }) async {
    final result = await OrderRepository.reserveListing(
      listingId: listingId,
      buyerId: buyerId,
    );

    // Update saldo pengguna
    if (result['remaining_balance'] != null) {
      final newBalance = (result['remaining_balance'] as num).toDouble();
      ref.read(authProvider.notifier).updateUserBalance(newBalance);
    }

    // Refresh listing marketplace agar status langsung 'reserved'
    ref.read(marketplaceProvider.notifier).loadListings(forceRefresh: true);

    // Refresh pesanan
    await loadOrders(silent: true);

    return result;
  }

  /// Konfirmasi serah terima COD oleh pembeli
  Future<Map<String, dynamic>> confirmReceipt({
    required String orderId,
    required String buyerId,
    String? cardName,
    String? cardId,
    double? amountIdr,
  }) async {
    final result = await OrderRepository.confirmReceipt(
      orderId: orderId,
      buyerId: buyerId,
    );

    // 1. Refresh koleksi pengguna (kartu resmi masuk Binder pembeli)
    ref.read(collectionProvider.notifier).refresh();

    // 2. Refresh profil untuk update saldo terbaru
    ref.read(authProvider.notifier).refreshProfile();

    // 3. Catat perilaku interaksi untuk rekomendasi AI personal (bobot 5.0)
    final resolvedCardId = cardId ?? result['card_id'] as String?;
    if (resolvedCardId != null && resolvedCardId.isNotEmpty) {
      await InteractionService.instance.logPurchase(
        userId: buyerId,
        cardId: resolvedCardId,
      );
    }

    // 4. Proses Sertifikat Keaslian On-Chain di Polygon Amoy
    final user = ref.read(authProvider).user;
    final price = amountIdr ?? (result['amount_idr'] as num?)?.toDouble() ?? 0;
    final txId = result['transaction_id']?.toString() ?? '';
    final tokenId =
        DateTime.now().millisecondsSinceEpoch.remainder(1000000).toString();

    String? onChainTxHash;
    if (resolvedCardId != null && resolvedCardId.isNotEmpty) {
      try {
        onChainTxHash = await Web3BlockchainService.instance.mintCertificate(
          cardId: resolvedCardId,
          cardName: cardName ?? 'Pokémon Card',
        );
      } catch (e) {
        debugPrint('[HoloDex Web3] Minting on-chain dilewati/tertunda: $e');
      }

      if (onChainTxHash != null && onChainTxHash.isNotEmpty) {
        final cert = CardCertificateModel(
          id: txId.isNotEmpty
              ? txId
              : 'cert-${DateTime.now().millisecondsSinceEpoch}',
          cardId: resolvedCardId,
          tokenId: tokenId,
          contractAddress: EnvLoader.blockchainContractAddress.isNotEmpty
              ? EnvLoader.blockchainContractAddress
              : '0xAmoyHoloDexProvenance',
          txHash: onChainTxHash,
          fromAddress: '0x0000000000000000000000000000000000000000',
          toAddress: Web3BlockchainService.instance.operatorAddress != null
              ? '0x${Web3BlockchainService.instance.operatorAddress}'
              : '0x${buyerId.replaceAll('-', '').padRight(40, '0').substring(0, 40)}',
          ownerUsername: user?.username ?? 'Buyer',
          action: 'transferred',
          priceIdr: price,
          notes: 'Marketplace Escrow Order #$orderId',
          createdAt: DateTime.now(),
        );

        await BlockchainRepository.saveCertificateRecord(cert);
      }
    }

    // Refresh pesanan & marketplace
    await loadOrders(silent: true);
    ref.read(marketplaceProvider.notifier).loadListings(forceRefresh: true);

    return {
      ...result,
      'tx_hash': onChainTxHash,
      'token_id': tokenId,
    };
  }

  /// Membatalkan pesanan oleh pembeli atau penjual
  Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String userId,
    String? reason,
  }) async {
    final result = await OrderRepository.cancelOrder(
      orderId: orderId,
      userId: userId,
      reason: reason,
    );

    // Refresh profil (saldo pembeli dikembalikan)
    ref.read(authProvider.notifier).refreshProfile();

    // Refresh pesanan & marketplace listing (kembali active)
    await loadOrders(silent: true);
    ref.read(marketplaceProvider.notifier).loadListings(forceRefresh: true);

    return result;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

/// Provider Riverpod tunggal untuk pesanan pengguna
final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(ref);
});

