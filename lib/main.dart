import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/database/local_db.dart';
import 'core/database/supabase_client.dart';
import 'core/services/currency_service.dart';
import 'core/services/notification_service.dart';
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

  // 4. Inisialisasi kurs mata uang (offline-first via SQLite cache + background refresh)
  try {
    await CurrencyService.initRates();
  } catch (e) {
    print('[HoloDex Error] Inisialisasi CurrencyService gagal: $e');
  }

  // 5. Inisialisasi service notifikasi lokal (Ketentuan #12)
  try {
    await NotificationService.instance.init();
    setupNotificationNavigation();
  } catch (e) {
    print('[HoloDex Error] Inisialisasi NotificationService gagal: $e');
  }

  // 6. Jalankan aplikasi dibungkus ProviderScope (Riverpod)
  runApp(
    const ProviderScope(
      child: HoloDexApp(),
    ),
  );
}
