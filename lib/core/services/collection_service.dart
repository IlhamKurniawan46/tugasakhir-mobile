import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';

/// Akses tabel `collection` dan `watchlist` di SQLite lokal.
/// Dipakai CardDetailScreen (Sesi 7) dan CollectionScreen/WatchlistScreen (Sesi 9).
class CollectionService {
  static Future<bool> isInCollection(String userId, String cardId) =>
      _exists('collection', userId, cardId);

  static Future<bool> isInWatchlist(String userId, String cardId) =>
      _exists('watchlist', userId, cardId);

  static Future<void> addToCollection(String userId, String cardId) async {
    final db = await LocalDb.instance;
    await db.insert(
      'collection',
      {
        'user_id': userId,
        'card_id': cardId,
        'acquired_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> removeFromCollection(String userId, String cardId) =>
      _delete('collection', userId, cardId);

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
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> removeFromWatchlist(String userId, String cardId) =>
      _delete('watchlist', userId, cardId);

  static Future<bool> _exists(
    String table,
    String userId,
    String cardId,
  ) async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'user_id = ? AND card_id = ?',
        whereArgs: [userId, cardId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal cek $table: $e');
      return false;
    }
  }

  static Future<void> _delete(
    String table,
    String userId,
    String cardId,
  ) async {
    final db = await LocalDb.instance;
    await db.delete(
      table,
      where: 'user_id = ? AND card_id = ?',
      whereArgs: [userId, cardId],
    );
  }
}
