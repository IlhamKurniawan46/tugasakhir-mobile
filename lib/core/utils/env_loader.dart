import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvLoader {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // Jika file .env belum dibuat atau gagal dibaca
      print('[HoloDex Error] Gagal memuat file .env: $e');
    }
  }

  static String get supabaseUrl {
    final raw = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    // Hilangkan trailing /rest/v1 atau garis miring di akhir jika terisi tidak sengaja
    return raw
        .replaceAll(RegExp(r'/rest/v1/?$'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  static String get supabaseAnonKey =>
      (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  static String get geminiApiKey =>
      (dotenv.env['GEMINI_API_KEY'] ?? '').trim();

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('your-anon-key');
}
