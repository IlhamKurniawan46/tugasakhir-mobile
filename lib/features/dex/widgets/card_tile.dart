import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import 'price_badge.dart';

class CardTile extends StatelessWidget {
  final CardModel card;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasRarity = card.rarity != null && card.rarity!.trim().isNotEmpty;
    final rarityText = card.rarity?.trim() ?? '';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Box: Badge Rarity (Kiri) & Indikator Multi-select (Kanan) di luar gambar
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    // Badge Rarity rata kiri
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: hasRarity
                            ? Semantics(
                                label: 'Kelangkaan: $rarityText',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLowest.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.surfaceHigh,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      rarityText,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.goldSoft,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    // Indikator Pilihan (Mode Multi-select)
                    if (isSelectionMode)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceLowest,
                        ),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.outline.withValues(alpha: 0.8),
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Tambahan jarak antara rarity dan gambar kartu
            const SizedBox(height: 5),

            // 2. Gambar Kartu (Aspect Ratio standar kartu Pokémon 63:88)
            // Mengambil lebar penuh (padding horizontal 10) agar batas kiri & kanan sejajar dengan Rarity, Nama, dan Set
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: AspectRatio(
                aspectRatio: 63 / 88,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: card.lowResImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: card.lowResImageUrl!,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceLow,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surfaceLow,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.outline,
                                size: 32,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceLow,
                          child: const Center(
                            child: Icon(
                              Icons.style_outlined,
                              color: AppColors.outline,
                              size: 36,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // 3. Info Kartu: Nama, Set & Badge Harga (padding bottom 8dp sama simetris dengan padding top 8dp)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.setName ?? card.setId ?? 'Pokémon TCG',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  PriceBadge(card: card),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
