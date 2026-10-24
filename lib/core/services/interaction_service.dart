import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';
import '../models/user_interaction_model.dart';

/// Service tunggal pencatatan perilaku pengguna untuk mesin rekomendasi AI personalisasi.
/// Data disimpan secara privat di SQLite lokal HP (tanpa sinkronisasi ke Supabase).
class InteractionService {
  InteractionService._();
  static final InteractionService instance = InteractionService._();

  // Konstanta jenis interaksi
  static const String eventPurchase = 'purchase';
  static const String eventWatchlistAdd = 'watchlist_add';
  static const String eventSearchMatch = 'search_match';
  static const String eventCardView = 'card_view';
  static const String eventListingView = 'listing_view';
  static const String eventQuiz = 'quiz';

  // Konstanta bobot dasar interaksi
  static const Map<String, double> baseWeights = {
    eventPurchase: 5.0,
    eventWatchlistAdd: 3.0,
    eventSearchMatch: 2.0,
    eventCardView: 1.0,
    eventListingView: 1.0,
    eventQuiz: 3.0,
  };

  // Batas penyimpanan interaksi per user
  static const int maxEventsPerUser = 1000;

  // Jeda deduplikasi pembukaan kartu yang sama (30 detik)
  static const Duration cardViewDedupeDuration = Duration(seconds: 30);

  // In-memory cache untuk deduplikasi card_view: key = '$userId:$cardId'
  final Map<String, DateTime> _lastCardViews = {};

  // Notifier untuk memicu perhitungan ulang rekomendasi saat ada interaksi baru
  final ValueNotifier<int> interactionEpoch = ValueNotifier<int>(0);

  void _notifyChange() {
    interactionEpoch.value++;
  }

  /// Catat pembukaan detail kartu dengan deduplikasi 30 detik
  Future<void> logCardView({
    required String userId,
    required String cardId,
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;

    final dedupeKey = '$userId:$cardId';
    final now = DateTime.now();
    final lastTime = _lastCardViews[dedupeKey];

    if (lastTime != null && now.difference(lastTime) < cardViewDedupeDuration) {
      return; // Lewati jika dibuka kembali dalam jeda 30 detik
    }

    _lastCardViews[dedupeKey] = now;
    await _insertEvent(
      userId: userId,
      eventType: eventCardView,
      cardId: cardId,
    );
  }

  /// Catat pembukaan detail listing pasar
  Future<void> logListingView({
    required String userId,
    required String cardId,
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;

    await _insertEvent(
      userId: userId,
      eventType: eventListingView,
      cardId: cardId,
    );
  }

  /// Catat penambahan kartu ke watchlist
  Future<void> logWatchlistAdd({
    required String userId,
    required String cardId,
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;

    await _insertEvent(
      userId: userId,
      eventType: eventWatchlistAdd,
      cardId: cardId,
    );
  }

  /// Catat pembelian sukses kartu di marketplace
  Future<void> logPurchase({
    required String userId,
    required String cardId,
  }) async {
    if (userId.isEmpty || cardId.isEmpty) return;

    await _insertEvent(
      userId: userId,
      eventType: eventPurchase,
      cardId: cardId,
    );
  }

  /// Catat pencarian teks (abaikan jika kosong atau < 3 karakter)
  Future<void> logSearch({
    required String userId,
    required String query,
    String? matchedCardId,
  }) async {
    final cleanQuery = query.trim();
    if (userId.isEmpty || cleanQuery.length < 3) return;

    await _insertEvent(
      userId: userId,
      eventType: eventSearchMatch,
      cardId: matchedCardId,
      queryText: cleanQuery,
    );
  }

  /// Catat jawaban kuis selera pengguna (Tahap 2)
  Future<void> logQuizAnswer({
    required String userId,
    required String answerKey, // misal: 'type:Darkness' atau 'set:sv03.5'
  }) async {
    if (userId.isEmpty || answerKey.isEmpty) return;

    await _insertEvent(
      userId: userId,
      eventType: eventQuiz,
      queryText: answerKey,
    );
  }

  /// Insert event ke SQLite lokal dan lakukan pemangkasan otomatis
  Future<void> _insertEvent({
    required String userId,
    required String eventType,
    String? cardId,
    String? queryText,
  }) async {
    try {
      final db = await LocalDb.instance;
      final now = DateTime.now().toUtc();

      await db.insert('user_interactions', {
        'user_id': userId,
        'event_type': eventType,
        'card_id': cardId,
        'query_text': queryText,
        'created_at': now.toIso8601String(),
      });

      // Pangkas otomatis jika melebihi batas 1.000 event
      await db.execute('''
        DELETE FROM user_interactions 
        WHERE user_id = ? 
        AND id NOT IN (
          SELECT id FROM user_interactions 
          WHERE user_id = ? 
          ORDER BY id DESC 
          LIMIT $maxEventsPerUser
        )
      ''', [userId, userId]);

      _notifyChange();
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal mencatat interaksi pengguna: $e');
    }
  }

  /// Ambil interaksi pengguna dalam [days] hari terakhir (default 90 hari)
  Future<List<UserInteraction>> getRecentInteractions(
    String userId, {
    int days = 90,
  }) async {
    if (userId.isEmpty) return [];

    try {
      final db = await LocalDb.instance;
      final cutoffDate = DateTime.now().toUtc().subtract(Duration(days: days));

      final rows = await db.query(
        'user_interactions',
        where: 'user_id = ? AND created_at >= ?',
        whereArgs: [userId, cutoffDate.toIso8601String()],
        orderBy: 'created_at DESC',
      );

      return rows.map((r) => UserInteraction.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal membaca riwayat interaksi: $e');
      return [];
    }
  }

  /// Reset / hapus seluruh interaksi untuk pengguna tertentu
  Future<void> clearUserInteractions(String userId) async {
    if (userId.isEmpty) return;

    try {
      final db = await LocalDb.instance;
      await db.delete(
        'user_interactions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      _lastCardViews.removeWhere((key, _) => key.startsWith('$userId:'));
      _notifyChange();
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal mereset interaksi pengguna: $e');
    }
  }

  /// Hitung total interaksi pengguna saat ini
  Future<int> getUserInteractionCount(String userId) async {
    if (userId.isEmpty) return 0;

    try {
      final db = await LocalDb.instance;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_interactions WHERE user_id = ?',
        [userId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
