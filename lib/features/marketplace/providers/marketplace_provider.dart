import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/card_certificate_model.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/blockchain_repository.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/services/recommendation_engine.dart';
import '../../../core/services/web3_blockchain_service.dart';
import '../../../core/utils/env_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/collection_provider.dart';

enum MarketplaceSort { cheapest, priciest, newest, forYou }

class MarketplaceState {
  final List<ListingModel> listings;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String selectedCondition; // 'all', 'mint', 'near_mint', dll.
  final MarketplaceSort sortBy;
  final String? selectedSetId;
  final UserInterestProfile? userProfile;

  const MarketplaceState({
    this.listings = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.selectedCondition = 'all',
    this.sortBy = MarketplaceSort.newest,
    this.selectedSetId,
    this.userProfile,
  });

  MarketplaceState copyWith({
    List<ListingModel>? listings,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? selectedCondition,
    MarketplaceSort? sortBy,
    String? selectedSetId,
    UserInterestProfile? userProfile,
  }) =>
      MarketplaceState(
        listings: listings ?? this.listings,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedCondition: selectedCondition ?? this.selectedCondition,
        sortBy: sortBy ?? this.sortBy,
        selectedSetId: selectedSetId ?? this.selectedSetId,
        userProfile: userProfile ?? this.userProfile,
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
      case MarketplaceSort.forYou:
        if (userProfile != null && !userProfile!.isColdStart) {
          result.sort((a, b) {
            final double scoreA = a.card != null
                ? RecommendationEngine.scoreCard(
                    card: a.card!,
                    profile: userProfile!,
                  ).score
                : 0.0;
            final double scoreB = b.card != null
                ? RecommendationEngine.scoreCard(
                    card: b.card!,
                    profile: userProfile!,
                  ).score
                : 0.0;
            return scoreB.compareTo(scoreA);
          });
        } else {
          result.sort((a, b) {
            final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return timeB.compareTo(timeA);
          });
        }
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

  void setUserProfile(UserInterestProfile? profile) {
    if (state.userProfile != profile) {
      state = state.copyWith(userProfile: profile);
    }
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

  /// Membeli listing secara atomik & memicu pencatatan sertifikat on-chain di Polygon Amoy
  Future<Map<String, dynamic>> buyListing({
    required String listingId,
    required String buyerId,
    String? cardName,
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

      // 4. Proses Sertifikat Keaslian On-Chain di Polygon Amoy
      final cardId = result['card_id'] as String? ?? '';
      final priceIdr = (result['price_idr'] as num?)?.toDouble() ?? 0;
      final txId = result['transaction_id']?.toString() ?? '';

      String? onChainTxHash;
      final tokenId = DateTime.now().millisecondsSinceEpoch.remainder(1000000).toString();
      final user = ref.read(authProvider).user;

      try {
        // Panggil minting on-chain via Web3 service
        onChainTxHash = await Web3BlockchainService.instance.mintCertificate(
          cardId: cardId,
          cardName: cardName ?? 'Pokémon Card',
        );
      } catch (e) {
        debugPrint('[HoloDex Web3] Minting on-chain dilewati/tertunda: $e');
      }

      // Simpan riwayat provenance sertifikat kartu jika ada transaksi
      if (cardId.isNotEmpty && onChainTxHash != null && onChainTxHash.isNotEmpty) {
        final cert = CardCertificateModel(
          id: txId.isNotEmpty ? txId : 'cert-${DateTime.now().millisecondsSinceEpoch}',
          cardId: cardId,
          tokenId: tokenId,
          contractAddress: EnvLoader.blockchainContractAddress.isNotEmpty
              ? EnvLoader.blockchainContractAddress
              : '0xAmoyHoloDexProvenance',
          txHash: onChainTxHash,
          fromAddress: '0x0000000000000000000000000000000000000000',
          toAddress: Web3BlockchainService.instance.operatorAddress != null
              ? '0x${Web3BlockchainService.instance.operatorAddress}'
              : '0x${buyerId.replaceAll('-', '').padRight(40, '0').substring(0, 40)}',
          ownerUsername: user?.username ?? 'Buyer',
          action: 'transferred',
          priceIdr: priceIdr,
          notes: 'Marketplace Purchase #$listingId',
          createdAt: DateTime.now(),
        );

        await BlockchainRepository.saveCertificateRecord(cert);
      }

      return {
        ...result,
        'tx_hash': onChainTxHash,
        'token_id': tokenId,
      };
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
