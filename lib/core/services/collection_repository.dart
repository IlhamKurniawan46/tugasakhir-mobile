import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';
import '../database/supabase_client.dart';
import '../models/card_model.dart';
import '../models/collection_item_model.dart';
import '../models/watchlist_item_model.dart';
import 'interaction_service.dart';

/// Repository terpusat untuk Koleksi Saya (Koleksi Fisik - Read-Only) dan Watchlist (Lokal).
class CollectionRepository {
  // =========================================================================
  // KOLEKSI SAYA — BACA-SAJA (Sumber kebenaran: Supabase)
  // =========================================================================

  /// Mengambil daftar kartu di Koleksi milik pengguna.
  /// Membaca cache SQLite lokal terlebih dahulu (offline-first), lalu menyinkronkan
  /// dari Supabase jika koneksi tersedia.
  static Future<List<CollectionItemModel>> getCollectionCards(
    String userId, {
    bool forceRefresh = false,
  }) async {
    List<CollectionItemModel> localItems = [];
    try {
      localItems = await _getCollectionFromLocal(userId);
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal baca koleksi dari SQLite: $e');
    }

    // Jika offline atau tidak ada koneksi Supabase, kembalikan data lokal
    if (!SupabaseService.isInitialized) {
      return localItems;
    }

    // Sinkronisasi tarik (pull) dari Supabase
    try {
      final remoteItems = await _fetchCollectionFromSupabase(userId);
      if (remoteItems != null) {
        // Simpan / update cache lokal untuk user ini
        await _saveCollectionToLocal(userId, remoteItems);
        return remoteItems;
      }
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal sinkronisasi koleksi dari Supabase: $e');
    }

    return localItems;
  }

