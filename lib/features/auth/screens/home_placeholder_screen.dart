import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/price_formatter.dart';
import '../providers/auth_provider.dart';

/// Layar sementara setelah login. Diganti bottom nav 5 tab di Sesi 3.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final text = Theme.of(context).textTheme;

    if (user == null) {
      // Misalnya setelah hot restart: state hilang, balik ke login.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HoloDex'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Halo, @${user.username}',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (user.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user.email!,
              style: text.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatIdr(user.balanceIdr),
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ini Placeholder',
            style: text.bodySmall?.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
