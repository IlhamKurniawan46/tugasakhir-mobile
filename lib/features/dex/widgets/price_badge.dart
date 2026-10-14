import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/utils/price_formatter.dart';

/// Badge penunjuk harga dalam Rupiah dengan aksen emas (gold) HoloDex.
class PriceBadge extends StatelessWidget {
  final double priceIdr;
  final bool compact;

  const PriceBadge({
    super.key,
    required this.priceIdr,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
            formatIdr(priceIdr),
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
