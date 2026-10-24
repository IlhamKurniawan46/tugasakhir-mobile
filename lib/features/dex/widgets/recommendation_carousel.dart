import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/providers/currency_provider.dart';
import '../providers/recommendation_provider.dart';

/// Carousel horizontal rekomendasi kartu personal di layar Dex.
/// Aman dari overflow pada layar 320dp dan textScaleFactor 1.3.
class RecommendationCarousel extends ConsumerWidget {
  const RecommendationCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recommendationProvider);
    final currency = ref.watch(currencyProvider);
    final textTheme = Theme.of(context).textTheme;
    final textScaler = MediaQuery.textScalerOf(context);

    // Jika sedang loading pertama kali
    if (state.isLoading && state.items.isEmpty) {
      return _buildSkeleton(context, textTheme);
    }

    // Jika kosong, jangan tampilkan apa-apa (tidak memakan ruang permanen)
    if (state.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isColdStart = state.isColdStart;
    final title = isColdStart ? 'Pilihan Awal Untukmu' : 'Rekomendasi Untukmu';
    final subtitle = isColdStart
        ? 'Kartu populer & beragam untuk memulai perjalananmu'
        : 'Berdasarkan kartu dan kategori yang kamu minati';

    // Hitung tinggi carousel secara responsif mengikuti font scale agar bebas overflow
    final double carouselHeight = textScaler.scale(225.0).clamp(225.0, 275.0);
    final double cardWidth = textScaler.scale(136.0).clamp(136.0, 160.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Judul & Subjudul
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isColdStart
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : AppColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isColdStart
                        ? Icons.stars_rounded
                        : Icons.stars_rounded,
                    size: 16,
                    color: isColdStart ? AppColors.gold : AppColors.cyan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal List Kartu Kompak
          SizedBox(
            height: carouselHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return SizedBox(
                  width: cardWidth,
                  child: _buildCompactCard(
                    context: context,
                    item: item,
                    currency: currency,
                    textTheme: textTheme,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu kompak rekomendasi
  Widget _buildCompactCard({
    required BuildContext context,
    required dynamic item,
    required AppCurrency currency,
    required TextTheme textTheme,
  }) {
    final card = item.card;
    final isExploration = item.isExploration == true;

    // Kalkulasi harga live terkonversi sesuai mata uang pilihan
    final priceFormatted = CardPriceCalculator.formatCardPrice(card, currency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/dex/card/${card.id}', extra: card);
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExploration
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : AppColors.surfaceHigh,
              width: isExploration ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(7.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Gambar Kartu Pokémon (Rasio 63:88 fleksibel)
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 63 / 88,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: card.lowResImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: card.lowResImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color: AppColors.surfaceHighest,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceHighest,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    size: 20,
                                    color: AppColors.outline,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceHighest,
                                child: const Icon(Icons.style, size: 20),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // 2. Nama Kartu (1 baris ellipsis)
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.onSurface,
                  ),
                ),

                // 3. Harga Terkonversi
                Text(
                  priceFormatted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 4),

                // 4. Chip Alasan Rekomendasi (maxLines 2)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: isExploration
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          isExploration ? FontWeight.w700 : FontWeight.w500,
                      color: isExploration
                          ? AppColors.gold
                          : AppColors.onSurfaceVariant,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Skeleton Shimmer Loading
  Widget _buildSkeleton(BuildContext context, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: 160,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 225,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => Container(
                width: 136,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
