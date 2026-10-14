// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Target set Pokémon TCG default untuk HoloDex
const List<String> kDefaultTargetSets = ['swsh3', 'swsh7', 'sv01', 'sv05'];

class SeedStats {
  int totalProcessed = 0;
  int succeeded = 0;
  int withPrice = 0;
  int withoutPrice = 0;
  int sourceTcgPlayer = 0;
  int sourceCardMarket = 0;
  List<String> failedCardIds = [];
  DateTime startTime = DateTime.now();
  String? exchangeRateDate;
  double? usdToIdr;
  double? eurToUsd;
}

void main(List<String> args) async {
  print('====================================================');
  print('     HoloDex — Catalog Seeding Pipeline (Sesi 4)    ');
  print('====================================================\n');

  // 1. Parsing argumen baris perintah
  String? targetSetArg;
  int? limitArg;
  bool dryRun = false;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg == '--set' && i + 1 < args.length) {
      targetSetArg = args[++i];
    } else if (arg == '--limit' && i + 1 < args.length) {
      limitArg = int.tryParse(args[++i]);
    }
  }

  print('Konfigurasi:');
  print('• Mode: ${dryRun ? "DRY-RUN (Simulasi, tidak menulis ke Supabase)" : "LIVE (Menulis ke Supabase)"}');
  if (targetSetArg != null) print('• Filter Set: $targetSetArg');
  if (limitArg != null) print('• Limit per Set: $limitArg kartu');
  print('');

  // 2. Baca environment variables
  final env = _loadEnvFiles();
  final supabaseUrl = env['SUPABASE_URL']?.trim();
  final serviceRoleKey = env['SUPABASE_SERVICE_ROLE_KEY']?.trim();

  if (!dryRun) {
    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      stderr.writeln('[Error] SUPABASE_URL tidak ditemukan di service_role.env atau .env');
      exit(1);
    }
    if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
      stderr.writeln('[Error] SUPABASE_SERVICE_ROLE_KEY tidak ditemukan di service_role.env');
      stderr.writeln('Pastikan service_role.env sudah diisi dengan benar.');
      exit(1);
    }
    print('• Supabase: Terhubung ke $supabaseUrl');
  }

  final stats = SeedStats();

  // 3. Fetch Kurs Mata Uang (Frankfurter API)
  print('\n[1/4] Mengambil kurs mata uang dari Frankfurter API...');
  final ratesSuccess = await _fetchExchangeRates(stats);
  if (!ratesSuccess) {
    stderr.writeln('[Fatal] Gagal mendapatkan kurs dari Frankfurter API. Script dihentikan.');
    exit(1);
  }
  print('✓ Kurs: 1 USD = Rp${stats.usdToIdr?.toStringAsFixed(0)} | 1 EUR = \$${stats.eurToUsd?.toStringAsFixed(4)} (Per ${stats.exchangeRateDate})');

  // 4. Daftar Set yang akan diproses
  final setsToProcess = targetSetArg != null ? [targetSetArg] : kDefaultTargetSets;

  final client = http.Client();
  final List<Map<String, dynamic>> batchBuffer = [];
  const int batchSize = 50;

  try {
    for (final setId in setsToProcess) {
      print('\n[2/4] Mengunduh daftar kartu untuk Set: "$setId"...');
      final setInfo = await _fetchWithRetry(
        client,
        'https://api.tcgdex.net/v2/en/sets/$setId',
      );

      if (setInfo == null) {
        print('[Warning] Set "$setId" tidak dapat diunduh. Melewati set ini.');
        continue;
      }

      final setName = setInfo['name'] as String? ?? setId;
      final rawCards = (setInfo['cards'] as List? ?? []);
      final totalCardsInSet = rawCards.length;
      final cardsList = limitArg != null ? rawCards.take(limitArg).toList() : rawCards;

      print('✓ Set "$setName" ($setId) memiliki $totalCardsInSet kartu. Memproses ${cardsList.length} kartu...');

      for (int i = 0; i < cardsList.length; i++) {
        final cardHeader = cardsList[i];
        final cardId = cardHeader['id'] as String;
        stats.totalProcessed++;

        // Jeda ~200ms antar request agar sopan ke server TCGdex
        await Future.delayed(const Duration(milliseconds: 200));

        final cardDetail = await _fetchWithRetry(
          client,
          'https://api.tcgdex.net/v2/en/cards/$cardId',
        );

        if (cardDetail == null) {
          stats.failedCardIds.add(cardId);
          stdout.write('E'); // Error
          continue;
        }

        // Hitung harga sesuai spesifikasi aturan harga referensi
        final cardRow = _processCardData(
          cardDetail: cardDetail,
          setId: setId,
          setName: setName,
          stats: stats,
        );

        stats.succeeded++;
        batchBuffer.add(cardRow);
        stdout.write(cardRow['has_price'] == true ? '.' : 'o'); // . = berharga, o = tanpa harga

        // Jika buffer mencapai batchSize dan bukan dryRun, upsert ke Supabase
        if (!dryRun && batchBuffer.length >= batchSize) {
          final ok = await _upsertBatchToSupabase(
            client: client,
            supabaseUrl: supabaseUrl!,
            serviceRoleKey: serviceRoleKey!,
            rows: List.from(batchBuffer),
          );
          if (!ok) {
            print('\n[Warning] Gagal upsert batch ${batchBuffer.length} kartu ke Supabase.');
          }
          batchBuffer.clear();
        }
      }
      print(''); // baris baru setelah dot progress per set
    }

    // Flush sisa buffer yang belum terkirim
    if (!dryRun && batchBuffer.isNotEmpty) {
      final ok = await _upsertBatchToSupabase(
        client: client,
        supabaseUrl: supabaseUrl!,
        serviceRoleKey: serviceRoleKey!,
        rows: List.from(batchBuffer),
      );
      if (!ok) {
        print('\n[Warning] Gagal upsert sisa batch ${batchBuffer.length} kartu ke Supabase.');
      }
      batchBuffer.clear();
    }
  } finally {
    client.close();
  }

  // 5. Cetak Ringkasan Statistik
  _printStatistics(stats, dryRun);
}