  /// Cek apakah suatu kartu ada di Koleksi user (cek lokal cepat).
  static Future<bool> isCardInCollection(String userId, String cardId) async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'collection',
        columns: ['id'],
        where: 'user_id = ? AND card_id = ?',
        whereArgs: [userId, cardId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal cek koleksi lokal: $e');
      return false;
    }
  }

  /// Baca cache koleksi dari SQLite lokal (dengan JOIN tabel cards).
  static Future<List<CollectionItemModel>> _getCollectionFromLocal(String userId) async {
    final db = await LocalDb.instance;
    final rows = await db.rawQuery('''
      SELECT 
        c.card_id, 
        c.user_id, 
        c.acquired_via, 
        c.acquired_at,
        k.id AS k_id,
        k.local_id AS k_local_id,
        k.name AS k_name,
        k.set_id AS k_set_id,
        k.set_name AS k_set_name,
        k.rarity AS k_rarity,
        k.type AS k_type,
        k.image_url AS k_image_url,
        k.price_idr AS k_price_idr,
        k.price_usd AS k_price_usd,
        k.price_eur AS k_price_eur,
        k.price_ref_usd AS k_price_ref_usd,
        k.price_source AS k_price_source,
        k.has_price AS k_has_price
      FROM collection c
      LEFT JOIN cards k ON k.id = c.card_id
      WHERE c.user_id = ?
      ORDER BY c.acquired_at DESC
    ''', [userId]);

    return rows.map((row) {
      CardModel? card;
      if (row['k_id'] != null) {
        card = CardModel(
          id: row['k_id'] as String,
          localId: row['k_local_id'] as String?,
          name: row['k_name'] as String? ?? 'Kartu Pokémon',
          setId: row['k_set_id'] as String?,
          setName: row['k_set_name'] as String?,
          rarity: row['k_rarity'] as String?,
          cardType: row['k_type'] as String?,
          imageUrl: row['k_image_url'] as String?,
          priceIdr: (row['k_price_idr'] as num?)?.toDouble(),
          priceUsd: (row['k_price_usd'] as num?)?.toDouble(),
          priceEur: (row['k_price_eur'] as num?)?.toDouble(),
          priceRefUsd: (row['k_price_ref_usd'] as num?)?.toDouble(),
          priceSource: row['k_price_source'] as String?,
          hasPrice: (row['k_has_price'] as int?) == 1,
        );
      }

      DateTime? acquiredDate;
      if (row['acquired_at'] != null) {
        acquiredDate = DateTime.fromMillisecondsSinceEpoch(row['acquired_at'] as int);
      }

      return CollectionItemModel(
        cardId: row['card_id'] as String,
        userId: row['user_id'] as String,
        acquiredVia: (row['acquired_via'] as String?) ?? 'purchase',
        acquiredAt: acquiredDate,
        card: card,
      );
    }).toList();
  }

  /// Tarik data koleksi dari Supabase via RPC atau query langsung.
  static Future<List<CollectionItemModel>?> _fetchCollectionFromSupabase(String userId) async {
    final client = SupabaseService.client;

    // Coba via RPC `get_user_collection`
    try {
      final res = await client.rpc('get_user_collection', params: {'p_user_id': userId});
      if (res is Map && res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List).cast<Map<String, dynamic>>();
        return list.map((item) => CollectionItemModel.fromJson(item, userId: userId)).toList();
      }
    } catch (_) {
      // Fallback ke PostgREST select langsung jika RPC belum dibuat
    }

    try {
      final rows = await client
          .from('collections')
          .select('card_id, acquired_via, acquired_at, cards(*)')
          .eq('user_id', userId)
          .order('acquired_at', ascending: false);

      final result = <CollectionItemModel>[];
      for (final r in rows as List) {
        final map = Map<String, dynamic>.from(r as Map);
        final cardData = map['cards'] as Map<String, dynamic>?;
        result.add(CollectionItemModel(
          cardId: map['card_id'] as String,
          userId: userId,
          acquiredVia: (map['acquired_via'] as String?) ?? 'purchase',
          acquiredAt: map['acquired_at'] != null
              ? DateTime.tryParse(map['acquired_at'] as String)
              : null,
          card: cardData != null ? CardModel.fromJson(cardData) : null,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('[HoloDex Error] Fallback select collections gagal: $e');
      return null;
    }
  }

  /// Perbarui cache SQLite untuk koleksi user ini.
  static Future<void> _saveCollectionToLocal(
    String userId,
    List<CollectionItemModel> items,
  ) async {
    final db = await LocalDb.instance;
    await db.transaction((txn) async {
      // Hapus data lama untuk user ini
      await txn.delete('collection', where: 'user_id = ?', whereArgs: [userId]);

      for (final item in items) {
        await txn.insert(
          'collection',
          {
            'user_id': userId,
            'card_id': item.cardId,
            'acquired_via': item.acquiredVia,
            'acquired_at': item.acquiredAt?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Jika ada detail kartu baru dari Supabase yang belum ada di local cards, simpan
        if (item.card != null) {
          final c = item.card!;
          await txn.insert(
            'cards',
            {
              'id': c.id,
              'local_id': c.localId,
              'name': c.name,
              'set_id': c.setId,
              'set_name': c.setName,
              'rarity': c.rarity,
              'type': c.cardType,
              'image_url': c.imageUrl,
              'price_idr': c.priceIdr,
              'price_usd': c.priceUsd,
              'price_eur': c.priceEur,
              'price_ref_usd': c.priceRefUsd,
              'price_source': c.priceSource,
              'has_price': c.hasPrice ? 1 : 0,
              'last_synced': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  // =========================================================================
  // WATCHLIST — TERSIMPAN LOKAL DI SQLITE PER PENGGUNA
  // =========================================================================

  /// Cek apakah kartu ada di watchlist user.
  static Future<bool> isInWatchlist(String userId, String cardId) async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'watchlist',
        columns: ['id'],
        where: 'user_id = ? AND card_id = ?',
        whereArgs: [userId, cardId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal cek watchlist: $e');
      return false;
    }
  }

  /// Tambah satu kartu ke watchlist.
  static Future<void> addToWatchlist(
    String userId,
    String cardId, {
    double? alertPriceIdr,
  }) async {
    final db = await LocalDb.instance;
    await db.insert(
      'watchlist',
      {
        'user_id': userId,
        'card_id': cardId,
        'alert_price_idr': alertPriceIdr,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await InteractionService.instance.logWatchlistAdd(
      userId: userId,
      cardId: cardId,
    );
  }

  /// Tambah banyak kartu ke watchlist sekaligus (multi-select mode Dex).
  /// Mengembalikan jumlah kartu baru yang berhasil ditambahkan (tidak duplikat).
  static Future<int> addMultipleToWatchlist(
    String userId,
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) return 0;
    final db = await LocalDb.instance;

    int newlyAdded = 0;
    final addedCardIds = <String>[];
    await db.transaction((txn) async {
      for (final cardId in cardIds) {
        final existing = await txn.query(
          'watchlist',
          columns: ['id'],
          where: 'user_id = ? AND card_id = ?',
          whereArgs: [userId, cardId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert(
            'watchlist',
            {
              'user_id': userId,
              'card_id': cardId,
              'alert_price_idr': null,
              'added_at': DateTime.now().millisecondsSinceEpoch,
            },
          );
          newlyAdded++;
          addedCardIds.add(cardId);
        }
      }
    });

    for (final cardId in addedCardIds) {
      await InteractionService.instance.logWatchlistAdd(
        userId: userId,
        cardId: cardId,
      );
    }

    return newlyAdded;
  }

  /// Hapus kartu dari watchlist.
  static Future<void> removeFromWatchlist(String userId, String cardId) async {
    final db = await LocalDb.instance;
    await db.delete(
      'watchlist',
      where: 'user_id = ? AND card_id = ?',
      whereArgs: [userId, cardId],
    );
  }

  /// Perbarui harga target kartu di watchlist.
  static Future<void> updateAlertPrice(
    String userId,
    String cardId,
    double? alertPriceIdr,
  ) async {
    final db = await LocalDb.instance;
    await db.update(
      'watchlist',
      {'alert_price_idr': alertPriceIdr},
      where: 'user_id = ? AND card_id = ?',
      whereArgs: [userId, cardId],
    );
  }

  /// Ambil seluruh daftar watchlist untuk user tertentu (dengan detail kartu).
  static Future<List<WatchlistItemModel>> getWatchlist(String userId) async {
    final db = await LocalDb.instance;
    final rows = await db.rawQuery('''
      SELECT 
        w.card_id, 
        w.user_id, 
        w.alert_price_idr, 
        w.added_at,
        k.id AS k_id,
        k.local_id AS k_local_id,
        k.name AS k_name,
        k.set_id AS k_set_id,
        k.set_name AS k_set_name,
        k.rarity AS k_rarity,
        k.type AS k_type,
        k.image_url AS k_image_url,
        k.price_idr AS k_price_idr,
        k.price_usd AS k_price_usd,
        k.price_eur AS k_price_eur,
        k.price_ref_usd AS k_price_ref_usd,
        k.price_source AS k_price_source,
        k.has_price AS k_has_price
      FROM watchlist w
      LEFT JOIN cards k ON k.id = w.card_id
      WHERE w.user_id = ?
      ORDER BY w.added_at DESC
    ''', [userId]);

    return rows.map((row) {
      CardModel? card;
      if (row['k_id'] != null) {
        card = CardModel(
          id: row['k_id'] as String,
          localId: row['k_local_id'] as String?,
          name: row['k_name'] as String? ?? 'Kartu Pokémon',
          setId: row['k_set_id'] as String?,
          setName: row['k_set_name'] as String?,
          rarity: row['k_rarity'] as String?,
          cardType: row['k_type'] as String?,
          imageUrl: row['k_image_url'] as String?,
          priceIdr: (row['k_price_idr'] as num?)?.toDouble(),
          priceUsd: (row['k_price_usd'] as num?)?.toDouble(),
          priceEur: (row['k_price_eur'] as num?)?.toDouble(),
          priceRefUsd: (row['k_price_ref_usd'] as num?)?.toDouble(),
          priceSource: row['k_price_source'] as String?,
          hasPrice: (row['k_has_price'] as int?) == 1,
        );
      }

      DateTime? addedDate;
      if (row['added_at'] != null) {
        addedDate = DateTime.fromMillisecondsSinceEpoch(row['added_at'] as int);
      }

      return WatchlistItemModel(
        cardId: row['card_id'] as String,
        userId: row['user_id'] as String,
        alertPriceIdr: (row['alert_price_idr'] as num?)?.toDouble(),
        addedAt: addedDate,
        card: card,
      );
    }).toList();
  }
}
