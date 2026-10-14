import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../providers/dex_provider.dart';
import '../widgets/card_tile.dart';

class DexScreen extends ConsumerStatefulWidget {
  const DexScreen({super.key});

  @override
  ConsumerState<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends ConsumerState<DexScreen> {
  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final dexState = ref.watch(dexProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.diamond, color: AppColors.gold, size: 24),
            const SizedBox(width: 8),
            Text(
              'HoloDex',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          // Tombol Toggle Sort: Termahal <-> Termurah
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                dexState.sortOrder == SortOrder.expensiveFirst
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 14,
                color: AppColors.gold,
              ),
              label: Text(
                dexState.sortOrder == SortOrder.expensiveFirst
                    ? 'Termahal'
                    : 'Termurah',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldSoft,
                ),
              ),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.surfaceHigh),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () {
                ref.read(dexProvider.notifier).toggleSortOrder();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Offline (jika Supabase gagal dijangkau)
          if (dexState.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceHighest,
              child: Row(
                children: const [
                  Icon(Icons.wifi_off, size: 16, color: AppColors.gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Offline — Menampilkan katalog dari cache lokal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Konten Grid Kartu
          Expanded(
            child: _buildBody(dexState),
          ),
        ],
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
          return CardTile(
            card: card,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${card.name} (${card.rarity ?? 'Regular'})'),
                  duration: const Duration(seconds: 1),
                ),
              );
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
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  color: AppColors.surfaceHigh,
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 80,
                  color: AppColors.surfaceHigh,
                ),
                const SizedBox(height: 10),
                Container(
                  height: 16,
                  width: 90,
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
