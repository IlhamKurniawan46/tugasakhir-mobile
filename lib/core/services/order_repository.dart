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
      case 'whatsapp_required':
        return 'Nomor WhatsApp wajib diisi terlebih dahulu sebelum melanjutkan transaksi agar dapat berkoordinasi COD.';
      case 'not_allowed':
        return 'Kontak WhatsApp hanya dapat diakses saat status pesanan masih aktif (Dipesan).';
      case 'no_contact':
        return 'Pihak lawan belum mengisi nomor WhatsApp.';
      case 'INVALID_PHONE_NUMBER':
        return 'Format nomor WhatsApp tidak valid. Gunakan format nomor Indonesia (contoh: 081234567890).';
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

  /// Mengambil kontak WhatsApp pihak lawan untuk pesanan aktif (status reserved)
  static Future<OrderContactResult> getOrderContact({
    required String orderId,
    required String userId,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const OrderFailure('Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'get_order_contact',
        params: {
          'p_order_id': orderId,
          'p_user_id': userId,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      return OrderContactResult.fromJson(result);
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] get_order_contact postgrest: ${e.message}');
      throw OrderFailure(e.message);
    } catch (e) {
      if (e is OrderFailure) rethrow;
      debugPrint('[HoloDex Error] getOrderContact exception: $e');
      throw const OrderFailure('Gagal mengambil kontak WhatsApp pihak lawan.');
    }
  }

  /// Menyimpan atau menghapus nomor WhatsApp pengguna milik sendiri
  static Future<String?> setMyWhatsapp({
    required String userId,
    required String? phoneNumber,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const OrderFailure('Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'set_my_whatsapp',
        params: {
          'p_user_id': userId,
          'p_number': phoneNumber,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['ok'] == true) {
        return result['whatsapp_number'] as String?;
      } else {
        final errCode = result['error_code'] as String?;
        final errMsg = mapErrorCodeToMessage(errCode, result['error'] as String?);
        throw OrderFailure(errMsg, errCode);
      }
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] set_my_whatsapp postgrest: ${e.message}');
      throw OrderFailure(e.message);
    } catch (e) {
      if (e is OrderFailure) rethrow;
      debugPrint('[HoloDex Error] setMyWhatsapp exception: $e');
      throw const OrderFailure('Gagal menyimpan nomor WhatsApp.');
    }
  }
}

/// Model hasil pemanggilan kontak pesanan
class OrderContactResult {
  final bool ok;
  final String? orderId;
  final String? role;
  final String? displayName;
  final String? whatsappNumber;
  final String? errorCode;
  final String? message;

  const OrderContactResult({
    required this.ok,
    this.orderId,
    this.role,
    this.displayName,
    this.whatsappNumber,
    this.errorCode,
    this.message,
  });

  factory OrderContactResult.fromJson(Map<String, dynamic> json) =>
      OrderContactResult(
        ok: json['ok'] == true,
        orderId: json['order_id'] as String?,
        role: json['role'] as String?,
        displayName: json['display_name'] as String?,
        whatsappNumber: json['whatsapp_number'] as String?,
        errorCode: json['error_code'] as String?,
        message: json['error'] as String? ?? json['message'] as String?,
      );
}

