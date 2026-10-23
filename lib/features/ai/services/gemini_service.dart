import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/card_model.dart';
import '../../../core/utils/env_loader.dart';

class GeminiCacheEntry {
  final String answer;
  final DateTime timestamp;

  const GeminiCacheEntry({
    required this.answer,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp).inMinutes >= 60; // TTL 1 jam
}

class GeminiService {
  // Cache in-memory per kartu & pertanyaan (TTL 1 jam)
  static final Map<String, GeminiCacheEntry> _cache = {};

  // Kandidat model Gemini generasi terbaru yang aktif dan responsif
  static const String defaultModel = 'gemini-3.5-flash';
  static const String fallbackModel = 'gemini-3.8-flash';
  static const String legacyFallbackModel = 'gemini-3.1-flash-lite';

  static String get _apiKey => EnvLoader.geminiApiKey;

  static bool get isConfigured =>
      _apiKey.isNotEmpty && !_apiKey.contains('your-gemini-api-key');

  /// Konsultasi AI Penasihat Kartu
  static Future<String> askCardAdvisor({
    required CardModel card,
    required String question,
    String? livePriceFormatted,
  }) async {
    // 1. Cek cache in-memory terlebih dahulu untuk menghemat kuota
    final priceTag = livePriceFormatted ?? '';
    final cacheKey = '${card.id}_${priceTag}_${question.trim().toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[HoloDex Gemini] Mengambil jawaban dari cache untuk: ${card.name}');
      return cached.answer;
    }

    if (!isConfigured) {
      return 'Kunci GEMINI_API_KEY belum dikonfigurasi di file .env. '
          'Silakan tambahkan API key Gemini Anda untuk mengaktifkan fitur ini.';
    }

    // 2. Susun System Prompt & Konteks Kartu
    const systemInstruction = '''
Kamu adalah HoloBot, asisten dan analis ahli kartu Pokémon TCG untuk kolektor Indonesia di aplikasi HoloDex.
Aturan ketat:
1. Jawab HANYA apa yang ditanyakan oleh pengguna secara langsung, padat, dan fokus pada inti pertanyaan (maksimal 1-2 paragraf).
2. Jika pengguna menanyakan kelayakan harga atau nilai pasar, WAJIB merujuk pada Harga Pasar Terkini di Aplikasi yang tertera di data.
3. JANGAN menambahkan topik perawatan fisik (seperti sleeve, toploader, grading) KECUALI jika pengguna secara spesifik menanyakannya.
4. Gunakan HANYA data kartu yang diberikan di bawah. DILARANG mengarang angka atau harga acuan di luar data ini.
5. Jangan pernah memberikan spekulasi finansial ilegal atau jaminan keuntungan.
''';

    final effectivePrice = livePriceFormatted ??
        (card.priceIdr != null ? 'Rp${card.priceIdr!.round()}' : 'Belum tercatat');

    final cardContext = '''
DATA KARTU:
- Nama: ${card.name}
- Set / Ekspansi: ${card.setName ?? card.setId ?? 'TCG'}
- Nomor Koleksi: #${card.localId ?? card.id}
- Kelangkaan (Rarity): ${card.rarity ?? 'Unknown'}
- Tipe: ${card.cardType ?? 'Pokémon'}
- Harga Pasar Terkini di Aplikasi: $effectivePrice
- Harga Acuan USD Asli: ${card.priceUsd != null ? '\$${card.priceUsd}' : '-'}
- Harga Acuan EUR Asli: ${card.priceEur != null ? '€${card.priceEur}' : '-'}
''';

    final userPrompt = '''
$cardContext
PERTANYAAN PENGGUNA:
$question
''';

