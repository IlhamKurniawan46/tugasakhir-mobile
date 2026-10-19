import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/session_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _canUseBiometric = false;
  String? _savedUsername;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await BiometricService.isBiometricAvailable();
    final savedUsername = await SessionService.getSavedUsername();
    if (mounted) {
      setState(() {
        _canUseBiometric = available && (savedUsername != null);
        _savedUsername = savedUsername;
        if (savedUsername != null && _usernameCtrl.text.isEmpty) {
          _usernameCtrl.text = savedUsername;
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authProvider.notifier).login(
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (ok && mounted) context.go('/dex');
  }

  Future<void> _submitBiometric() async {
    final ok = await ref.read(authProvider.notifier).loginWithBiometrics();
    if (ok && mounted) context.go('/dex');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Masuk',
      subtitle: 'Lanjutkan ke katalog dan koleksi kartumu.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordCtrl,
                  onSubmitted: _submit,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                ),
              ],
            ),
          ),
        ),
        if (auth.status == AuthStatus.error && auth.errorMessage != null) ...[
          const SizedBox(height: 16),
          AuthErrorBox(message: auth.errorMessage!),
        ],
        const SizedBox(height: 24),
        AuthSubmitButton(
          label: 'Masuk',
          loadingLabel: 'Memverifikasi...',
          isLoading: auth.isLoading,
          onPressed: _submit,
        ),
        if (_canUseBiometric) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading ? null : _submitBiometric,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 50),
                foregroundColor: AppColors.goldSoft,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: const Icon(Icons.fingerprint, color: AppColors.gold),
              label: Text(
                _savedUsername != null
                    ? 'Masuk sebagai @$_savedUsername (Sidik Jari)'
                    : 'Masuk dengan Sidik Jari',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Belum punya akun?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () {
                      ref.read(authProvider.notifier).clearError();
                      context.push('/register');
                    },
              child: const Text('Daftar'),
            ),
          ],
        ),
      ],
    );
  }
}