/// Helper untuk membaca file .env dan service_role.env secara manual
Map<String, String> _loadEnvFiles() {
  final result = <String, String>{};

  void parseFile(String filename) {
    final file = File(filename);
    if (!file.existsSync()) return;
    final lines = file.readAsLinesSync();
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eqIdx = line.indexOf('=');
      if (eqIdx > 0) {
        final key = line.substring(0, eqIdx).trim();
        final val = line.substring(eqIdx + 1).trim();
        result[key] = val;
      }
    }
  }

  parseFile('.env');
  parseFile('service_role.env'); // Timpa dengan nilai dari service_role.env jika ada
  return result;
}

/// Mengambil kurs USD, EUR, IDR dari Frankfurter API
Future<bool> _fetchExchangeRates(SeedStats stats) async {
  final endpoints = [
    'https://api.frankfurter.dev/v1/latest?from=USD&to=EUR,IDR',
    'https://api.frankfurter.dev/latest?from=USD&to=EUR,IDR',
  ];

  for (final url in endpoints) {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        final eurPerUsd = (rates['EUR'] as num).toDouble();
        final idrPerUsd = (rates['IDR'] as num).toDouble();

        stats.exchangeRateDate = data['date'] as String? ?? 'Hari ini';
        stats.usdToIdr = idrPerUsd;
        stats.eurToUsd = eurPerUsd > 0 ? (1.0 / eurPerUsd) : 1.1;
        return true;
      }
    } catch (e) {
      // Coba endpoint alternatif berikutnya
    }
  }
  return false;
}

/// HTTP GET dengan retry dan exponential backoff (maksimal 3 kali)
Future<Map<String, dynamic>?> _fetchWithRetry(
  http.Client client,
  String url, {
  int maxRetries = 3,
}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final response = await client
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 429 || response.statusCode >= 500) {
        // Rate limit atau server error, tunggu dan coba lagi
        final backoff = Duration(milliseconds: 300 * pow(2, attempt).toInt());
        await Future.delayed(backoff);
      }
    } catch (e) {
      if (attempt == maxRetries) return null;
      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }
  }
  return null;
}