    try {
      final answer = await _callGeminiApi(
        systemInstruction: systemInstruction,
        prompt: userPrompt,
      );

      // Simpan ke cache
      _cache[cacheKey] = GeminiCacheEntry(
        answer: answer,
        timestamp: DateTime.now(),
      );

      return answer;
    } catch (e) {
      debugPrint('[HoloDex Gemini Error] $e');
      rethrow;
    }
  }

  /// Konsultasi Umum HoloBot (tanpa konteks kartu spesifik)
  static Future<String> askGeneralAdvisor({
    required String question,
  }) async {
    final cacheKey = 'general_${question.trim().toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[HoloDex Gemini] Mengambil jawaban umum dari cache.');
      return cached.answer;
    }

    if (!isConfigured) {
      return 'Kunci GEMINI_API_KEY belum dikonfigurasi di file .env. '
          'Silakan tambahkan API key Gemini Anda untuk mengaktifkan fitur ini.';
    }

    const systemInstruction = '''
Kamu adalah HoloBot, asisten cerdas Pokémon TCG dan marketplace HoloDex untuk kolektor Indonesia.
Aturan ketat:
1. Batasi topik HANYA seputar kartu Pokémon TCG, aturan permainan, istilah kelangkaan (rarity), tips merawat koleksi, dan ekosistem marketplace HoloDex. Tolak dengan sopan topik di luar Pokémon TCG.
2. Karena kamu sedang berbicara dalam mode umum tanpa data kartu spesifik, DILARANG mengarang harga kartu atau angka pasar tertentu. Beri tahu pengguna untuk membuka detail kartu langsung di Dex jika ingin mengecek estimasi harga pasar terkini.
3. Jawab padat, ramah, dan to-the-point dalam Bahasa Indonesia (maksimal 2 paragraf).
''';

    final userPrompt = '''
PERTANYAAN PENGGUNA:
$question
''';

    try {
      final answer = await _callGeminiApi(
        systemInstruction: systemInstruction,
        prompt: userPrompt,
      );

      _cache[cacheKey] = GeminiCacheEntry(
        answer: answer,
        timestamp: DateTime.now(),
      );

      return answer;
    } catch (e) {
      debugPrint('[HoloDex Gemini Error General] $e');
      rethrow;
    }
  }

  /// Membuat deskripsi otomatis untuk listing jual kartu di pasar
  static Future<String> generateListingDescription({
    required CardModel card,
    required String conditionLabel,
  }) async {
    if (!isConfigured) {
      return 'Koleksi kartu Pokémon ${card.name} (${card.setName ?? 'TCG'}). '
          'Kondisi: $conditionLabel. Disimpan dalam sleeve & toploader.';
    }

    const systemInstruction = '''
Kamu adalah asisten penjual kartu Pokémon TCG di marketplace HoloDex Indonesia.
Buat deskripsi singkat (maksimal 2-3 kalimat) yang profesional, menarik pembeli, dan jujur mengenai kondisi kartu.
Sebutkan nama kartu, set, kondisi, dan rekomendasi perlindungan (misal toploader & sleeve). Gunakan Bahasa Indonesia.
''';

    final prompt = '''
Buatkan deskripsi listing penjualan untuk kartu:
- Nama: ${card.name}
- Set: ${card.setName ?? card.setId ?? 'TCG'}
- Kelangkaan: ${card.rarity ?? 'Kartu'}
- Kondisi Fisik: $conditionLabel
''';

    try {
      final response = await _callGeminiApi(
        systemInstruction: systemInstruction,
        prompt: prompt,
      );
      return response.replaceAll('*', '').trim();
    } catch (e) {
      debugPrint('[HoloDex Gemini Description Error] $e');
      return 'Dijual kartu Pokémon ${card.name} set ${card.setName ?? 'TCG'}. '
          'Kondisi fisik $conditionLabel, tersimpan rapi dalam sleeve.';
    }
  }

  /// Panggilan HTTP langsung ke Google Generative Language REST API (v1beta)
  static Future<String> _callGeminiApi({
    required String systemInstruction,
    required String prompt,
    String model = defaultModel,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
    );

    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.35,
        'maxOutputTokens': 1000,
        'thinkingConfig': {
          'thinkingBudget': 0,
        },
      }
    };

    http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('[HoloDex Gemini Error on $model] $e');
      if (model == defaultModel) {
        debugPrint('[HoloDex Gemini] Timeout/Network error, fallback ke model: $fallbackModel');
        return _callGeminiApi(
          systemInstruction: systemInstruction,
          prompt: prompt,
          model: fallbackModel,
        );
      } else if (model == fallbackModel) {
        debugPrint('[HoloDex Gemini] Timeout/Network error, fallback ke model cadangan: $legacyFallbackModel');
        return _callGeminiApi(
          systemInstruction: systemInstruction,
          prompt: prompt,
          model: legacyFallbackModel,
        );
      }
      rethrow;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is Map<String, dynamic> && part['text'] != null) {
              buffer.write(part['text']);
            }
          }
          final text = buffer.toString().trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
      throw Exception('Respons Gemini kosong atau tidak memiliki teks kandidat.');
    } else if (response.statusCode == 429) {
      throw Exception(
        'Batas kuota gratis AI telah tercapai (HTTP 429). '
        'Silakan tunggu beberapa saat lagi sebelum mencoba kembali.',
      );
    } else if (response.statusCode == 400 ||
        response.statusCode == 403 ||
        response.statusCode == 404 ||
        response.statusCode == 500 ||
        response.statusCode == 502 ||
        response.statusCode == 503) {
      // Jika model overload (503), tidak ditemukan (404), atau bermasalah, coba fallback bertingkat
      if (model == defaultModel) {
        debugPrint('[HoloDex Gemini] Model $model status ${response.statusCode}, fallback ke: $fallbackModel');
        return _callGeminiApi(
          systemInstruction: systemInstruction,
          prompt: prompt,
          model: fallbackModel,
        );
      } else if (model == fallbackModel) {
        debugPrint('[HoloDex Gemini] Model $model status ${response.statusCode}, fallback ke cadangan: $legacyFallbackModel');
        return _callGeminiApi(
          systemInstruction: systemInstruction,
          prompt: prompt,
          model: legacyFallbackModel,
        );
      }
      throw Exception(
        'Layanan AI sedang sibuk atau menolak permintaan (${response.statusCode}). '
        'Silakan coba kembali dalam beberapa saat.',
      );
    } else {
      throw Exception(
        'Server AI mengembalikan status ${response.statusCode}: ${response.body}',
      );
    }
  }

  /// Bersihkan seluruh cache in-memory
  static void clearCache() {
    _cache.clear();
  }
}
