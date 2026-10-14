import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../auth/providers/auth_provider.dart';

class SaranKesanScreen extends ConsumerStatefulWidget {
  const SaranKesanScreen({super.key});

  @override
  ConsumerState<SaranKesanScreen> createState() => _SaranKesanScreenState();
}

class _SaranKesanScreenState extends ConsumerState<SaranKesanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kesanCtrl = TextEditingController();
  final _saranCtrl = TextEditingController();
  int _rating = 5;
  bool _submitted = false;

  @override
  void dispose() {
    _kesanCtrl.dispose();
    _saranCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitted = true);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Terima Kasih!'),
          ],
        ),
        content: const Text(
          'Saran dan kesan untuk mata kuliah Pemrograman Aplikasi Mobile berhasil disimpan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saran & Kesan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: AppColors.gold, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Pemrograman Aplikasi Mobile',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Form evaluasi dan umpan balik tugas akhir pembuatan aplikasi HoloDex.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pengisi: @${user.username}',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating Kepuasan
                  Text(
                    'RATING PENGALAMAN BELAJAR',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.outline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppColors.surfaceHigh),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return IconButton(
                          iconSize: 32,
                          icon: Icon(
                            starValue <= _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: starValue <= _rating
                                ? AppColors.gold
                                : AppColors.surfaceHigh,
                          ),
                          onPressed: () {
                            setState(() => _rating = starValue);
                          },
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kesan
                  Text(
                    'KESAN PERKULIAHAN',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.outline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _kesanCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Tuliskan pengalaman, wawasan baru, atau tantangan menarik selama perkuliahan...',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Kesan tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Pesan & Saran
                  Text(
                    'PESAN & SARAN',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.outline,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _saranCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Tuliskan saran untuk pengembangan materi, praktikum, atau metode pengajaran ke depan...',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Saran tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // Tombol Kirim
                  FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: Icon(_submitted ? Icons.check : Icons.send),
                    label: Text(
                      _submitted ? 'Kirim Ulang' : 'Kirim Umpan Balik',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
