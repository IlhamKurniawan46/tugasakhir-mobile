import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/listing_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/collection_provider.dart';

enum MarketplaceSort { cheapest, priciest, newest }

class MarketplaceState {
  final List<ListingModel> listings;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String selectedCondition; // 'all', 'mint', 'near_mint', dll.
  final MarketplaceSort sortBy;
  final String? selectedSetId;

  const MarketplaceState({
    this.listings = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCondition = 'all',
    this.sortBy = MarketplaceSort.newest,
    this.selectedSetId,
  });

  MarketplaceState copyWith({
    List<ListingModel>? listings,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? selectedCondition,
    MarketplaceSort? sortBy,
    String? selectedSetId,
  }) =>
      MarketplaceState(
        listings: listings ?? this.listings,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedCondition: selectedCondition ?? this.selectedCondition,
        sortBy: sortBy ?? this.sortBy,
        selectedSetId: selectedSetId ?? this.selectedSetId,
      );

  /// Mengembalikan listing aktif yang sudah disaring berdasarkan filter dan urutan
  List<ListingModel> get filteredListings {
    var result = listings.where((l) => l.isActive).toList();

    // 1. Filter Pencarian Nama Kartu atau Penjual
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      result = result.where((l) {
        final cardName = l.card?.name.toLowerCase() ?? '';
        final sellerName = l.sellerUsername?.toLowerCase() ?? '';
        final desc = l.description?.toLowerCase() ?? '';
        return cardName.contains(query) ||
            sellerName.contains(query) ||
            desc.contains(query);
      }).toList();
    }

    // 2. Filter Kondisi Kartu
    if (selectedCondition != 'all') {
      result = result
          .where((l) =>
              l.condition.toLowerCase() == selectedCondition.toLowerCase())
          .toList();
    }

    // 3. Filter Set
    if (selectedSetId != null && selectedSetId!.isNotEmpty) {
      result = result.where((l) => l.card?.setId == selectedSetId).toList();
    }

    // 4. Pengurutan (Sorting)
    switch (sortBy) {
      case MarketplaceSort.cheapest:
        result.sort((a, b) => a.priceIdr.compareTo(b.priceIdr));
        break;
      case MarketplaceSort.priciest:
        result.sort((a, b) => b.priceIdr.compareTo(a.priceIdr));
        break;
      case MarketplaceSort.newest:
        result.sort((a, b) {
          final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });
        break;
    }

    return result;
  }
}

class MarketplaceNotifier extends StateNotifier<MarketplaceState> {
  final Ref ref;

  MarketplaceNotifier(this.ref) : super(const MarketplaceState()) {
    loadListings();
  }

  /// Memuat daftar listing aktif dari Supabase
  Future<void> loadListings({bool forceRefresh = false}) async {
    if (state.isLoading && !forceRefresh) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final items = await MarketplaceRepository.fetchActiveListings();
      state = state.copyWith(
        listings: items,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat pasar: $e',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCondition(String condition) {
    state = state.copyWith(selectedCondition: condition);
  }

  void setSortBy(MarketplaceSort sort) {
    state = state.copyWith(sortBy: sort);
  }

  void setSetId(String? setId) {
    state = state.copyWith(selectedSetId: setId);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedCondition: 'all',
      sortBy: MarketplaceSort.newest,
      selectedSetId: null,
    );
  }

  /// Membeli listing secara atomik
  Future<bool> buyListing({
    required String listingId,
    required String buyerId,
  }) async {
    try {
      final result = await MarketplaceRepository.buyListing(
        listingId: listingId,
        buyerId: buyerId,
      );

      // 1. Update saldo user di state auth
      if (result['new_balance_idr'] != null) {
        final newBalance =
            (result['new_balance_idr'] as num?)?.toDouble() ?? 0;
        ref.read(authProvider.notifier).updateUserBalance(newBalance);
      }

      // 2. Refresh koleksi user (kartu otomatis masuk ke Koleksi Saya)
      ref.read(collectionProvider.notifier).refresh();

      // 3. Update status listing di lokal menjadi 'sold'
      final updatedList = state.listings.map((l) {
        if (l.id == listingId) {
          return l.copyWith(status: 'sold');
        }
        return l;
      }).toList();

      state = state.copyWith(listings: updatedList);

      // Invalidate transaksi provider agar riwayat terbarui
      ref.invalidate(userTransactionsProvider(buyerId));

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Membatalkan listing milik user
  Future<bool> cancelListing({
    required String listingId,
    required String sellerId,
  }) async {
    try {
      await MarketplaceRepository.cancelListing(
        listingId: listingId,
        sellerId: sellerId,
      );

      // Hapus atau ubah status di lokal
      final updatedList = state.listings.map((l) {
        if (l.id == listingId) {
          return l.copyWith(status: 'cancelled');
        }
        return l;
      }).toList();

      state = state.copyWith(listings: updatedList);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider utama daftar pasar HoloDex
final marketplaceProvider =
    StateNotifierProvider<MarketplaceNotifier, MarketplaceState>(
  (ref) => MarketplaceNotifier(ref),
);

/// Provider riwayat transaksi pengguna (beli & jual)
final userTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, userId) async {
  return MarketplaceRepository.getUserTransactions(userId);
});

/// Provider listing aktif yang sedang dijual oleh user tertentu
final userActiveListingsProvider =
    Provider.family<List<ListingModel>, String>((ref, userId) {
  final allListings = ref.watch(marketplaceProvider).listings;
  return allListings
      .where((l) => l.sellerId == userId && l.isActive)
      .toList();
});
