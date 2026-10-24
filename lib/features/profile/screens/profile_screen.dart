import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/interaction_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dex/providers/recommendation_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/watchlist_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isTogglingBiometric = false;

  Future<void> _handleToggleFingerprint(bool value) async {
    setState(() => _isTogglingBiometric = true);
    final success =
        await ref.read(authProvider.notifier).toggleFingerprint(value);
    setState(() => _isTogglingBiometric = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Login sidik jari berhasil diaktifkan!'
                : 'Login sidik jari dinonaktifkan.',
          ),
          backgroundColor: value ? AppColors.success : AppColors.surfaceHighest,
        ),
      );
    } else {
      final error = ref.read(authProvider).errorMessage ??
          'Gagal mengubah pengaturan biometrik.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Sesi login pada perangkat ini akan dihapus. Kamu harus memasukkan password untuk login kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceLowest,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _confirmResetInteractions(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Profil Minat?'),
        content: const Text(
          'Seluruh riwayat interaksi dan preferensi rekomendasi di perangkat ini akan dihapus. '
          'Rekomendasi di beranda dan pasar akan kembali ke setelan awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceLowest,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus & Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await InteractionService.instance.clearUserInteractions(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Riwayat minat berhasil direset.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Pokémon':
        return Icons.catching_pokemon;
      case 'Tipe':
        return Icons.local_fire_department;
      case 'Set':
        return Icons.style;
      case 'Rarity':
        return Icons.military_tech;
      case 'Budget':
        return Icons.savings;
      default:
        return Icons.star;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Pokémon':
        return AppColors.gold;
      case 'Tipe':
        return AppColors.cyan;
      case 'Set':
        return AppColors.pink;
      case 'Rarity':
        return const Color(0xFFB388FF);
      case 'Budget':
        return AppColors.success;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Kolektor'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Header Card Profil
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.surfaceHigh,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : 'H',
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${user.username}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user.email != null && user.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Kolektor Terverifikasi',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Saldo Virtual
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface,
                  AppColors.surfaceHigh.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo Virtual HoloDex',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Icon(Icons.wallet, color: AppColors.gold, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatIdr(user.balanceIdr),
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dapat digunakan untuk simulasi transaksi di marketplace.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ringkasan Portofolio Koleksi Saya
          Builder(
            builder: (context) {
              final collectionState = ref.watch(collectionProvider);
              final selectedCurrency = ref.watch(currencyProvider);
              final totalValue =
                  collectionState.getTotalInCurrency(selectedCurrency);

              final String formattedValue;
              if (totalValue != null) {
                formattedValue =
                    PriceFormatter.format(totalValue, selectedCurrency.code);
              } else {
                formattedValue = 'Kurs belum tersedia';
              }

              return InkWell(
                onTap: () => context.push('/collection'),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.collections_bookmark,
                          color: AppColors.cyan,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Nilai Koleksi Saya',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedValue,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.cyan,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${collectionState.items.length} kartu',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Profil Minat & Personalisasi (AI On-Device)
          _buildInterestSection(context, user, textTheme),
          const SizedBox(height: 24),

          // Pengaturan Keamanan
          Text(
            'KEAMANAN & AUTENTIKASI',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.outline,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.fingerprint,
                    color: AppColors.gold,
                  ),
                  title: const Text('Login Sidik Jari (Biometrik)'),
                  subtitle: Text(
                    user.fingerprintEnabled
                        ? 'Aktif - Buka aplikasi dengan sensor sidik jari'
                        : 'Nonaktif - Masuk menggunakan password',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  value: user.fingerprintEnabled,
                  onChanged: _isTogglingBiometric
                      ? null
                      : (val) => _handleToggleFingerprint(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Menu Koleksi
          Text(
            'MENU KOLEKSI & PANTAUAN',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.outline,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final collectionCount =
                        ref.watch(collectionProvider).items.length;
                    return ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined,
                          color: AppColors.gold),
                      title: const Text('Koleksi Saya'),
                      subtitle: Text(
                        '$collectionCount kartu tersimpan',
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push('/collection'),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                Consumer(
                  builder: (context, ref, _) {
                    final watchlistCount =
                        ref.watch(watchlistProvider).items.length;
                    return ListTile(
                      leading: const Icon(Icons.favorite_outline,
                          color: AppColors.pink),
                      title: const Text('Watchlist & Pantauan Harga'),
                      subtitle: Text(
                        '$watchlistCount kartu dipantau',
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push('/watchlist'),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Menu Lainnya
          Text(
            'MENU LAINNYA',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.outline,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined,
                      color: AppColors.gold),
                  title: const Text('Saran & Kesan Mata Kuliah'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.go('/saran-kesan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Keluar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar dari Akun'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestSection(
    BuildContext context,
    UserModel user,
    TextTheme textTheme,
  ) {
    final recState = ref.watch(recommendationProvider);
    final profile = recState.profile;
    final topInterests = profile?.getTopInterests(limit: 5) ?? [];
    final interactionCount = recState.interactionCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
                const SizedBox(width: 6),
                Text(
                  'MINAT & PERSONALISASI (AI)',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.outline,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'On-Device',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radar Selera Kolektor',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          interactionCount > 0
                              ? '$interactionCount interaksi terekam (Peluruhan 14 hari)'
                              : 'Belum cukup interaksi untuk membaca seleramu.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (interactionCount > 0)
                    IconButton(
                      icon: const Icon(Icons.refresh_outlined, size: 20),
                      color: AppColors.outline,
                      tooltip: 'Hitung ulang rekomendasi',
                      onPressed: () => ref
                          .read(recommendationProvider.notifier)
                          .loadRecommendations(force: true),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (topInterests.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: AppColors.cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sistem belajar otomatis dari aktivitasmu! Cukup cari Pokémon favorit, klik detail kartu, tambahkan ke watchlist, atau beli di pasar.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...topInterests.map((interest) {
                  final catColor = _getCategoryColor(interest.category);
                  final catIcon = _getCategoryIcon(interest.category);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(catIcon, size: 14, color: catColor),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                interest.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                interest.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${(interest.percentage * 100).toInt()}%',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: interest.percentage,
                            backgroundColor: AppColors.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(catColor),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Reset Jejak Rekomendasi'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 42),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () => _confirmResetInteractions(user.id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
