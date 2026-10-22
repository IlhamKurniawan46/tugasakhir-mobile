import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../../profile/providers/watchlist_provider.dart';
import '../providers/dex_provider.dart';
import '../widgets/card_tile.dart';

class DexScreen extends ConsumerStatefulWidget {
  const DexScreen({super.key});

  @override
  ConsumerState<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends ConsumerState<DexScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedCardIds = {};

  bool get _isSelectionMode => _selectedCardIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(dexProvider.notifier).loadMore();
    }
  }

  void _toggleCardSelection(String cardId) {
    setState(() {
      if (_selectedCardIds.contains(cardId)) {
        _selectedCardIds.remove(cardId);
      } else {
        _selectedCardIds.add(cardId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedCardIds.clear();
    });
  }

  Future<void> _addSelectedToWatchlist() async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu.'),
          backgroundColor: AppColors.surfaceHighest,
        ),
      );
      return;
    }

    final totalSelected = _selectedCardIds.length;
    final addedCount = await CollectionRepository.addMultipleToWatchlist(
      userId,
      _selectedCardIds.toList(),
    );
    final alreadyCount = totalSelected - addedCount;

    // Refresh provider watchlist agar sinkron
    ref.read(watchlistProvider.notifier).loadWatchlist();

    if (!mounted) return;
    _exitSelectionMode();

    final message = addedCount > 0
        ? '$addedCount kartu ditambahkan ke Watchlist${alreadyCount > 0 ? ' ($alreadyCount sudah ada)' : ''}'
        : 'Semua kartu yang dipilih sudah ada di Watchlist';

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.pink, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.surfaceHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showTotalPriceBottomSheet(BuildContext context) {
    final dexCards = ref.read(dexProvider).cards;
    final selectedCards =
        dexCards.where((c) => _selectedCardIds.contains(c.id)).toList();
    final selectedCurrency = ref.read(currencyProvider);

    double totalRefUsd = 0.0;
    int pricedCount = 0;
    for (final card in selectedCards) {
      if (card.priceRefUsd != null && card.priceRefUsd! > 0) {
        totalRefUsd += card.priceRefUsd!;
        pricedCount++;
      }
    }
    final unpricedCount = selectedCards.length - pricedCount;

    final totalConverted = CurrencyService.convert(
      totalRefUsd,
      from: 'USD',
      to: selectedCurrency.code,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate, color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Total Harga (${selectedCards.length} Kartu)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Card Portofolio Kalkulasi Total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi Total Harga Pilihan:',
                        style: TextStyle(fontSize: 12, color: AppColors.outline),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalConverted != null
                            ? PriceFormatter.format(
                                totalConverted, selectedCurrency.code)
                            : 'Kurs belum siap',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                      if (unpricedCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '$unpricedCount kartu tanpa data harga pasar tidak dihitung.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // List kartu terpilih ringkas
                const Text(
                  'Kartu Terpilih:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: selectedCards.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: AppColors.surfaceHigh,
                    ),
                    itemBuilder: (context, idx) {
                      final card = selectedCards[idx];
                      final priceText = CardPriceCalculator.formatCardPrice(
                          card, selectedCurrency);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          card.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          card.setName ?? 'Pokémon TCG',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.outline,
                          ),
                        ),
                        trailing: Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.onGold,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortFilterBottomSheet(BuildContext context) {
    final currentOrder = ref.read(dexProvider).sortOrder;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Sheet
                Row(
                  children: [
                    const Icon(Icons.sort, color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Pengurutan & Filter Katalog',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.outline),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih urutan tampilan kartu di katalog Dex:',
                  style: TextStyle(fontSize: 12, color: AppColors.outline),
                ),
                const SizedBox(height: 16),

                // Pilihan Sort: Termahal, Termurah, Nama
                ...SortOrder.values.map((order) {
                  final isSelected = currentOrder == order;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold.withValues(alpha: 0.12)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Icon(
                          order == SortOrder.expensiveFirst
                              ? Icons.trending_up
                              : (order == SortOrder.cheapestFirst
                                  ? Icons.trending_down
                                  : Icons.sort_by_alpha),
                          color: isSelected ? AppColors.gold : AppColors.outline,
                          size: 22,
                        ),
                        title: Text(
                          order.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.gold : AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          order.description,
                          style: const TextStyle(fontSize: 11, color: AppColors.outline),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.gold, size: 20)
                            : const Icon(Icons.radio_button_unchecked,
                                color: AppColors.surfaceHighest, size: 20),
                        onTap: () {
                          ref.read(dexProvider.notifier).setSortOrder(order);
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Tombol Buka Filter Lanjutan di Search
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceHigh),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.tune, color: AppColors.gold, size: 18),
                    label: const Text(
                      'Buka Filter Lanjutan (Set, Rarity, Harga)',
                      style: TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/dex/search');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dexState = ref.watch(dexProvider);
    final selectedCurrency = ref.watch(currencyProvider);
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: _isSelectionMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Batal Pilih',
                  onPressed: _exitSelectionMode,
                ),
                title: Text(
                  '${_selectedCardIds.length} dipilih',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: AppColors.pink),
                    tooltip: 'Tambah ke Watchlist',
                    onPressed: _addSelectedToWatchlist,
                  ),
                  IconButton(
                    icon: const Icon(Icons.calculate_outlined, color: AppColors.gold),
                    tooltip: 'Total Harga',
                    onPressed: () => _showTotalPriceBottomSheet(context),
                  ),
                ],
              )
            : AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: AppColors.gold, size: 24),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'HoloDex',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // SATU aksi utama: Ikon Kalender Event
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: AppColors.gold),
                    tooltip: 'Kalender Event',
                    onPressed: () => context.push('/calendar'),
                  ),
                ],
              ),
        body: Column(
          children: [
            // Bar Pencarian & Filter Cepat
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/dex/search'),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.search,
                                  color: AppColors.outline, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cari nama kartu, set, atau kelangkaan...',
                                  style: TextStyle(
                                    color: AppColors.outline,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tombol Tune Filter / Pengurutan
                    InkWell(
                      onTap: () => _showSortFilterBottomSheet(context),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 16,
                              width: 1,
                              color: AppColors.surfaceHigh,
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.tune,
                                color: AppColors.gold, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Selector Mata Uang Global (IDR | USD | EUR) & Tombol Konverter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: AppCurrency.values.map((currency) {
                        final isSelected = selectedCurrency == currency;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(currency.code),
                            selected: isSelected,
                            showCheckmark: false,
                            onSelected: (_) {
                              ref
                                  .read(currencyProvider.notifier)
                                  .setCurrency(currency);
                            },
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.onGold
                                  : AppColors.onSurfaceVariant,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.surfaceHigh,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    InkWell(
                      onTap: () => context.push('/converter'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceHigh),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.currency_exchange,
                                size: 13, color: AppColors.gold),
                            SizedBox(width: 5),
                            Text(
                              'Konverter',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
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

            // Mode Pilih Petunjuk Kecil (hanya muncul saat mode pilih aktif)
            if (_isSelectionMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: AppColors.gold.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ketuk kartu untuk memilih/batal. Pilih ikon Watchlist atau Total Harga di atas.',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.goldSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Daftar Grid Kartu
            Expanded(child: _buildBody(dexState)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(DexState state) {
    // 1. Shimmer Skeleton Loading di awal
    if (state.isLoading && state.cards.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.63,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => _buildShimmerTile(),
      );
    }

    // 2. Error View
    if (state.errorMessage != null && state.cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: AppColors.outline,
              ),
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(dexProvider.notifier).fetchCards(refresh: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Grid Kartu dengan Infinite Scroll & Pull-to-Refresh
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () => ref.read(dexProvider.notifier).fetchCards(refresh: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.63,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: state.cards.length + (state.isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= state.cards.length) {
            return _buildShimmerTile();
          }

          final card = state.cards[index];
          final isSelected = _selectedCardIds.contains(card.id);

          return CardTile(
            card: card,
            isSelected: isSelected,
            isSelectionMode: _isSelectionMode,
            onLongPress: () {
              _toggleCardSelection(card.id);
            },
            onTap: () {
              if (_isSelectionMode) {
                _toggleCardSelection(card.id);
              } else {
                context.push('/dex/card/${card.id}', extra: card);
              }
            },
          );
        },
      ),
    );
  }

  /// Placeholder kotak loading dengan shimmer visual
  Widget _buildShimmerTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 80,
                  color: AppColors.surfaceHigh,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 50,
                  color: AppColors.surfaceHigh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
