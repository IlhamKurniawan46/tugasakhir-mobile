import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_db.dart';

/// Mengelola sesi user dengan TTL 7 hari menggunakan flutter_secure_storage
/// (Android Keystore) dan sinkronisasi ke tabel `sessions` di SQLite lokal.
class SessionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  static const String _kSessionToken = 'holodex_session_token';
  static const String _kUserId = 'holodex_user_id';
  static const String _kUsername = 'holodex_username';
  static const String _kExpiresAt = 'holodex_expires_at';

  static const Duration sessionTtl = Duration(days: 7);

  /// Menghasilkan token acak 32-byte hex untuk identifikasi sesi.
  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Simpan sesi baru ke Keystore dan SQLite saat login / register berhasil.
  static Future<void> saveSession({
    required String userId,
    required String username,
  }) async {
    final token = _generateToken();
    final now = DateTime.now();
    final expiresAt = now.add(sessionTtl);
    final expiresAtMs = expiresAt.millisecondsSinceEpoch;

    // 1. Simpan di secure storage
    await _storage.write(key: _kSessionToken, value: token);
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kExpiresAt, value: expiresAtMs.toString());

    // 2. Simpan di SQLite tabel sessions
    try {
      final db = await LocalDb.instance;
      // Bersihkan sesi lama user ini
      await db.delete('sessions', where: 'user_id = ?', whereArgs: [userId]);
      await db.insert(
        'sessions',
        {
          'id': token,
          'user_id': userId,
          'token': token,
          'expires_at': expiresAtMs,
          'created_at': now.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal simpan sesi ke SQLite: $e');
    }
  }

  /// Cek apakah ada sesi aktif dan belum kedaluwarsa (< 7 hari).
  static Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _kSessionToken);
    final userId = await _storage.read(key: _kUserId);
    final expiresAtStr = await _storage.read(key: _kExpiresAt);

    if (token == null || userId == null || expiresAtStr == null) {
      return false;
    }

    final expiresAtMs = int.tryParse(expiresAtStr);
    if (expiresAtMs == null) return false;

    final isExpired = DateTime.now().millisecondsSinceEpoch >= expiresAtMs;
    if (isExpired) {
      await clearSession();
      return false;
    }

    return true;
  }

  /// Ambil user ID dari sesi yang masih aktif.
  static Future<String?> getActiveUserId() async {
    if (!await hasValidSession()) return null;
    return await _storage.read(key: _kUserId);
  }

  /// Ambil username terakhir yang login (berguna untuk prefill & biometric).
  static Future<String?> getSavedUsername() async {
    return await _storage.read(key: _kUsername);
  }

  /// Hapus sesi dari secure storage dan SQLite saat logout.
  static Future<void> clearSession() async {
    final userId = await _storage.read(key: _kUserId);

    await _storage.delete(key: _kSessionToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kExpiresAt);
    // Note: _kUsername sengaja tidak dihapus agar bisa untuk pre-fill / quick login sidik jari

    if (userId != null) {
      try {
        final db = await LocalDb.instance;
        await db.delete('sessions', where: 'user_id = ?', whereArgs: [userId]);
      } catch (e) {
        debugPrint('[HoloDex Error] Gagal hapus sesi dari SQLite: $e');
      }
    }
  }
}
