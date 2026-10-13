import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';

enum AuthStatus { idle, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.idle,
    this.user,
    this.errorMessage,
  });

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

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

  Future<bool> login({
    required String username,
    required String password,
  }) =>
      _run(() => AuthService.login(username: username, password: password));

  /// Sesi 2 hanya mengosongkan state. Hapus token session ditambah di Sesi 3.
  void logout() => state = const AuthState();

  void clearError() {
    if (state.status == AuthStatus.error) state = const AuthState();
  }

  Future<bool> _run(Future<UserModel> Function() action) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await action();
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
