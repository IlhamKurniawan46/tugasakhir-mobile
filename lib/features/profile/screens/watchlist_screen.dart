import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/watchlist_item_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../providers/watchlist_provider.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchlistProvider.notifier).loadWatchlist();
    });
  }

  void _showSetTargetDialog(WatchlistItemModel item) {
    final selectedCurrency = ref.read(currencyProvider);
    final controller = TextEditingController();

    if (item.alertPriceIdr != null && item.alertPriceIdr! > 0) {
      final converted = CurrencyService.convert(
        item.alertPriceIdr!,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      if (converted != null) {
        controller.text = selectedCurrency == AppCurrency.idr
            ? converted.round().toString()
            : converted.toStringAsFixed(2);
      }
    }

    final cardName = item.card?.name ?? 'Kartu Pokémon';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: const [
            Icon(Icons.price_change, color: AppColors.gold, size: 22),
            SizedBox(width: 8),
            Text('Atur Target Harga', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tentukan target harga untuk $cardName dalam ${selectedCurrency.code}. '
              'Lencana "Target Tercapai" akan muncul jika harga pasar saat ini berada di bawah atau sama dengan target ini.',
              style: const TextStyle(fontSize: 12, color: AppColors.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '${selectedCurrency.symbol} ',
                labelText: 'Harga Target (${selectedCurrency.code})',
                hintText: selectedCurrency == AppCurrency.idr
                    ? 'Contoh: 150000'
                    : 'Contoh: 12.50',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (item.alertPriceIdr != null)
            TextButton(
              onPressed: () async {
                await ref
                    .read(watchlistProvider.notifier)
                    .updateAlertPrice(item.cardId, null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Hapus Target', style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onGold,
            ),
            onPressed: () async {
              final rawText = controller.text.trim().replaceAll(',', '.');
              final inputAmount = double.tryParse(rawText);
              if (inputAmount != null && inputAmount > 0) {
                final idrAmount = CurrencyService.convert(
                  inputAmount,
                  from: selectedCurrency.code,
                  to: 'IDR',
                );
                await ref
                    .read(watchlistProvider.notifier)
                    .updateAlertPrice(item.cardId, idrAmount);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(WatchlistItemModel item) {
    final cardName = item.card?.name ?? 'kartu ini';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hapus dari Watchlist?'),
        content: Text('Hapus $cardName dari daftar pantauan kamu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceLowest,
            ),
            onPressed: () {
              ref.read(watchlistProvider.notifier).removeItem(item.cardId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$cardName dihapus dari Watchlist.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlistState = ref.watch(watchlistProvider);
    final selectedCurrency = ref.watch(currencyProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Watchlist & Target Harga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: () => ref.read(watchlistProvider.notifier).loadWatchlist(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.read(watchlistProvider.notifier).loadWatchlist(),
        child: watchlistState.isLoading && watchlistState.items.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : watchlistState.errorMessage != null && watchlistState.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(watchlistState.errorMessage!),
                      ],
                    ),
                  )
                : watchlistState.items.isEmpty
                    ? _buildEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: watchlistState.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = watchlistState.items[index];
                          return _buildWatchlistTile(
                            context,
                            item,
                            selectedCurrency,
                            textTheme,
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildWatchlistTile(
    BuildContext context,
    WatchlistItemModel item,
    AppCurrency selectedCurrency,
    TextTheme textTheme,
  ) {
    final card = item.card;
    final cardName = card?.name ?? 'Kartu Pokémon #${item.cardId}';
    final cardSet = card?.setName ?? card?.setId ?? 'Pokémon TCG';
    final currentPriceFormatted = card != null
        ? CardPriceCalculator.formatCardPrice(card, selectedCurrency)
        : '-';

    final targetReached = WatchlistState.isTargetReached(item);

    String? targetPriceFormatted;
    if (item.alertPriceIdr != null && item.alertPriceIdr! > 0) {
      final converted = CurrencyService.convert(
        item.alertPriceIdr!,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      if (converted != null) {
        targetPriceFormatted =
            PriceFormatter.format(converted, selectedCurrency.code);
      }
    }

    return Dismissible(
      key: Key('watchlist_${item.cardId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(watchlistProvider.notifier).removeItem(item.cardId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cardName dihapus dari Watchlist.'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: targetReached
                ? AppColors.success.withValues(alpha: 0.6)
                : AppColors.surfaceHigh,
          ),
        ),
        child: InkWell(
          onTap: () {
            context.push('/dex/card/${card?.id ?? item.cardId}', extra: card);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gambar Kartu Mini
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 52,
                    height: 72,
                    child: card?.lowResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.lowResImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => Container(
                              color: AppColors.surfaceLow,
                            ),
                            errorWidget: (ctx, url, error) => Container(
                              color: AppColors.surfaceLow,
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceLow,
                            child: const Icon(Icons.style, size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info & Target
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cardName,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (targetReached) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check,
                                      size: 11, color: AppColors.success),
                                  SizedBox(width: 2),
                                  Text(
                                    'Target Tercapai',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cardSet,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Sekarang: $currentPriceFormatted',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                          if (targetPriceFormatted != null)
                            Text(
                              'Target: $targetPriceFormatted',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: targetReached
                                    ? AppColors.success
                                    : AppColors.outline,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tombol Menu Aksi Target / Hapus
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.outline),
                  color: AppColors.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'target') {
                      _showSetTargetDialog(item);
                    } else if (value == 'delete') {
                      _confirmDelete(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'target',
                      child: Row(
                        children: [
                          const Icon(Icons.price_change,
                              size: 18, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Text(item.alertPriceIdr != null
                              ? 'Ubah Target Harga'
                              : 'Set Target Harga'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Hapus dari Watchlist',
                              style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceHigh),
          ),
          child: const Icon(
            Icons.favorite_border,
            size: 40,
            color: AppColors.pink,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Watchlist Masih Kosong',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pantau kartu favorit dan pasang harga target. '
          'Tambahkan kartu lewat ikon hati di detail kartu atau via mode pilih di Dex.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 48),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.onGold,
            ),
            icon: const Icon(Icons.search),
            label: const Text(
              'Jelajahi Katalog Dex',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => context.go('/dex'),
          ),
        ),
      ],
    );
  }
}
