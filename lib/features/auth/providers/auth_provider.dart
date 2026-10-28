import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/services/session_service.dart';

enum AuthStatus { idle, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final bool biometricPromptPending;

  const AuthState({
    this.status = AuthStatus.idle,
    this.user,
    this.errorMessage,
    this.biometricPromptPending = false,
  });

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? biometricPromptPending,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: errorMessage,
        biometricPromptPending:
            biometricPromptPending ?? this.biometricPromptPending,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Registrasi user baru + simpan sesi otomatis.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) =>
      _run(() => AuthService.register(
            username: username,
            email: email,
            password: password,
          ));

  /// Login dengan password + simpan sesi otomatis.
  Future<bool> login({
    required String username,
    required String password,
  }) =>
      _run(() => AuthService.login(username: username, password: password));

  /// Cek sesi saat splash screen. Mengembalikan true jika berhasil auto-login.
  Future<bool> checkSessionAndAutoLogin() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final hasSession = await SessionService.hasValidSession();
      if (!hasSession) {
        state = const AuthState(status: AuthStatus.idle);
        return false;
      }

      final userId = await SessionService.getActiveUserId();
      if (userId == null) {
        state = const AuthState(status: AuthStatus.idle);
        return false;
      }

      final user = await AuthService.getUserById(userId);
      if (user == null) {
        await SessionService.clearSession();
        state = const AuthState(status: AuthStatus.idle);
        return false;
      }

      // Jika user mengaktifkan biometrik di sesi sebelumnya
      if (user.fingerprintEnabled) {
        final isAvailable = await BiometricService.isBiometricAvailable();
        if (isAvailable) {
          final authenticated = await BiometricService.authenticate(
            reason: 'Pindai sidik jari untuk membuka HoloDex',
          );
          if (authenticated) {
            state = AuthState(status: AuthStatus.authenticated, user: user);
            return true;
          } else {
            // Biometrik gagal atau dibatalkan, siapkan user tapi minta masuk via login
            state = AuthState(
              status: AuthStatus.idle,
              user: user,
              biometricPromptPending: true,
            );
            return false;
          }
        }
      }

      // Jika biometrik tidak diaktifkan, langsung masuk
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (_) {
      state = const AuthState(status: AuthStatus.idle);
      return false;
    }
  }

  /// Login menggunakan biometrik secara manual (misal dari tombol di LoginScreen).
  Future<bool> loginWithBiometrics() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final savedUsername = await SessionService.getSavedUsername();
      if (savedUsername == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Silakan login dengan password terlebih dahulu.',
        );
        return false;
      }

      final user = await AuthService.getUserByUsername(savedUsername);
      if (user == null || !user.fingerprintEnabled) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Biometrik belum diaktifkan untuk akun ini.',
        );
        return false;
      }

      final authenticated = await BiometricService.authenticate(
        reason: 'Pindai sidik jari untuk login sebagai @${user.username}',
      );

      if (authenticated) {
        await SessionService.saveSession(
          userId: user.id,
          username: user.username,
        );
        state = AuthState(status: AuthStatus.authenticated, user: user);
        return true;
      } else {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Verifikasi sidik jari dibatalkan atau gagal.',
        );
        return false;
      }
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Terjadi kesalahan biometrik. Gunakan password.',
      );
      return false;
    }
  }

  /// Toggle aktivasi fingerprint untuk user yang sedang aktif.
  Future<bool> toggleFingerprint(bool enabled) async {
    final currentUser = state.user;
    if (currentUser == null) return false;

    if (enabled) {
      final isAvailable = await BiometricService.isBiometricAvailable();
      if (!isAvailable) {
        state = state.copyWith(
          errorMessage: 'Perangkat ini tidak memiliki sensor biometrik aktif.',
        );
        return false;
      }
      final verified = await BiometricService.authenticate(
        reason: 'Konfirmasi sidik jari untuk mengaktifkan fitur ini',
      );
      if (!verified) return false;
    }

    await AuthService.updateFingerprint(currentUser.id, enabled);
    final updated = currentUser.copyWith(fingerprintEnabled: enabled);
    state = state.copyWith(user: updated);
    return true;
  }

  /// Logout: hapus sesi di secure storage & SQLite, lalu bersihkan state.
  Future<void> logout() async {
    await SessionService.clearSession();
    state = const AuthState();
  }

  /// Perbarui saldo user saat ini (misal setelah beli kartu atau top up).
  void updateUserBalance(double newBalance) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(balanceIdr: newBalance),
      );
    }
  }

  /// Perbarui foto profil user aktif di state & SQLite.
  Future<void> updateUserPhoto(String? photoPath) async {
    final currentUser = state.user;
    if (currentUser == null) return;

    await AuthService.updateUserPhoto(currentUser.id, photoPath);
    state = state.copyWith(
      user: currentUser.copyWith(photoUrl: photoPath),
    );
  }

  /// Sinkronisasi profil user terkini dari Supabase (termasuk saldo & whatsapp) atau SQLite.
  Future<void> refreshProfile() async {
    final currentUser = state.user;
    if (currentUser == null) return;
    try {
      final user = await MarketplaceRepository.getUserProfile(currentUser.id) ??
          await AuthService.getUserById(currentUser.id);
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (_) {}
  }

  /// Memperbarui atau menghapus nomor WhatsApp pengguna
  Future<String?> updateWhatsapp(String? phoneNumber) async {
    final currentUser = state.user;
    if (currentUser == null) return null;

    final normalized = await OrderRepository.setMyWhatsapp(
      userId: currentUser.id,
      phoneNumber: phoneNumber,
    );

    final updated = currentUser.copyWith(
      whatsappNumber: normalized,
      resetWhatsappNumber: normalized == null,
    );
    state = state.copyWith(user: updated);
    return normalized;
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
    }
  }

  Future<bool> _run(Future<UserModel> Function() action) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await action();
      // Simpan sesi ke secure storage
      await SessionService.saveSession(
        userId: user.id,
        username: user.username,
      );
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on AuthFailure catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
      return false;
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Terjadi kesalahan. Coba lagi.',
      );
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
