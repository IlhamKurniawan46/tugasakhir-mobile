import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../providers/collection_provider.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  DateTime _lastCardTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _openCardDetail(CardModel? card, String fallbackCardId) {
    final now = DateTime.now();
    if (now.difference(_lastCardTap).inMilliseconds < 600) return;
    _lastCardTap = now;
    context.push('/dex/card/${card?.id ?? fallbackCardId}', extra: card);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(collectionProvider.notifier).loadCollection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionState = ref.watch(collectionProvider);
    final selectedCurrency = ref.watch(currencyProvider);
    final currencyRates = ref.watch(currencyRatesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Koleksi Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sinkronkan Koleksi',
            onPressed: collectionState.isRefreshing
                ? null
                : () => ref.read(collectionProvider.notifier).loadCollection(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () =>
            ref.read(collectionProvider.notifier).loadCollection(forceRefresh: true),
        child: collectionState.isLoading && collectionState.items.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : collectionState.errorMessage != null && collectionState.items.isEmpty
                ? _buildErrorView(collectionState.errorMessage!)
                : collectionState.items.isEmpty
                    ? _buildEmptyView()
                    : CustomScrollView(
                        slivers: [
                          // 1. Header Portofolio / Total Nilai Koleksi
                          SliverToBoxAdapter(
                            child: _buildPortfolioSummary(
                              context,
                              collectionState,
                              selectedCurrency,
                              currencyRates,
                            ),
                          ),

                          // 2. Subheader Daftar Kartu
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'DAFTAR KARTU FISIK (${collectionState.items.length})',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: AppColors.outline,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceHigh,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Baca-Saja',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 3. Grid Kartu Koleksi (2 Kolom)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.58,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = collectionState.items[index];
                                  return _buildCollectionCardTile(
                                    context,
                                    item.card,
                                    item.cardId,
                                    item.acquiredVia,
                                    selectedCurrency,
                                  );
                                },
                                childCount: collectionState.items.length,
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildPortfolioSummary(
    BuildContext context,
    CollectionState state,
    AppCurrency selectedCurrency,
    CurrencyRatesState ratesState,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final totalAmount = state.getTotalInCurrency(selectedCurrency);

    final String valueText;
    if (ratesState.isLoading && totalAmount == null) {
      valueText = 'Memuat kurs...';
    } else if (totalAmount != null) {
      valueText = PriceFormatter.format(totalAmount, selectedCurrency.code);
    } else {
      valueText = 'Kurs tidak tersedia';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              const Icon(Icons.collections_bookmark, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Estimasi Nilai Koleksi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.items.length} Kartu Fisik',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Dihitung dari harga pasar TCG live',
                style: textTheme.bodySmall?.copyWith(color: AppColors.outline),
              ),
              if (state.unpricedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${state.unpricedCount} kartu tanpa data harga',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCardTile(
    BuildContext context,
    CardModel? card,
    String fallbackCardId,
    String acquiredVia,
    AppCurrency selectedCurrency,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final cardName = card?.name ?? 'Kartu Pokémon #$fallbackCardId';
    final cardSet = card?.setName ?? card?.setId ?? 'Pokémon TCG';
    final formattedPrice = card != null
        ? CardPriceCalculator.formatCardPrice(card, selectedCurrency)
        : '-';

    return InkWell(
      onTap: () => _openCardDetail(card, fallbackCardId),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.surfaceHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gambar Kartu (Rasio 63:88)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 63 / 88,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (card?.lowResImageUrl != null)
                            CachedNetworkImage(
                              imageUrl: card!.lowResImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(
                                color: AppColors.surfaceLow,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (ctx, url, err) => Container(
                                color: AppColors.surfaceLow,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.outline,
                                  size: 32,
                                ),
                              ),
                            )
                          else
                            Container(
                              color: AppColors.surfaceLow,
                              child: const Icon(
                                Icons.style_outlined,
                                color: AppColors.outline,
                                size: 36,
                              ),
                            ),
                          // Badge status perolehan
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLowest.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.cyan.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 10, color: AppColors.cyan),
                                  SizedBox(width: 3),
                                  Text(
                                    'Pasar',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cyan,
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
              ),
            ),

            // Metadata Kartu
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            Icons.collections_bookmark_outlined,
            size: 40,
            color: AppColors.outline,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Koleksi Masih Kosong',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kartu masuk ke sini setelah kamu membelinya di Pasar. '
          'Pengguna tidak bisa menambah kartu fisik secara manual.',
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
            icon: const Icon(Icons.storefront),
            label: const Text(
              'Jelajahi Pasar (Marketplace)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => context.go('/marketplace'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              side: const BorderSide(color: AppColors.surfaceHigh),
            ),
            icon: const Icon(Icons.search, color: AppColors.goldSoft),
            label: const Text(
              'Buka Katalog Dex',
              style: TextStyle(color: AppColors.goldSoft),
            ),
            onPressed: () => context.go('/dex'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.cloud_off, size: 56, color: AppColors.error),
        const SizedBox(height: 16),
        const Text(
          'Gagal Memuat Koleksi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.outline),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            onPressed: () =>
                ref.read(collectionProvider.notifier).loadCollection(forceRefresh: true),
          ),
        ),
      ],
    );
  }
}
