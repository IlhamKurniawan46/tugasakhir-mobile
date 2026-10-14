import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(authProvider.notifier).register(
          username: _usernameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    if (ok && mounted) context.go('/dex');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          ref.read(authProvider.notifier).clearError(),
      child: AuthScaffold(
        title: 'Buat akun',
        subtitle: 'Saldo awal Rp100.000 untuk mencoba marketplace.',
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
                    autofillHints: const [AutofillHints.newUsername],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: '3–20 karakter: huruf, angka, atau _',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Username wajib diisi';
                      if (!_usernamePattern.hasMatch(value)) {
                        return 'Gunakan 3–20 huruf, angka, atau _';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'email@example.com',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Email wajib diisi';
                      if (!_emailPattern.hasMatch(value)) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _passwordCtrl,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password wajib diisi';
                      if (v.length < 8) return 'Minimal 8 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _confirmCtrl,
                    label: 'Ulangi password',
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: _submit,
                    validator: (v) => v != _passwordCtrl.text
                        ? 'Password tidak sama'
                        : null,
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
            label: 'Daftar',
            loadingLabel: 'Mengamankan password...',
            isLoading: auth.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sudah punya akun?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () {
                        ref.read(authProvider.notifier).clearError();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                child: const Text('Masuk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
