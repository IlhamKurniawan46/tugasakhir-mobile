import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../database/local_db.dart';

/// Data hasil pembacaan kurs ECB (Frankfurter API)
/// Data hasil pembacaan kurs ECB (Frankfurter API)
class CurrencyRates {
  final double usdToIdr;
  final double usdToEur;
  final double? usdToJpy;
  final String? ecbDate;
  final DateTime? updatedAt;
  final bool isFromCache;

  const CurrencyRates({
    required this.usdToIdr,
    required this.usdToEur,
    this.usdToJpy,
    this.ecbDate,
    this.updatedAt,
    this.isFromCache = false,
  });

  /// Apakah data kurs sudah melebihi batas waktu TTL 24 jam
  bool get isExpired {
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt!) > const Duration(hours: 24);
  }

  /// Apakah kurs JPY tersedia dan valid
  bool get hasJpy => usdToJpy != null && usdToJpy! > 0;

  /// 1 EUR dalam USD = 1 / usdToEur
  double get eurToUsd => usdToEur > 0 ? (1.0 / usdToEur) : 0;

  /// 1 EUR dalam IDR = (1 / usdToEur) * usdToIdr
  double get eurToIdr => usdToEur > 0 ? ((1.0 / usdToEur) * usdToIdr) : 0;

  /// 1 EUR dalam JPY = (1 / usdToEur) * usdToJpy
  double? get eurToJpy =>
      (usdToEur > 0 && hasJpy) ? ((1.0 / usdToEur) * usdToJpy!) : null;

  /// 10.000 IDR dalam USD
  double get idrToUsd => usdToIdr > 0 ? (1.0 / usdToIdr) : 0;

  /// 1 JPY dalam USD
  double? get jpyToUsd => hasJpy ? (1.0 / usdToJpy!) : null;
}

/// Mengelola kurs mata uang real-time (Frankfurter API) dengan cache SQLite 24 jam.
/// Mendukung konversi dinamis 4 mata uang: USD, EUR, IDR, JPY (semua arah).
class CurrencyService {
  static const String _primaryUrl =
      '${AppConstants.frankfurterBaseUrl}/v1/latest?from=USD&to=EUR,IDR,JPY';
  static const String _fallbackUrl =
      '${AppConstants.frankfurterBaseUrl}/latest?from=USD&to=EUR,IDR,JPY';

  // Nilai kurs saat ini dalam memori
  static CurrencyRates? _currentRates;
  static bool _isInitialized = false;

  static CurrencyRates? get currentRates => _currentRates;
  static bool get isInitialized => _isInitialized;
  static bool get hasRates =>
      _currentRates != null &&
      _currentRates!.usdToIdr > 0 &&
      _currentRates!.usdToEur > 0;

  // Backward compatibility getters
  static double get usdToIdrRate => _currentRates?.usdToIdr ?? 17921.0;
  static double get eurToUsdRate => _currentRates?.eurToUsd ?? 1.1195;

  /// Inisialisasi kurs saat aplikasi mulai:
  /// 1. Muat dari SQLite cache terlebih dahulu agar instan (offline-first).
  /// 2. Jika cache kosong, sudah > 24 jam, atau belum memuat JPY, segarkan dari API.
  static Future<void> initRates() async {
    if (_isInitialized) return;

    // 1. Muat cache dari SQLite
    await _loadFromCache();

    // 2. Jika belum ada data, cache kedaluwarsa (> 24 jam), atau JPY belum ada di cache lama
    if (_currentRates == null || _currentRates!.isExpired || _currentRates!.usdToJpy == null) {
      try {
        await refreshRates();
      } catch (e) {
        debugPrint('[HoloDex Warning] Gagal refresh kurs API, tetap pakai cache: $e');
      }
    }

    _isInitialized = true;
  }

  /// Konversi antar 4 mata uang (USD, EUR, IDR, JPY) melalui satu basis konsisten (USD).
  /// Mengembalikan null jika kurs belum pernah dimuat, mata uang tidak dikenal,
  /// atau kurs spesifik (mis. JPY pada cache lama) belum tersedia.
  static double? convert(
    num? amount, {
    required String from,
    required String to,
  }) {
    if (amount == null) return null;
    final cleanFrom = from.trim().toUpperCase();
    final cleanTo = to.trim().toUpperCase();

    if (cleanFrom == cleanTo) return amount.toDouble();
    if (!hasRates) return null;

    final rates = _currentRates!;
    final double value = amount.toDouble();

    // 1. Konversi nilai asal ke basis USD
    double amountInUsd;
    if (cleanFrom == 'USD') {
      amountInUsd = value;
    } else if (cleanFrom == 'IDR') {
      if (rates.usdToIdr <= 0) return null;
      amountInUsd = value / rates.usdToIdr;
    } else if (cleanFrom == 'EUR') {
      if (rates.usdToEur <= 0) return null;
      amountInUsd = value / rates.usdToEur;
    } else if (cleanFrom == 'JPY') {
      if (rates.usdToJpy == null || rates.usdToJpy! <= 0) return null;
      amountInUsd = value / rates.usdToJpy!;
    } else {
      return null;
    }

    // 2. Konversi dari basis USD ke mata uang tujuan
    if (cleanTo == 'USD') {
      return amountInUsd;
    } else if (cleanTo == 'IDR') {
      return amountInUsd * rates.usdToIdr;
    } else if (cleanTo == 'EUR') {
      return amountInUsd * rates.usdToEur;
    } else if (cleanTo == 'JPY') {
      if (rates.usdToJpy == null || rates.usdToJpy! <= 0) return null;
      return amountInUsd * rates.usdToJpy!;
    }

    return null;
  }

