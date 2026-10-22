import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/collection_item_model.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/providers/currency_provider.dart';

class CollectionState {
  final List<CollectionItemModel> items;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  const CollectionState({
    this.items = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  CollectionState copyWith({
    List<CollectionItemModel>? items,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
  }) =>
      CollectionState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        errorMessage: errorMessage,
      );

  /// Jumlah kartu yang memiliki harga acuan USD
  int get pricedCount =>
      items.where((i) => i.card?.priceRefUsd != null && i.card!.priceRefUsd! > 0).length;

  /// Jumlah kartu tanpa data harga pasar
  int get unpricedCount => items.length - pricedCount;

  /// Total nilai referensi dalam USD
  double get totalRefUsd {
    double total = 0.0;
    for (final item in items) {
      final price = item.card?.priceRefUsd;
      if (price != null && price > 0) {
        total += price;
      }
    }
    return total;
  }

  /// Total nilai terkonversi ke mata uang target (IDR, USD, EUR)
  double? getTotalInCurrency(AppCurrency targetCurrency) {
    if (items.isEmpty) return 0.0;
    final totalUsd = totalRefUsd;
    if (totalUsd <= 0 && pricedCount == 0) return 0.0;

    return CurrencyService.convert(
      totalUsd,
      from: 'USD',
      to: targetCurrency.code,
    );
  }
}

class CollectionNotifier extends StateNotifier<CollectionState> {
  CollectionNotifier() : super(const CollectionState(isLoading: true)) {
    loadCollection();
  }

  Future<void> loadCollection({bool forceRefresh = false}) async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null) {
      state = const CollectionState(
        items: [],
        isLoading: false,
        errorMessage: 'Silakan login untuk melihat Koleksi Saya.',
      );
      return;
    }

    if (forceRefresh) {
      state = state.copyWith(isRefreshing: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoading: state.items.isEmpty, errorMessage: null);
    }

    try {
      final items = await CollectionRepository.getCollectionCards(
        userId,
        forceRefresh: forceRefresh,
      );
      state = state.copyWith(
        items: items,
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Gagal memuat Koleksi Saya: $e',
      );
    }
  }

  void clear() {
    state = const CollectionState();
  }
}

final collectionProvider =
    StateNotifierProvider<CollectionNotifier, CollectionState>((ref) {
  return CollectionNotifier();
});
