import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/services/recommendation_engine.dart';
import '../../../core/utils/price_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dex/providers/recommendation_provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/listing_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketplaceProvider.notifier).loadListings();
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTopUpDialog(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        color: AppColors.gold, size: 24),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Top Up Saldo Vitrual',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tambahkan saldo untuk berbelanja kartu di marketplace.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildTopUpOption(ctx, userId, 250000, '+ Rp250.000'),
                    _buildTopUpOption(ctx, userId, 500000, '+ Rp500.000'),
                    _buildTopUpOption(ctx, userId, 1000000, '+ Rp1.000.000'),
                    _buildTopUpOption(ctx, userId, 2500000, '+ Rp2.500.000'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopUpOption(
    BuildContext context,
    String userId,
    double amount,
    String label,
  ) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        try {
          final newBalance = await MarketplaceRepository.topUpBalance(
            userId: userId,
            amount: amount,
          );
          ref.read(authProvider.notifier).updateUserBalance(newBalance);
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                    'Saldo berhasil ditambah! Saldo saat ini: ${PriceFormatter.formatIdr(newBalance)}'),
                backgroundColor: AppColors.snackBarSuccess,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 2000),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Gagal top up: $e'),
                backgroundColor: AppColors.snackBarError,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 2000),
              ),
            );
          }
        }
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  void _showSortFilterModal(BuildContext context) {
    final state = ref.read(marketplaceProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Urutkan & Saring',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(marketplaceProvider.notifier).resetFilters();
                        _searchController.clear();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset',
                          style: TextStyle(color: AppColors.gold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Urutkan Berdasarkan:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: AppColors.cyan),
                          SizedBox(width: 4),
                          Text('Untuk Kamu (AI)'),
                        ],
                      ),
                      selected: state.sortBy == MarketplaceSort.forYou,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(marketplaceProvider.notifier)
                              .setSortBy(MarketplaceSort.forYou);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Terbaru'),
                      selected: state.sortBy == MarketplaceSort.newest,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(marketplaceProvider.notifier)
                              .setSortBy(MarketplaceSort.newest);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Harga Termurah'),
                      selected: state.sortBy == MarketplaceSort.cheapest,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(marketplaceProvider.notifier)
                              .setSortBy(MarketplaceSort.cheapest);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Harga Termahal'),
                      selected: state.sortBy == MarketplaceSort.priciest,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          ref
                              .read(marketplaceProvider.notifier)
                              .setSortBy(MarketplaceSort.priciest);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceState = ref.watch(marketplaceProvider);
    final authState = ref.watch(authProvider);
    final recState = ref.watch(recommendationProvider);
    final userProfile = recState.profile;

    // Sinkronkan profil minat ke provider pasar untuk pengurutan "Untuk Kamu"
    if (marketplaceState.userProfile != userProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(marketplaceProvider.notifier).setUserProfile(userProfile);
      });
    }

    final user = authState.user;
    final textTheme = Theme.of(context).textTheme;
    final filteredListings = marketplaceState.filteredListings;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storefront, color: AppColors.gold, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pasar HoloDex',
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Riwayat Transaksi',
            onPressed: () => context.push('/marketplace/history'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart, size: 20),
        label: const Text(
          'Jual Kartu',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () => context.push('/marketplace/create'),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(marketplaceProvider.notifier).loadListings(forceRefresh: true);
          await ref.read(authProvider.notifier).refreshProfile();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Banner Saldo & Top Up Virtual
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.surfaceHigh,
                        AppColors.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    spacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Saldo HoloPay (Simulasi)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              PriceFormatter.formatIdr(user?.balanceIdr ?? 0),
                              style: textTheme.titleMedium?.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (user != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.gold.withAlpha(26),
                            foregroundColor: AppColors.gold,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _showTopUpDialog(context, user.id),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Top Up',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar & Filter Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => ref
                            .read(marketplaceProvider.notifier)
                            .setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText: 'Cari kartu Pokémon / penjual...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(marketplaceProvider.notifier)
                                        .setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.surfaceHigh),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.surfaceHigh),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.map_outlined, color: AppColors.gold),
                        tooltip: 'Peta Penjual Terdekat (LBS)',
                        onPressed: () => context.push('/marketplace/map'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.tune, color: AppColors.gold),
                        tooltip: 'Urutkan & Saring',
                        onPressed: () => _showSortFilterModal(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Baris Filter Kondisi Kartu (Horizontal Scroll Anti-Overflow)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildConditionChip('all', 'Semua'),
                    const SizedBox(width: 8),
                    _buildConditionChip('mint', 'Mint (Mulus)'),
                    const SizedBox(width: 8),
                    _buildConditionChip('near_mint', 'Near Mint'),
                    const SizedBox(width: 8),
                    _buildConditionChip('excellent', 'Excellent'),
                    const SizedBox(width: 8),
                    _buildConditionChip('good', 'Good'),
                    const SizedBox(width: 8),
                    _buildConditionChip('poor', 'Poor'),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),

            // Grid Items Listing
            if (marketplaceState.isLoading && marketplaceState.listings.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (filteredListings.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 64,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Kartu Dijual',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          marketplaceState.searchQuery.isNotEmpty ||
                                  marketplaceState.selectedCondition != 'all'
                              ? 'Tidak ada kartu yang cocok dengan saringan saat ini. Coba reset filter.'
                              : 'Jadilah yang pertama memasang listing kartu fisik di Pasar HoloDex!',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (marketplaceState.searchQuery.isNotEmpty ||
                            marketplaceState.selectedCondition != 'all')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              side: const BorderSide(color: AppColors.gold),
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset Saringan'),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(marketplaceProvider.notifier).resetFilters();
                            },
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('Jual Kartu Pertama'),
                            onPressed: () => context.push('/marketplace/create'),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.60,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final listing = filteredListings[index];
                      final isMatch = userProfile != null &&
                          !userProfile.isColdStart &&
                          listing.card != null &&
                          RecommendationEngine.scoreCard(
                                card: listing.card!,
                                profile: userProfile,
                              ).score >=
                              0.25;

                      return ListingCard(
                        listing: listing,
                        isMatchForYou: isMatch,
                        onTap: () {
                          context.push(
                            '/marketplace/listing/${listing.id}',
                            extra: listing,
                          );
                        },
                      );
                    },
                    childCount: filteredListings.length,
                  ),
                ),
              ),

            // Ruang bawah agar tidak tertutup FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 88),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionChip(String conditionKey, String label) {
    final state = ref.watch(marketplaceProvider);
    final isSelected = state.selectedCondition == conditionKey;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.gold,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(marketplaceProvider.notifier).setCondition(conditionKey);
        }
      },
    );
  }
}
