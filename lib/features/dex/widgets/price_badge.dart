import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';

/// Badge penunjuk harga dinamis sesuai preferensi mata uang (IDR/USD/EUR) HoloDex.
class PriceBadge extends ConsumerWidget {
  final CardModel? card;
  final double? price;
  final String? currency;
  final double? priceIdr;
  final bool compact;

  const PriceBadge({
    super.key,
    this.card,
    this.price,
    this.currency,
    this.priceIdr,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCurrency = ref.watch(currencyProvider);
    // Ikuti juga perubahan nilai kurs live jika terjadi pembaruan
    ref.watch(currencyRatesProvider);
    final textTheme = Theme.of(context).textTheme;

    String displayText;
    if (card != null) {
      displayText = CardPriceCalculator.formatCardPrice(card!, selectedCurrency);
    } else if (price != null) {
      displayText = PriceFormatter.format(price, currency ?? selectedCurrency.code);
    } else if (priceIdr != null) {
      displayText = formatIdr(priceIdr);
    } else {
      displayText = '-';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sell_outlined,
            size: 11,
            color: AppColors.gold,
          ),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
