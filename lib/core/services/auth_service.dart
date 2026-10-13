import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_db.dart';
import '../database/supabase_client.dart';
import '../models/user_model.dart';
import '../utils/constant_time_compare.dart';

/// Error yang pesannya aman ditampilkan langsung ke user.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 16;
  static const int keyLength = 32;

  // ---------------------------------------------------------------------------
  // PBKDF2
  // ---------------------------------------------------------------------------

  /// Salt 16 byte dari Fortuna (CSPRNG pointycastle), di-seed dengan
  /// Random.secure() milik OS. Salt unik per user membuat dua password sama
  /// menghasilkan hash berbeda, sehingga tabel hash siap pakai (rainbow table)
  /// tidak berguna.
  static Uint8List generateSalt() {
    final osRandom = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => osRandom.nextInt(256)),
    );
    final fortuna = FortunaRandom()..seed(KeyParameter(seed));
    return fortuna.nextBytes(saltLength);
  }

  /// PBKDF2-HMAC-SHA256: HMAC-SHA256 diulang 100.000 kali. Pengulangan ini
  /// sengaja membuat satu tebakan password butuh waktu, jadi brute force
  /// jutaan tebakan menjadi sangat mahal. Output 32 byte, dikembalikan hex.
  static String _derive(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, keyLength));
    final key = derivator.process(Uint8List.fromList(utf8.encode(password)));
    return _toHex(key);
  }

  /// 100k iterasi makan ~1 detik di HP. Dijalankan di isolate terpisah supaya
  /// UI (loading spinner) tidak macet.
  static Future<String> hashPassword(String password, Uint8List salt) {
    return Isolate.run(() => _derive(password, salt));
  }

  static String _toHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _fromHex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Register & Login
  // ---------------------------------------------------------------------------

  static SupabaseClient get _client {
    if (!SupabaseService.isInitialized) {
      throw const AuthFailure(
        'Server belum terhubung. Cek koneksi internet lalu coba lagi.',
      );
    }
    return SupabaseService.client;
  }

  static Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final salt = generateSalt();
    final hash = await hashPassword(password, salt);

    final Map<String, dynamic> result;
    try {
      final response = await _client.rpc('register_user', params: {
        'p_username': username,
        'p_email': email,
        'p_password_hash': hash,
        'p_salt': _toHex(salt),
      });
      result = Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] register_user: ${e.message}');
      throw const AuthFailure('Gagal mendaftar. Coba lagi sebentar lagi.');
    } catch (e) {
      debugPrint('[HoloDex Error] register_user: $e');
      throw const AuthFailure('Tidak bisa menghubungi server.');
    }

    if (result['success'] != true) {
      throw AuthFailure(result['error'] as String? ?? 'Gagal mendaftar.');
    }

    final user = UserModel.fromJson(
      Map<String, dynamic>.from(result['user'] as Map),
    );
    await _cacheUser(user);
    return user;
  }

  static Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final Map<String, dynamic> result;
    try {
      final response = await _client.rpc('get_login_credentials', params: {
        'p_username': username,
      });
      result = Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (e) {
      debugPrint('[HoloDex Error] get_login_credentials: ${e.message}');
      throw const AuthFailure('Gagal masuk. Coba lagi sebentar lagi.');
    } catch (e) {
      debugPrint('[HoloDex Error] get_login_credentials: $e');
      throw const AuthFailure('Tidak bisa menghubungi server.');
    }

    // Pesan sama untuk "user tidak ada" dan "password salah" supaya orang
    // lain tidak bisa mengecek username mana yang terdaftar.
    const wrongCredentials = AuthFailure('Username atau password salah.');

    if (result['success'] != true) {
      // Tetap hitung PBKDF2 agar waktu respons mirip dengan kasus password salah.
      await hashPassword(password, generateSalt());
      throw wrongCredentials;
    }

    final salt = _fromHex(result['salt'] as String);
    final storedHash = result['password_hash'] as String;
    final inputHash = await hashPassword(password, salt);

    if (!constantTimeEquals(inputHash, storedHash)) {
      throw wrongCredentials;
    }

    final user = UserModel.fromJson(
      Map<String, dynamic>.from(result['user'] as Map),
    );
    await _cacheUser(user);
    return user;
  }

  /// Simpan profil (tanpa hash) ke SQLite untuk tampilan offline di sesi berikut.
  static Future<void> _cacheUser(UserModel user) async {
    try {
      final db = await LocalDb.instance;
      await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal cache user ke SQLite: $e');
    }
  }
}
