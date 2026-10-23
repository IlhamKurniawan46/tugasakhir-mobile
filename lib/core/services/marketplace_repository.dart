import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_db.dart';
import '../database/supabase_client.dart';
import '../models/listing_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

/// Exception khusus untuk kegagalan operasi Marketplace
class MarketplaceFailure implements Exception {
  final String message;
  const MarketplaceFailure(this.message);

  @override
  String toString() => message;
}

/// Repository terpusat untuk Marketplace P2P HoloDex.
/// Mengelola listing aktif, pasang listing baru, transaksi beli atomik, dan riwayat.
class MarketplaceRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Mengambil daftar semua listing aktif di Marketplace.
  static Future<List<ListingModel>> fetchActiveListings({
    String? cardId,
    String? sellerId,
  }) async {
    if (!SupabaseService.isInitialized) {
      return [];
    }

    try {
      final response = await _client.rpc(
        'get_active_listings',
        params: {
          'p_card_id': cardId,
          'p_seller_id': sellerId,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> list = result['data'] as List<dynamic>;
        return list
            .map((item) =>
                ListingModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } else {
        debugPrint(
            '[HoloDex Error] get_active_listings gagal: ${result['error']}');
        return [];
      }
    } catch (e) {
      debugPrint('[HoloDex Error] fetchActiveListings exception: $e');
      return [];
    }
  }

  /// Mengambil detail satu listing berdasarkan ID.
  static Future<ListingModel?> getListingDetail(String listingId) async {
    if (!SupabaseService.isInitialized) return null;

    try {
      final response = await _client.rpc(
        'get_listing_detail',
        params: {'p_listing_id': listingId},
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true && result['data'] != null) {
        return ListingModel.fromJson(
            Map<String, dynamic>.from(result['data'] as Map));
      }
    } catch (e) {
      debugPrint('[HoloDex Error] getListingDetail exception: $e');
    }
    return null;
  }

  /// Membuat listing baru di Marketplace.
  static Future<String> createListing({
    required String cardId,
    required String sellerId,
    required double priceIdr,
    required String condition,
    String? description,
    double? lat,
    double? lng,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const MarketplaceFailure(
          'Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'create_listing',
        params: {
          'p_card_id': cardId,
          'p_seller_id': sellerId,
          'p_price_idr': priceIdr,
          'p_condition': condition,
          'p_description': description,
          'p_lat': lat,
          'p_lng': lng,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true && result['listing_id'] != null) {
        return result['listing_id'] as String;
      } else {
        throw MarketplaceFailure(
            result['error'] as String? ?? 'Gagal membuat listing kartu.');
      }
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] create_listing postgrest: ${e.message}');
      throw MarketplaceFailure(e.message);
    } catch (e) {
      if (e is MarketplaceFailure) rethrow;
      final str = e.toString().toLowerCase();
      if (str.contains('socketexception') ||
          str.contains('failed host lookup') ||
          str.contains('clientexception') ||
          str.contains('network') ||
          str.contains('connection')) {
        debugPrint('[HoloDex Error] create_listing offline / network error: $e');
        throw const MarketplaceFailure(
          'Gagal terhubung ke server Supabase. Periksa koneksi internet (Wi-Fi/Data) di perangkat Anda.',
        );
      }
      debugPrint('[HoloDex Error] create_listing exception: $e');
      throw const MarketplaceFailure('Terjadi kesalahan saat membuat listing.');
    }
  }

  /// Membeli listing secara atomik.
  /// Memotong saldo pembeli, menambah saldo penjual, memindahkan kartu ke koleksi pembeli,
  /// dan mencatat transaksi di backend Supabase.
  static Future<Map<String, dynamic>> buyListing({
    required String listingId,
    required String buyerId,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const MarketplaceFailure(
          'Tidak terhubung ke server database online.');
    }

    try {
      final response = await _client.rpc(
        'buy_listing',
        params: {
          'p_listing_id': listingId,
          'p_buyer_id': buyerId,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true) {
        // Update saldo lokal di SQLite jika ada
        final newBalance =
            (result['new_balance_idr'] as num?)?.toDouble() ?? 0;
        try {
          final db = await LocalDb.instance;
          await db.update(
            'users',
            {'balance_idr': newBalance},
            where: 'id = ?',
            whereArgs: [buyerId],
          );
        } catch (_) {}

        return result;
      } else {
        throw MarketplaceFailure(
            result['error'] as String? ?? 'Gagal membeli listing.');
      }
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] buy_listing postgrest: ${e.message}');
      throw MarketplaceFailure(e.message);
    } catch (e) {
      if (e is MarketplaceFailure) rethrow;
      debugPrint('[HoloDex Error] buy_listing exception: $e');
      throw const MarketplaceFailure('Terjadi kesalahan saat membeli kartu.');
    }
  }

  /// Membatalkan listing aktif milik sendiri.
  static Future<bool> cancelListing({
    required String listingId,
    required String sellerId,
  }) async {
    if (!SupabaseService.isInitialized) return false;

    try {
      final response = await _client.rpc(
        'cancel_listing',
        params: {
          'p_listing_id': listingId,
          'p_seller_id': sellerId,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true) {
        return true;
      } else {
        throw MarketplaceFailure(
            result['error'] as String? ?? 'Gagal membatalkan listing.');
      }
    } catch (e) {
      if (e is MarketplaceFailure) rethrow;
      debugPrint('[HoloDex Error] cancelListing exception: $e');
      throw const MarketplaceFailure(
          'Terjadi kesalahan saat membatalkan listing.');
    }
  }

  /// Mengambil riwayat transaksi pengguna (pembelian & penjualan).
  static Future<List<TransactionModel>> getUserTransactions(
      String userId) async {
    if (!SupabaseService.isInitialized) return [];

    try {
      final response = await _client.rpc(
        'get_user_transactions',
        params: {'p_user_id': userId},
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> list = result['data'] as List<dynamic>;
        return list
            .map((item) => TransactionModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('[HoloDex Error] getUserTransactions exception: $e');
    }
    return [];
  }

  /// Mengambil profil user terbaru dari Supabase (sinkronisasi saldo).
  static Future<UserModel?> getUserProfile(String userId) async {
    if (!SupabaseService.isInitialized) return null;

    try {
      final response = await _client.rpc(
        'get_user_profile',
        params: {'p_user_id': userId},
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true && result['user'] != null) {
        final user = UserModel.fromJson(
            Map<String, dynamic>.from(result['user'] as Map));

        // Update cache SQLite
        final db = await LocalDb.instance;
        await db.update(
          'users',
          {
            'balance_idr': user.balanceIdr,
            'photo_path': user.photoUrl,
            'fingerprint_enabled': user.fingerprintEnabled ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [userId],
        );

        return user;
      }
    } catch (e) {
      debugPrint('[HoloDex Error] getUserProfile exception: $e');
    }
    return null;
  }

  /// Top up saldo virtual untuk keperluan simulasi/demo tugas akhir.
  static Future<double> topUpBalance({
    required String userId,
    required double amount,
  }) async {
    if (!SupabaseService.isInitialized) {
      throw const MarketplaceFailure('Server database tidak terhubung.');
    }

    try {
      final response = await _client.rpc(
        'top_up_balance',
        params: {
          'p_user_id': userId,
          'p_amount': amount,
        },
      );

      final Map<String, dynamic> result =
          Map<String, dynamic>.from(response as Map);

      if (result['success'] == true && result['new_balance_idr'] != null) {
        final newBalance =
            (result['new_balance_idr'] as num?)?.toDouble() ?? 0;

        // Update lokal
        final db = await LocalDb.instance;
        await db.update(
          'users',
          {'balance_idr': newBalance},
          where: 'id = ?',
          whereArgs: [userId],
        );

        return newBalance;
      } else {
        throw MarketplaceFailure(
            result['error'] as String? ?? 'Gagal top up saldo.');
      }
    } catch (e) {
      if (e is MarketplaceFailure) rethrow;
      debugPrint('[HoloDex Error] topUpBalance exception: $e');
      throw const MarketplaceFailure('Terjadi kesalahan saat top up saldo.');
    }
  }
}
