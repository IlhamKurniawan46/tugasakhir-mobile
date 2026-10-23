import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Halaman Saran & Kesan Mata Kuliah Pemrograman Aplikasi Mobile.
/// Berisi teks evaluasi dan refleksi statis yang dapat diedit langsung pada variabel di bawah.
class SaranKesanScreen extends StatelessWidget {
  const SaranKesanScreen({super.key});

  // ===========================================================================
  // EDIT KONTEN STATIS DI SINI:
  // ===========================================================================
  static const String pengembangNama = 'M. Ilham Kurniawan / 124240078';
  static const String pengembangPeran = 'Pengembang HoloDex • Mahasiswa';
  static const String mataKuliah = 'Pemrograman Aplikasi Mobile';
  static const String deskripsiHeader =
      'Saran dan kesan mahasiswa selama menempuh perkuliahan.';

  static const String kesanPerkuliahan =
      'Selama mengikuti perkuliahan Pemrograman Aplikasi Mobile ini, saya mendapatkan banyak pengalaman dan wawasan mengenai ekosistem pengembangan aplikasi mobile modern menggunakan Flutter dan Dart.\n\n'
      'Tugas Akhir ini juga memberikan tantangan komprehensif yang sangat nyata.';

  static const String pesanDanSaran =
      'Materi perkuliahan dan bimbingan yang diberikan selama satu semester ini sudah sangat baik, terstruktur, dan relevan dengan perkembangan industri rekayasa perangkat lunak mobile masa kini.\n\n'
      'Saran saya untuk perkuliahan ke depannya, eksplorasi arsitektur Clean Code, state management Riverpod, serta integrasi teknologi modern (seperti Web3/Blockchain dan AI on-device) dapat terus dipertahankan dan diperluas pada silabus praktikum, sehingga mahasiswa memiliki portofolio proyek yang kuat dan siap bersaing.';
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saran & Kesan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Card Identitas & Mata Kuliah
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppColors.surfaceHigh),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: AppColors.gold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mataKuliah,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tugas Akhir Semester',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deskripsiHeader,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Box Pengisi / Identitas Mahasiswa
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: AppColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                pengembangNama,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                pengembangPeran,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Section Kesan Perkuliahan
            _buildContentSection(
              context: context,
              title: 'KESAN PERKULIAHAN',
              icon: Icons.format_quote_rounded,
              iconColor: AppColors.gold,
              content: kesanPerkuliahan,
            ),

            const SizedBox(height: 20),

            // 3. Section Pesan & Saran
            _buildContentSection(
              context: context,
              title: 'SARAN',
              icon: Icons.lightbulb_outline,
              iconColor: AppColors.cyan,
              content: pesanDanSaran,
            ),

            const SizedBox(height: 24),

            // 4. Footer Info
            Center(
              child: Text(
                'HoloDex • Pemrograman Aplikasi Mobile 2026',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.outline.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Section
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.outline,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Konten Teks Statis
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.surfaceHigh),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurface,
              height: 1.6,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}
