import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_db.dart';
import '../database/supabase_client.dart';
import '../models/order_model.dart';

/// Exception khusus untuk operasi Pesanan / Rekber
class OrderFailure implements Exception {
  final String message;
  final String? errorCode;

  const OrderFailure(this.message, [this.errorCode]);

  @override
  String toString() => message;
}

/// Repository terpusat untuk alur Rekber / Escrow HoloDex.
/// Mengelola pemesanan listing, penahanan saldo, konfirmasi serah terima COD, dan pembatalan.
class OrderRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Memetakan kode kesalahan RPC ke pesan ramah bahasa Indonesia untuk pengguna
  static String mapErrorCodeToMessage(String? errorCode, [String? fallback]) {
    switch (errorCode) {
      case 'INSUFFICIENT_BALANCE':
        return 'Saldo virtual Anda tidak mencukupi untuk memesan kartu ini. Silakan top up terlebih dahulu.';
      case 'ALREADY_RESERVED':
        return 'Kartu ini sedang dipesan oleh kolektor lain.';
      case 'LISTING_NOT_ACTIVE':
        return 'Listing kartu sudah tidak tersedia atau telah terjual.';
      case 'CANNOT_BUY_OWN_LISTING':
        return 'Anda tidak dapat memesan kartu dari listing milik sendiri.';
      case 'ORDER_NOT_FOUND':
        return 'Data pesanan tidak ditemukan di sistem.';
      case 'UNAUTHORIZED':
        return 'Anda tidak memiliki hak untuk melakukan tindakan ini.';
      case 'INVALID_ORDER_STATUS':
        return 'Status pesanan sudah berubah (mungkin telah dibatalkan atau selesai).';
      case 'ORDER_EXPIRED':
        return 'Waktu pesanan ini telah melewati batas 72 jam dan telah kedaluwarsa.';
      case 'BUYER_NOT_FOUND':
        return 'Akun pembeli tidak valid atau tidak ditemukan.';
      case 'LISTING_NOT_FOUND':
        return 'Listing kartu tidak ditemukan.';
      default:
        return fallback ?? 'Terjadi kesalahan pada transaksi. Silakan coba lagi.';
    }
  }

  /// Memesan listing (reserve) dan menahan saldo pembeli
  static Future<Map<String, dynamic>> reserveListing({
    required String listingId,
    required String buyerId,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const OrderFailure('Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'reserve_listing',
        params: {
          'p_listing_id': listingId,
          'p_buyer_id': buyerId,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['ok'] == true) {
        // Perbarui sisa saldo pembeli di SQLite jika ada
        if (result['remaining_balance'] != null) {
          final newBalance =
              (result['remaining_balance'] as num).toDouble();
          try {
            final db = await LocalDb.instance;
            await db.update(
              'users',
              {'balance_idr': newBalance},
              where: 'id = ?',
              whereArgs: [buyerId],
            );
          } catch (_) {}
        }

        return result;
      } else {
        final errCode = result['error_code'] as String?;
        final errMsg = mapErrorCodeToMessage(errCode, result['error'] as String?);
        throw OrderFailure(errMsg, errCode);
      }
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] reserve_listing postgrest: ${e.message}');
      throw OrderFailure(e.message);
    } catch (e) {
      if (e is OrderFailure) rethrow;
      final str = e.toString().toLowerCase();
      if (str.contains('socketexception') ||
          str.contains('failed host lookup') ||
          str.contains('network') ||
          str.contains('connection')) {
        throw const OrderFailure(
          'Gagal terhubung ke server. Periksa koneksi internet perangkat Anda.',
        );
      }
      debugPrint('[HoloDex Error] reserveListing exception: $e');
      throw const OrderFailure('Terjadi kesalahan saat memproses pesanan.');
    }
  }

  /// Konfirmasi serah terima COD oleh pembeli (serahkan saldo ke penjual, kartu masuk Binder)
  static Future<Map<String, dynamic>> confirmReceipt({
    required String orderId,
    required String buyerId,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const OrderFailure('Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'confirm_receipt',
        params: {
          'p_order_id': orderId,
          'p_buyer_id': buyerId,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['ok'] == true) {
        return result;
      } else {
        final errCode = result['error_code'] as String?;
        final errMsg = mapErrorCodeToMessage(errCode, result['error'] as String?);
        throw OrderFailure(errMsg, errCode);
      }
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] confirm_receipt postgrest: ${e.message}');
      throw OrderFailure(e.message);
    } catch (e) {
      if (e is OrderFailure) rethrow;
      final str = e.toString().toLowerCase();
      if (str.contains('socketexception') ||
          str.contains('network') ||
          str.contains('connection')) {
        throw const OrderFailure(
          'Koneksi internet bermasalah. Konfirmasi serah terima membutuhkan internet aktif.',
        );
      }
      debugPrint('[HoloDex Error] confirmReceipt exception: $e');
      throw const OrderFailure('Gagal mengonfirmasi serah terima kartu.');
    }
  }

  /// Membatalkan pesanan oleh pembeli atau penjual (saldo dikembalikan ke pembeli)
  static Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String userId,
    String? reason,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const OrderFailure('Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'cancel_order',
        params: {
          'p_order_id': orderId,
          'p_user_id': userId,
          'p_reason': reason,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['ok'] == true) {
        return result;
      } else {
        final errCode = result['error_code'] as String?;
        final errMsg = mapErrorCodeToMessage(errCode, result['error'] as String?);
        throw OrderFailure(errMsg, errCode);
      }
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] cancel_order postgrest: ${e.message}');
      throw OrderFailure(e.message);
    } catch (e) {
      if (e is OrderFailure) rethrow;
      final str = e.toString().toLowerCase();
      if (str.contains('socketexception') ||
          str.contains('network') ||
          str.contains('connection')) {
        throw const OrderFailure(
          'Koneksi internet bermasalah. Pembatalan pesanan membutuhkan internet aktif.',
        );
      }
      debugPrint('[HoloDex Error] cancelOrder exception: $e');
      throw const OrderFailure('Gagal membatalkan pesanan.');
    }
  }

  /// Mengambil seluruh riwayat pesanan (pembelian & penjualan) milik pengguna
  static Future<List<OrderModel>> getMyOrders(String userId) async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final response = await _client.rpc(
        'get_my_orders',
        params: {'p_user_id': userId},
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['ok'] == true && result['data'] != null) {
        final List<dynamic> list = result['data'] as List<dynamic>;
        return list
            .map((item) =>
                OrderModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else {
        debugPrint('[HoloDex Error] get_my_orders gagal: ${result['error']}');
        return [];
      }
    } catch (e) {
      debugPrint('[HoloDex Error] getMyOrders exception: $e');
      return [];
    }
  }
}

