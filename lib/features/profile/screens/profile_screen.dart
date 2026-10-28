import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/interaction_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/providers/currency_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dex/providers/recommendation_provider.dart';
import '../../marketplace/providers/order_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/watchlist_provider.dart';
import '../widgets/whatsapp_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Radar Minat & Personalisasi AI di profil.
  /// Ubah menjadi true jika ingin menampilkan visualisasi algoritma.
  static const bool _showInterestRadar = false;

  bool _isTogglingBiometric = false;
  bool _isUpdatingPhoto = false;

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      setState(() => _isUpdatingPhoto = true);

      final user = ref.read(authProvider).user;
      if (user == null) {
        setState(() => _isUpdatingPhoto = false);
        return;
      }

      // Salin foto ke direktori dokumen aplikasi agar permanen
      final appDir = await getApplicationDocumentsDirectory();
      final profilesDir = Directory(p.join(appDir.path, 'profiles'));
      if (!await profilesDir.exists()) {
        await profilesDir.create(recursive: true);
      }

      final fileName =
          'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage =
          await File(pickedFile.path).copy(p.join(profilesDir.path, fileName));

      // Hapus file foto lama jika ada
      if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
        final oldFile = File(user.photoUrl!);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (_) {}
        }
      }

      await ref.read(authProvider.notifier).updateUserPhoto(savedImage.path);

      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui!'),
            backgroundColor: AppColors.snackBarSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      final oldFile = File(user.photoUrl!);
      if (await oldFile.exists()) {
        try {
          await oldFile.delete();
        } catch (_) {}
      }
    }

    await ref.read(authProvider.notifier).updateUserPhoto(null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil dihapus.'),
          backgroundColor: AppColors.surfaceHighest,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPhotoOptionsBottomSheet(UserModel user) {
    final textTheme = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ubah Foto Profil',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.gold),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.cyan),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
              if (user.photoUrl != null && user.photoUrl!.isNotEmpty) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.snackBarError),
                  title: const Text(
                    'Hapus Foto Profil',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeProfileImage();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
          backgroundColor: value ? AppColors.snackBarSuccess : AppColors.surfaceHighest,
        ),
      );
    } else {
      final error = ref.read(authProvider).errorMessage ??
          'Gagal mengubah pengaturan biometrik.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.snackBarError,
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
            backgroundColor: AppColors.snackBarSuccess,
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                      onTap: _isUpdatingPhoto
                          ? null
                          : () => _showPhotoOptionsBottomSheet(user),
                      borderRadius: BorderRadius.circular(36),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.surfaceHigh,
                        backgroundImage: (user.photoUrl != null &&
                                user.photoUrl!.isNotEmpty &&
                                File(user.photoUrl!).existsSync())
                            ? FileImage(File(user.photoUrl!))
                            : null,
                        child: _isUpdatingPhoto
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.gold,
                                ),
                              )
                            : (user.photoUrl == null ||
                                    user.photoUrl!.isEmpty ||
                                    !File(user.photoUrl!).existsSync())
                                ? Text(
                                    user.username.isNotEmpty
                                        ? user.username[0].toUpperCase()
                                        : 'H',
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: _isUpdatingPhoto
                            ? null
                            : () => _showPhotoOptionsBottomSheet(user),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 13,
                            color: AppColors.onGold,
                          ),
                        ),
                      ),
                    ),
                  ],
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

          // Saldo Virtual & Saldo Ditahan
          Consumer(
            builder: (context, ref, _) {
              final orderState = ref.watch(orderProvider);
              final reservedAmount = orderState.totalReservedAmount;

              return Container(
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
                          'Saldo (simulasi)',
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
                    if (reservedAmount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withAlpha(120),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_clock,
                              size: 13,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Saldo ditahan: ${formatIdr(reservedAmount)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Dapat digunakan untuk simulasi transaksi di marketplace.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              );
            },
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
          // Aktifkan _showInterestRadar = true di atas jika ingin menampilkan radar ini ke dosen
          if (_showInterestRadar) ...[
            _buildInterestSection(context, user, textTheme),
            const SizedBox(height: 24),
          ],

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
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(
                    Icons.chat_outlined,
                    color: Color(0xFF25D366),
                  ),
                  title: const Text('Nomor WhatsApp (Koordinasi COD)'),
                  subtitle: Text(
                    user.whatsappNumber != null &&
                            user.whatsappNumber!.trim().isNotEmpty
                        ? 'Tersimpan (${WhatsAppHelper.maskPhoneNumber(user.whatsappNumber)})'
                        : 'Belum diatur (Wajib sebelum pesan / jual)',
                    style: textTheme.bodySmall?.copyWith(
                      color: user.whatsappNumber != null &&
                              user.whatsappNumber!.trim().isNotEmpty
                          ? AppColors.onSurfaceVariant
                          : AppColors.gold,
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    WhatsAppDialog.show(
                      context,
                      initialPhone: user.whatsappNumber,
                    );
                  },
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
                    final orderState = ref.watch(orderProvider);
                    final actionCount = orderState.actionRequiredCount;
                    return ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined,
                          color: AppColors.gold),
                      title: const Text('Pesanan Saya (Rekber)'),
                      subtitle: Text(
                        actionCount > 0
                            ? '$actionCount pesanan butuh konfirmasi'
                            : '${orderState.orders.length} pesanan tercatat',
                        style: TextStyle(
                          fontSize: 11,
                          color: actionCount > 0
                              ? AppColors.gold
                              : AppColors.outline,
                          fontWeight: actionCount > 0
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (actionCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$actionCount',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                      onTap: () => context.push('/marketplace/orders'),
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
                          color: AppColors.gold),
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
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.history_toggle_off,
                      color: AppColors.gold),
                  title: const Text('Reset Jejak Rekomendasi'),
                  subtitle: const Text(
                    'Bersihkan data riwayat minat di perangkat ini',
                    style: TextStyle(fontSize: 11, color: AppColors.outline),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _confirmResetInteractions(user.id),
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
