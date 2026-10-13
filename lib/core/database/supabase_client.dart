import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/env_loader.dart';

class SupabaseService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'Supabase belum diinisialisasi. Pastikan .env sudah diisi dengan benar.',
      );
    }
    return Supabase.instance.client;
  }

  static Future<void> init() async {
    final url = EnvLoader.supabaseUrl;
    final anonKey = EnvLoader.supabaseAnonKey;

    if (_isInitialized) return;

    if (!EnvLoader.isSupabaseConfigured) {
      print(
        '[HoloDex Warning] SUPABASE_URL atau SUPABASE_ANON_KEY belum diisi di file .env. '
        'Supabase belum aktif.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: false,
      );
      _isInitialized = true;
      print('[HoloDex] Supabase initialized successfully');
    } catch (e) {
      print('[HoloDex Error] Inisialisasi Supabase gagal: $e');
    }
  }

  static String lastError = '';

  /// Mengecek konektivitas database online Supabase
  static Future<bool> testConnection() async {
    lastError = '';
    if (!_isInitialized) {
      lastError = 'Supabase client belum terinisialisasi.';
      return false;
    }

    try {
      // Tes koneksi membaca release_events (tabel publik)
      await client.from('release_events').select('id').limit(1);
      print('[HoloDex] Supabase connected - koneksi database online aktif!');
      return true;
    } catch (e) {
      lastError = e.toString();
      print('[HoloDex Error] Gagal koneksi ke Supabase: $e');
      return false;
    }
  }
}
