import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/local_db.dart';
import '../database/supabase_client.dart';
import '../models/card_model.dart';

/// Layanan penanganan Mini Game Pack Opening (Booster Pack Pokémon).
class PackService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _bestPullKey = 'holodex_best_pull_idr';

  /// Mengambil 5 kartu acak untuk membuka 1 booster pack.
  /// Kartu diurutkan dari harga/rarity terendah ke tertinggi sehingga kartu terbaik
  /// terbuka paling akhir untuk efek suspense.
  static Future<List<CardModel>> getRandomPackCards({
    String? setId,
    int count = 5,
  }) async {
    List<CardModel> cards = [];

    // 1. Coba ambil dari SQLite lokal
    try {
      final db = await LocalDb.instance;
      final whereClause = setId != null && setId.isNotEmpty
          ? 'has_price = 1 AND set_id = ?'
          : 'has_price = 1';
      final whereArgs = setId != null && setId.isNotEmpty ? [setId] : null;

      final rows = await db.query(
        'cards',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'RANDOM()',
        limit: count,
      );

      if (rows.isNotEmpty) {
        cards = rows.map((r) => CardModel.fromMap(r)).toList();
      }
    } catch (e) {
      debugPrint('[HoloDex Pack] Gagal query SQLite lokal: $e');
    }

    // 2. Fallback: Ambil dari Supabase jika SQLite kosong
    if (cards.isEmpty) {
      try {
        if (SupabaseService.isInitialized) {
          final client = SupabaseService.client;
          var query = client
              .from('cards')
              .select()
              .eq('has_price', true);

          if (setId != null && setId.isNotEmpty) {
            query = query.eq('set_id', setId);
          }

          final response = await query.limit(50);
          final list = (response as List)
              .map((json) => CardModel.fromJson(json as Map<String, dynamic>))
              .toList();

          if (list.isNotEmpty) {
            list.shuffle(Random());
            cards = list.take(count).toList();
          }
        }
      } catch (e) {
        debugPrint('[HoloDex Pack] Gagal query Supabase fallback: $e');
      }
    }

    // 3. Fallback jika offline & DB belum pernah di-seed sama sekali
    if (cards.isEmpty) {
      cards = _getSampleMockCards(count);
    }

    // Urutkan dari harga terendah ke tertinggi (kartu 'chase' paling belakang)
    cards.sort((a, b) {
      final priceA = a.priceRefUsd ?? a.priceIdr ?? 0.0;
      final priceB = b.priceRefUsd ?? b.priceIdr ?? 0.0;
      return priceA.compareTo(priceB);
    });

    return cards;
  }

  /// Menghitung total nilai tarikan dalam IDR
  static double calculateTotalValueIdr(List<CardModel> cards) {
    double total = 0.0;
    for (final card in cards) {
      total += card.priceIdr ?? 0.0;
    }
    return total;
  }

  /// Membaca rekor pull value terbaik pengguna
  static Future<double> getBestPullValueIdr() async {
    try {
      final valueStr = await _storage.read(key: _bestPullKey);
      if (valueStr != null) {
        return double.tryParse(valueStr) ?? 0.0;
      }
    } catch (e) {
      debugPrint('[HoloDex Pack] Gagal membaca best pull storage: $e');
    }
    return 0.0;
  }

  /// Menyimpan rekor pull value terbaik jika melebihi rekor sebelumnya.
  /// Mengembalikan true jika rekor baru tercapai.
  static Future<bool> checkAndSaveBestPull(double newPullValueIdr) async {
    try {
      final currentBest = await getBestPullValueIdr();
      if (newPullValueIdr > currentBest) {
        await _storage.write(
          key: _bestPullKey,
          value: newPullValueIdr.toString(),
        );
        return true;
      }
    } catch (e) {
      debugPrint('[HoloDex Pack] Gagal simpan best pull: $e');
    }
    return false;
  }

  /// Mock data jika DB benar-benar kosong
  static List<CardModel> _getSampleMockCards(int count) {
    const samples = [
      CardModel(
        id: 'swsh3-1',
        localId: '1',
        name: 'Butterfree V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Ultra Rare',
        priceIdr: 45000,
        priceUsd: 2.8,
        hasPrice: true,
      ),
      CardModel(
        id: 'swsh3-20',
        localId: '20',
        name: 'Charizard VMAX',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Secret Rare',
        priceIdr: 850000,
        priceUsd: 52.0,
        hasPrice: true,
      ),
      CardModel(
        id: 'swsh7-12',
        localId: '12',
        name: 'Jolteon V',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Rare Holo V',
        priceIdr: 95000,
        priceUsd: 6.0,
        hasPrice: true,
      ),
      CardModel(
        id: 'swsh7-215',
        localId: '215',
        name: 'Umbreon VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        priceIdr: 12500000,
        priceUsd: 780.0,
        hasPrice: true,
      ),
      CardModel(
        id: 'sv01-25',
        localId: '25',
        name: 'Pikachu',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Common',
        priceIdr: 15000,
        priceUsd: 0.95,
        hasPrice: true,
      ),
    ];
    return samples.take(count).toList();
  }
}
