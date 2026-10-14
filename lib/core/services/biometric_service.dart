import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wrapper untuk local_auth (autentikasi sidik jari / biometrik).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Cek apakah perangkat mendukung biometrik dan memiliki sensor yang siap.
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      debugPrint('[HoloDex Error] Cek biometrik gagal: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[HoloDex Error] Cek biometrik gagal: $e');
      return false;
    }
  }

  /// Cek tipe biometrik yang tersedia di perangkat (misal fingerprint, face).
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal membaca tipe biometrik: $e');
      return [];
    }
  }

  /// Lakukan proses autentikasi biometrik.
  /// [biometricOnly]: jika true, hanya sidik jari/wajah tanpa PIN perangkat.
  static Future<bool> authenticate({
    String reason = 'Pindai sidik jari untuk verifikasi akun HoloDex',
    bool biometricOnly = true,
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
      );
    } on PlatformException catch (e) {
      debugPrint('[HoloDex Error] Autentikasi biometrik error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[HoloDex Error] Autentikasi biometrik error: $e');
      return false;
    }
  }

  /// Batalkan dialog autentikasi yang sedang aktif jika ada.
  static Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
