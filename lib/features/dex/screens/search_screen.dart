import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../providers/search_provider.dart';
import '../widgets/card_tile.dart';
import '../widgets/filter_bottom_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final currentQuery = ref.read(searchProvider).query;
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openFilterBottomSheet() {
    final searchState = ref.read(searchProvider);
    FilterBottomSheet.show(
      context,
      currentState: searchState,
      onApply: ({setId, rarity, minPrice, maxPrice}) {
        ref.read(searchProvider.notifier).applyFilters(
              setId: setId,
              rarity: rarity,
              minPrice: minPrice,
              maxPrice: maxPrice,
            );
      },
      onReset: () {
        ref.read(searchProvider.notifier).clearAllFilters();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: 'Cari nama kartu (cth: Charizard, Pikachu)...',
            hintStyle: WidgetStateProperty.all(
              const TextStyle(
                color: AppColors.outline,
                fontSize: 13,
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
              ),
            ),
            leading: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.search, color: AppColors.gold, size: 20),
            ),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: AppColors.onSurfaceVariant,
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchProvider.notifier).setQuery('');
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Badge(
                    isLabelVisible: state.hasActiveFilters,
                    backgroundColor: AppColors.gold,
                    textColor: AppColors.onGold,
                    label: Text(
                      '${state.activeFilterCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 20,
                      color: state.hasActiveFilters
                          ? AppColors.gold
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  onPressed: _openFilterBottomSheet,
                ),
              ),
            ],
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(AppColors.surface),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.surfaceHigh),
              ),
            ),
            constraints: const BoxConstraints(
              minHeight: 44,
              maxHeight: 44,
            ),
            onChanged: (val) {
              ref.read(searchProvider.notifier).setQuery(val);
            },
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Filter Chips Bar
          if (state.hasActiveFilters) _buildActiveFilterChips(state),

          // Result Count Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceHigh, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ditemukan ${state.results.length} kartu',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.hasActiveFilters || state.query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(searchProvider.notifier).resetAll();
                    },
                    child: const Text(
                      'Hapus Semua',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.goldSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(SearchState state) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Set Chip
          if (state.selectedSetId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.style, size: 14, color: AppColors.gold),
                label: Text(
                  'Set: ${_getSetName(state)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.gold),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(searchProvider.notifier).clearSetFilter();
                },
              ),
            ),

          // Rarity Chip
          if (state.selectedRarity != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.star, size: 14, color: AppColors.pink),
                label: Text(
                  'Rarity: ${state.selectedRarity}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.pink),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(searchProvider.notifier).clearRarityFilter();
                },
              ),
            ),

          // Price Chip
          if (state.minPrice != null || state.maxPrice != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.payments, size: 14, color: AppColors.cyan),
                label: Text(
                  _getPriceLabel(state),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.cyan),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  ref.read(searchProvider.notifier).clearPriceFilter();
                },
              ),
            ),
        ],
      ),
    );
  }

  String _getSetName(SearchState state) {
    if (state.selectedSetId == null) return '';
    for (final s in state.availableSets) {
      if (s['id'] == state.selectedSetId) {
        return s['name'] ?? state.selectedSetId!;
      }
    }
    return state.selectedSetId!;
  }

  String _getPriceLabel(SearchState state) {
    if (state.minPrice == null && state.maxPrice != null) {
      return '< Rp ${_formatNumber(state.maxPrice!)}';
    } else if (state.minPrice != null && state.maxPrice == null) {
      return '> Rp ${_formatNumber(state.minPrice!)}';
    } else if (state.minPrice != null && state.maxPrice != null) {
      return 'Rp ${_formatNumber(state.minPrice!)} – ${_formatNumber(state.maxPrice!)}';
    }
    return 'Harga';
  }

  String _formatNumber(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(val % 1000000 == 0 ? 0 : 1)} Jt';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)} Rb';
    }
    return val.toStringAsFixed(0);
  }

  Widget _buildBody(SearchState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (state.results.isEmpty) {
      return _buildEmptyState(state);
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final isLargeText = textScaler.scale(10) > 11.5;
    final cardAspectRatio = isLargeText ? 0.465 : 0.505;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final card = state.results[index];
        return CardTile(
          card: card,
          onTap: () {
            context.push('/dex/card/${card.id}', extra: card);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(SearchState state) {
    final hasCriteria = state.query.isNotEmpty || state.hasActiveFilters;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceHigh, width: 2),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Kartu Tidak Ditemukan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasCriteria
                  ? 'Tidak ada kartu yang cocok dengan kata kunci "${state.query}" atau kombinasi filter saat ini.'
                  : 'Belum ada kartu yang dapat ditampilkan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.outline,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset Pencarian & Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceHighest,
                foregroundColor: AppColors.goldSoft,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.surfaceHigh),
                ),
              ),
              onPressed: () {
                _searchController.clear();
                ref.read(searchProvider.notifier).resetAll();
              },
            ),
          ],
        ),
      ),
    );
  }
}
