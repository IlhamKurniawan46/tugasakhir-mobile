import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/database/local_db.dart';
import 'core/database/supabase_client.dart';
import 'core/utils/env_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Muat environment variable dari .env
  await EnvLoader.init();

  // 2. Inisialisasi database lokal SQLite
  try {
    await LocalDb.instance;
  } catch (e) {
    print('[HoloDex Error] Inisialisasi LocalDb gagal: $e');
  }

  // 3. Inisialisasi Supabase
  try {
    await SupabaseService.init();
    if (SupabaseService.isInitialized) {
      await SupabaseService.testConnection();
    }
  } catch (e) {
    print('[HoloDex Error] Inisialisasi SupabaseService gagal: $e');
  }

  // 4. Jalankan aplikasi dibungkus ProviderScope (Riverpod)
  runApp(
    const ProviderScope(
      child: HoloDexApp(),
    ),
  );
}
