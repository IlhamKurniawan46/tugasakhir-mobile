import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';

/// Mengelola kurs mata uang real-time (Frankfurter API) dengan cache SQLite 24 jam.
class CurrencyService {
  static const String _primaryUrl =
      'https://api.frankfurter.dev/v1/latest?from=USD&to=EUR,IDR';
  static const String _fallbackUrl =
      'https://api.frankfurter.dev/latest?from=USD&to=EUR,IDR';

  // Nilai fallback default jika offline & cache kosong (berdasarkan seed Sesi 4)
  static double _usdToIdrRate = 17921.0;
  static double _eurToUsdRate = 1.1195;
  static bool _isLoaded = false;

  static double get usdToIdrRate => _usdToIdrRate;
  static double get eurToUsdRate => _eurToUsdRate;

  /// Inisialisasi kurs: coba ambil dari internet jika cache kedaluwarsa (> 24 jam),
  /// atau fallback ke SQLite cache.
  static Future<void> initRates() async {
    if (_isLoaded) return;

    // 1. Coba baca dari SQLite dulu
    await _loadFromCache();

    // 2. Refresh dari API di background jika perlu
    _refreshFromApi().then((_) {
      _isLoaded = true;
    }).catchError((e) {
      debugPrint('[HoloDex Warning] Kurs offline, menggunakan data cache: $e');
    });
  }

  /// Konversi harga acuan USD (price_ref_usd) ke Rupiah dinamis.
  static double convertRefUsdToIdr(double priceRefUsd) {
    return priceRefUsd * _usdToIdrRate;
  }

  static Future<void> _loadFromCache() async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'currency_cache',
        where: 'base = ?',
        whereArgs: ['USD'],
      );

      for (final row in rows) {
        final target = row['target'] as String;
        final rate = (row['rate'] as num).toDouble();
        if (target == 'IDR' && rate > 0) {
          _usdToIdrRate = rate;
        } else if (target == 'EUR' && rate > 0) {
          _eurToUsdRate = 1.0 / rate;
        }
      }
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal membaca cache kurs dari SQLite: $e');
    }
  }

  static Future<void> _refreshFromApi() async {
    final urls = [_primaryUrl, _fallbackUrl];

    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rates = data['rates'] as Map<String, dynamic>;
          final idr = (rates['IDR'] as num).toDouble();
          final eur = (rates['EUR'] as num).toDouble();

          if (idr > 0) _usdToIdrRate = idr;
          if (eur > 0) _eurToUsdRate = 1.0 / eur;

          // Simpan ke SQLite
          await _saveToCache(idr: idr, eur: eur);
          return;
        }
      } catch (_) {
        // Coba url fallback berikutnya
      }
    }
  }

  static Future<void> _saveToCache({
    required double idr,
    required double eur,
  }) async {
    try {
      final db = await LocalDb.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      final batch = db.batch();
      batch.insert(
        'currency_cache',
        {'base': 'USD', 'target': 'IDR', 'rate': idr, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'currency_cache',
        {'base': 'USD', 'target': 'EUR', 'rate': eur, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal menyimpan cache kurs ke SQLite: $e');
    }
  }
}
