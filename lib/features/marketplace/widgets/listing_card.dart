import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';

/// Widget kartu item listing dagangan di grid Pasar HoloDex.
/// Mematuhi aspek rasio kartu Pokémon asli (63:88), padding aman, dan anti-overflow.
class ListingCard extends ConsumerWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final bool isMatchForYou;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.isMatchForYou = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final selectedCurrency = ref.watch(currencyProvider);
    final card = listing.card;

    // Hitung harga listing sesuai preferensi mata uang user
    String displayPrice;
    if (selectedCurrency == AppCurrency.idr) {
      displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
    } else {
      final converted = CurrencyService.convert(
        listing.priceIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      if (converted != null) {
        displayPrice = PriceFormatter.format(converted, selectedCurrency.code);
      } else {
        displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.surfaceHigh.withAlpha(128),
          width: 1,
        ),
      ),
      color: AppColors.surface,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Kartu Pokémon dengan Aspect Ratio 63/88
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 63 / 88,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: card?.lowResImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: card!.lowResImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppColors.surfaceHigh,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: AppColors.surfaceHigh,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.onSurfaceVariant,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.surfaceHigh,
                                  child: const Icon(
                                    Icons.style_outlined,
                                    color: AppColors.onSurfaceVariant,
                                    size: 32,
                                  ),
                                ),
                        ),
                        // Badge Kondisi Kartu di pojok atas
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: listing.conditionBadgeColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              listing.condition.toUpperCase().replaceAll('_', ' '),
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Badge Rekomendasi "Cocok" di pojok kanan atas
                        if (isMatchForYou)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cyan,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Colors.black,
                                    size: 9,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Cocok',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Nama Kartu
              Text(
                card?.name ?? 'Kartu Pokémon',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),

              // Sub-info: Rarity & Set
              const SizedBox(height: 2),
              Text(
                '${card?.setName ?? card?.setId ?? 'TCG'} ${card?.localId != null ? '#${card!.localId}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),

              const SizedBox(height: 6),

              // Harga Pasar Listing
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  displayPrice,
                  maxLines: 1,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Info Penjual & Lokasi
              Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '@${listing.sellerUsername ?? 'Penjual'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
