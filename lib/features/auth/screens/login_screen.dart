import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (ok && mounted) context.go('/home');
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