  /// Mendapatkan nilai tukar per 1 unit mata uang asal ke mata uang tujuan.
  static double? getRate({required String from, required String to}) {
    return convert(1.0, from: from, to: to);
  }

  /// Konversi harga acuan USD (price_ref_usd) ke Rupiah dinamis.
  static double convertRefUsdToIdr(double priceRefUsd) {
    final converted = convert(priceRefUsd, from: 'USD', to: 'IDR');
    return converted ?? (priceRefUsd * usdToIdrRate);
  }

  /// Memperbarui kurs dari Frankfurter API dan menyimpan ke SQLite cache.
  static Future<bool> refreshRates({bool force = false}) async {
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
          final jpy = (rates['JPY'] as num?)?.toDouble();
          final ecbDate = data['date'] as String?;
          final now = DateTime.now();

          if (idr > 0 && eur > 0) {
            _currentRates = CurrencyRates(
              usdToIdr: idr,
              usdToEur: eur,
              usdToJpy: jpy,
              ecbDate: ecbDate,
              updatedAt: now,
              isFromCache: false,
            );

            // Simpan ke SQLite
            await _saveToCache(
              idr: idr,
              eur: eur,
              jpy: jpy,
              ecbDate: ecbDate,
              now: now,
            );
            return true;
          }
        }
      } catch (e) {
        debugPrint('[HoloDex Warning] Percobaan kurs gagal ke $url: $e');
      }
    }

    // Jika API gagal tapi cache lokal ada, pertahankan cache
    if (_currentRates == null) {
      await _loadFromCache();
    }
    return false;
  }

  static Future<void> _loadFromCache() async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'currency_cache',
        where: 'base = ?',
        whereArgs: ['USD'],
      );

      double? idr;
      double? eur;
      double? jpy;
      String? ecbDate;
      int? updatedTimestamp;

      for (final row in rows) {
        final target = row['target'] as String;
        final rate = (row['rate'] as num).toDouble();
        if (target == 'IDR' && rate > 0) {
          idr = rate;
        } else if (target == 'EUR' && rate > 0) {
          eur = rate;
        } else if (target == 'JPY' && rate > 0) {
          jpy = rate;
        }

        if (row['ecb_date'] != null) {
          ecbDate = row['ecb_date'] as String;
        }
        if (row['updated_at'] != null) {
          updatedTimestamp = row['updated_at'] as int;
        }
      }

      if (idr != null && eur != null) {
        _currentRates = CurrencyRates(
          usdToIdr: idr,
          usdToEur: eur,
          usdToJpy: jpy,
          ecbDate: ecbDate,
          updatedAt: updatedTimestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(updatedTimestamp)
              : null,
          isFromCache: true,
        );
      }
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal membaca cache kurs dari SQLite: $e');
    }
  }

  static Future<void> _saveToCache({
    required double idr,
    required double eur,
    double? jpy,
    String? ecbDate,
    required DateTime now,
  }) async {
    try {
      final db = await LocalDb.instance;
      final nowMs = now.millisecondsSinceEpoch;

      final batch = db.batch();
      batch.insert(
        'currency_cache',
        {
          'base': 'USD',
          'target': 'IDR',
          'rate': idr,
          'ecb_date': ecbDate,
          'updated_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'currency_cache',
        {
          'base': 'USD',
          'target': 'EUR',
          'rate': eur,
          'ecb_date': ecbDate,
          'updated_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (jpy != null && jpy > 0) {
        batch.insert(
          'currency_cache',
          {
            'base': 'USD',
            'target': 'JPY',
            'rate': jpy,
            'ecb_date': ecbDate,
            'updated_at': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal menyimpan cache kurs ke SQLite: $e');
    }
  }

  /// Metode pengujian: inject nilai rates secara eksplisit untuk keperluan unit test
  @visibleForTesting
  static void setMockRates(CurrencyRates? rates) {
    _currentRates = rates;
    _isInitialized = true;
  }
}
