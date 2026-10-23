import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';

class CardRevealWidget extends ConsumerStatefulWidget {
  final CardModel card;
  final bool isRevealed;
  final VoidCallback onTap;

  const CardRevealWidget({
    super.key,
    required this.card,
    required this.isRevealed,
    required this.onTap,
  });

  @override
  ConsumerState<CardRevealWidget> createState() => _CardRevealWidgetState();
}

class _CardRevealWidgetState extends ConsumerState<CardRevealWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    if (widget.isRevealed) {
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CardRevealWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _flipController.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  bool _isHighRarity(String? rarity) {
    if (rarity == null) return false;
    final r = rarity.toLowerCase();
    return r.contains('ultra') ||
        r.contains('secret') ||
        r.contains('holo') ||
        r.contains('special') ||
        r.contains('vmax') ||
        r.contains('vstar');
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = ref.watch(currencyProvider);
    final isHigh = _isHighRarity(widget.card.rarity);

    // Format harga live
    String priceText;
    if (widget.card.priceIdr != null) {
      if (selectedCurrency == AppCurrency.idr) {
        priceText = PriceFormatter.formatIdr(widget.card.priceIdr);
      } else {
        final converted = CurrencyService.convert(
          widget.card.priceIdr,
          from: 'IDR',
          to: selectedCurrency.code,
        );
        priceText = converted != null
            ? PriceFormatter.format(converted, selectedCurrency.code)
            : PriceFormatter.formatIdr(widget.card.priceIdr);
      }
    } else {
      priceText = 'Harga N/A';
    }

    // Ukuran kartu proporsional Pokémon (aspek rasio 63 / 88)
    const cardWidth = 240.0;
    const cardHeight = cardWidth * (88.0 / 63.0); // ~335dp

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isUnder = angle > (pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Efek perspektif 3D
              ..rotateY(angle),
            child: isUnder
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildFrontCard(
                      context,
                      cardWidth,
                      cardHeight,
                      priceText,
                      isHigh,
                    ),
                  )
                : _buildBackCard(cardWidth, cardHeight),
          );
        },
      ),
    );
  }

  // Tampilan Belakang Kartu (Klasik Pokémon Card Back)
  Widget _buildBackCard(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF415A77), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [
                Color(0xFF2A6F97),
                Color(0xFF012A4A),
              ],
            ),
            border: Border.all(color: const Color(0xFFFFD166), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.catching_pokemon,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'POKÉMON',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'TAP UNTUK MEMBALIK',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tampilan Depan Kartu Hasil Tarikan
  Widget _buildFrontCard(
    BuildContext context,
    double width,
    double height,
    String priceText,
    bool isHigh,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh ? AppColors.gold : AppColors.surfaceHigh,
          width: isHigh ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isHigh
                ? AppColors.gold.withValues(alpha: 0.45)
                : Colors.black45,
            blurRadius: isHigh ? 16 : 8,
            spreadRadius: isHigh ? 2 : 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gambar Kartu Pokémon (Aspect Ratio 63/88)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 63 / 88,
                  child: widget.card.highResImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: widget.card.highResImageUrl!,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceHigh,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.surfaceHigh,
                            child: const Icon(
                              Icons.broken_image,
                              color: AppColors.outline,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceHigh,
                          child: const Icon(Icons.style, color: AppColors.gold),
                        ),
                ),
              ),
            ),
          ),

          // Bar Info Kartu (Nama, Rarity, Harga)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        widget.card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isHigh)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HOLO / RARE',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.card.rarity ?? 'Common',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      priceText,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
