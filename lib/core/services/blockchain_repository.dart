import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_db.dart';
import '../database/supabase_client.dart';
import '../models/card_certificate_model.dart';

/// Repository untuk mengelola data sertifikat keaslian & provenance kartu.
/// Menyediakan sinkronisasi Supabase online dan SQLite lokal offline.
class BlockchainRepository {
  static SupabaseClient get _client => SupabaseService.client;

  /// Mengambil daftar riwayat kepemilikan kartu (provenance) berdasarkan ID kartu
  static Future<List<CardCertificateModel>> getCardProvenance(String cardId) async {
    // 1. Coba ambil dari Supabase
    if (SupabaseService.isInitialized) {
      try {
        final response = await _client.rpc(
          'get_card_provenance',
          params: {'p_card_id': cardId},
        );

        final Map<String, dynamic> result =
            Map<String, dynamic>.from(response as Map);

        if (result['success'] == true && result['data'] != null) {
          final List rawList = result['data'] as List;
          final items = rawList
              .map((item) => CardCertificateModel.fromJson(
                  Map<String, dynamic>.from(item as Map)))
              .toList();

          // Simpan / update ke cache SQLite lokal
          _cacheCertificatesLocally(items);

          return items;
        }
      } catch (e) {
        debugPrint('[HoloDex Error] getCardProvenance Supabase: $e');
      }
    }

    // 2. Fallback: Ambil dari cache SQLite lokal
    return await getLocalCardProvenance(cardId);
  }

  /// Ambil sertifikat kartu dari SQLite lokal
  static Future<List<CardCertificateModel>> getLocalCardProvenance(String cardId) async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'card_certificates',
        where: 'card_id = ?',
        whereArgs: [cardId],
        orderBy: 'created_at ASC',
      );

      return rows.map((r) => CardCertificateModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[HoloDex Error] getLocalCardProvenance: $e');
      return [];
    }
  }

  /// Simpan rekaman sertifikat/transfer ke Supabase dan SQLite lokal
  static Future<void> saveCertificateRecord(CardCertificateModel cert) async {
    // 1. Simpan ke SQLite lokal
    try {
      final db = await LocalDb.instance;
      await db.insert(
        'card_certificates',
        cert.toMap(),
      );
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal simpan sertifikat ke SQLite: $e');
    }

    // 2. Simpan ke Supabase jika terhubung
    if (SupabaseService.isInitialized) {
      try {
        await _client.from('card_certificates').insert(cert.toJson());
      } catch (e) {
        debugPrint('[HoloDex Error] Gagal simpan sertifikat ke Supabase: $e');
      }
    }
  }

  /// Memperbarui catatan transaksi dan koleksi dengan bukti on-chain (tx_hash, token_id)
  static Future<void> updateTransactionAndCollection({
    required String transactionId,
    required String userId,
    required String cardId,
    required String txHash,
    required String tokenId,
    required String contractAddress,
  }) async {
    // 1. Update ke SQLite lokal
    try {
      final db = await LocalDb.instance;
      if (transactionId.isNotEmpty) {
        await db.update(
          'transactions',
          {
            'tx_hash': txHash,
            'token_id': tokenId,
            'contract_address': contractAddress,
            'blockchain_status': 'confirmed',
          },
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      }
      if (userId.isNotEmpty && cardId.isNotEmpty) {
        await db.update(
          'collections',
          {
            'tx_hash': txHash,
            'token_id': tokenId,
            'contract_address': contractAddress,
          },
          where: 'user_id = ? AND card_id = ?',
          whereArgs: [userId, cardId],
        );
      }
    } catch (e) {
      debugPrint('[HoloDex Error] updateTransactionAndCollection SQLite: $e');
    }

    // 2. Update ke Supabase online jika terhubung
    if (SupabaseService.isInitialized) {
      try {
        if (transactionId.isNotEmpty) {
          await _client.from('transactions').update({
            'tx_hash': txHash,
            'token_id': tokenId,
            'contract_address': contractAddress,
            'blockchain_status': 'confirmed',
          }).eq('id', transactionId);
        }
        if (userId.isNotEmpty && cardId.isNotEmpty) {
          await _client.from('collections').update({
            'tx_hash': txHash,
            'token_id': tokenId,
            'contract_address': contractAddress,
          }).match({'user_id': userId, 'card_id': cardId});
        }
      } catch (e) {
        debugPrint('[HoloDex Error] updateTransactionAndCollection Supabase: $e');
      }
    }
  }

  /// Cache kumpulan sertifikat ke SQLite lokal
  static Future<void> _cacheCertificatesLocally(List<CardCertificateModel> items) async {
    if (items.isEmpty) return;
    try {
      final db = await LocalDb.instance;
      final batch = db.batch();
      for (final item in items) {
        batch.insert(
          'card_certificates',
          item.toMap(),
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }
}