/// Memproses data kartu dan menerapkan aturan harga referensi
Map<String, dynamic> _processCardData({
  required Map<String, dynamic> cardDetail,
  required String setId,
  required String setName,
  required SeedStats stats,
}) {
  final pricing = cardDetail['pricing'] as Map<String, dynamic>?;

  double? priceUsd;
  double? priceEur;
  double? priceRefUsd;
  String? priceSource;

  if (pricing != null) {
    // 1. TCGPlayer (USD): Cari marketPrice tertinggi dari semua varian yang ada
    // Varian bisa bernama: normal, holofoil, reverse-holofoil, holo, reverse, dll.
    final tcg = pricing['tcgplayer'] as Map<String, dynamic>?;
    if (tcg != null) {
      double maxMarketPrice = 0.0;
      bool foundTcgPrice = false;

      tcg.forEach((key, val) {
        if (key != 'unit' && key != 'updated' && val is Map<String, dynamic>) {
          final mp = val['marketPrice'];
          if (mp != null && mp is num && mp > 0) {
            final valNum = mp.toDouble();
            if (valNum > maxMarketPrice) {
              maxMarketPrice = valNum;
              foundTcgPrice = true;
            }
          }
        }
      });

      if (foundTcgPrice) {
        priceUsd = maxMarketPrice;
      }
    }

    // 2. Cardmarket (EUR): Prioritas trend -> avg30 (bandingkan dengan varian holo jika ada)
    final cm = pricing['cardmarket'] as Map<String, dynamic>?;
    if (cm != null) {
      double? bestTrend;
      final trendNormal = (cm['trend'] as num?)?.toDouble();
      final trendHolo = (cm['trend-holo'] as num?)?.toDouble();

      if (trendNormal != null && trendNormal > 0 && trendHolo != null && trendHolo > 0) {
        bestTrend = max(trendNormal, trendHolo);
      } else {
        bestTrend = (trendNormal != null && trendNormal > 0)
            ? trendNormal
            : ((trendHolo != null && trendHolo > 0) ? trendHolo : null);
      }

      if (bestTrend != null && bestTrend > 0) {
        priceEur = bestTrend;
      } else {
        // Fallback ke avg30
        final avg30Normal = (cm['avg30'] as num?)?.toDouble();
        final avg30Holo = (cm['avg30-holo'] as num?)?.toDouble();
        if (avg30Normal != null && avg30Normal > 0 && avg30Holo != null && avg30Holo > 0) {
          priceEur = max(avg30Normal, avg30Holo);
        } else {
          priceEur = (avg30Normal != null && avg30Normal > 0)
              ? avg30Normal
              : ((avg30Holo != null && avg30Holo > 0) ? avg30Holo : null);
        }
      }
    }
  }

  // 3. Menghitung price_ref_usd (nilai pembanding tunggal)
  if (priceUsd != null && priceUsd > 0) {
    priceRefUsd = priceUsd;
    priceSource = 'tcgplayer';
    stats.sourceTcgPlayer++;
  } else if (priceEur != null && priceEur > 0 && stats.eurToUsd != null) {
    priceRefUsd = priceEur * stats.eurToUsd!;
    priceSource = 'cardmarket';
    stats.sourceCardMarket++;
  }

  final bool hasPrice = priceRefUsd != null && priceRefUsd > 0;
  if (hasPrice) {
    stats.withPrice++;
  } else {
    stats.withoutPrice++;
  }

  // Snapshot harga IDR saat seed
  double? priceIdr;
  if (priceRefUsd != null && stats.usdToIdr != null) {
    priceIdr = (priceRefUsd * stats.usdToIdr!).roundToDouble();
  }

  // URL dasar gambar tanpa ekstensi (.webp akan ditambahkan di aplikasi)
  final String? rawImage = cardDetail['image'] as String?;

  // Card type
  String? cardType = cardDetail['category'] as String?;
  final typesList = cardDetail['types'] as List?;
  if (typesList != null && typesList.isNotEmpty) {
    cardType = typesList.first.toString();
  }

  return {
    'id': cardDetail['id'],
    'local_id': cardDetail['localId']?.toString(),
    'name': cardDetail['name'] ?? 'Unknown Card',
    'set_id': setId,
    'set_name': setName,
    'rarity': cardDetail['rarity'] as String?,
    'card_type': cardType,
    'image_url': rawImage,
    'price_usd': priceUsd,
    'price_eur': priceEur,
    'price_ref_usd': priceRefUsd,
    'price_idr': priceIdr,
    'price_source': priceSource,
    'has_price': hasPrice,
    'seeded_at': DateTime.now().toUtc().toIso8601String(),
  };
}

/// Melakukan upsert batch ke tabel `cards` Supabase via REST PostgREST
Future<bool> _upsertBatchToSupabase({
  required http.Client client,
  required String supabaseUrl,
  required String serviceRoleKey,
  required List<Map<String, dynamic>> rows,
}) async {
  final endpoint = '$supabaseUrl/rest/v1/cards';

  try {
    final response = await client.post(
      Uri.parse(endpoint),
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode(rows),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    } else {
      stderr.writeln('\n[Supabase Error ${response.statusCode}]: ${response.body}');
      return false;
    }
  } catch (e) {
    stderr.writeln('\n[Supabase Exception]: $e');
    return false;
  }
}

/// Mencetak rekapitulasi statistik pipeline
void _printStatistics(SeedStats stats, bool dryRun) {
  final duration = DateTime.now().difference(stats.startTime);

  print('\n====================================================');
  print('               STATISTIK SEED PIPELINE              ');
  print('====================================================');
  print('• Status: ${dryRun ? "SIMULASI (DRY-RUN)" : "SELESAI (SUKSES TERSIMPAN)"}');
  print('• Durasi Total          : ${duration.inMinutes}m ${duration.inSeconds % 60}s');
  print('• Kurs Acuan Digunakan  : 1 USD = Rp${stats.usdToIdr?.toStringAsFixed(0)} (Per ${stats.exchangeRateDate})');
  print('• Total Kartu Diproses  : ${stats.totalProcessed}');
  print('• Berhasil Diparsing    : ${stats.succeeded}');
  print('• Kartu dengan Harga    : ${stats.withPrice} (${((stats.withPrice / (stats.succeeded > 0 ? stats.succeeded : 1)) * 100).toStringAsFixed(1)}%)');
  print('  - Sumber TCGPlayer    : ${stats.sourceTcgPlayer}');
  print('  - Sumber Cardmarket   : ${stats.sourceCardMarket}');
  print('• Kartu Tanpa Harga     : ${stats.withoutPrice}');
  print('• Kartu Gagal           : ${stats.failedCardIds.length}');
  if (stats.failedCardIds.isNotEmpty) {
    print('  - ID yang Gagal       : ${stats.failedCardIds.join(', ')}');
  }
  print('====================================================\n');
}
