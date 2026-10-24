import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/watchlist_item_model.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/providers/currency_provider.dart';
import '../../auth/providers/auth_provider.dart';

class WatchlistState {
  final List<WatchlistItemModel> items;
  final bool isLoading;
  final String? errorMessage;

  const WatchlistState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  WatchlistState copyWith({
    List<WatchlistItemModel>? items,
    bool? isLoading,
    String? errorMessage,
  }) =>
      WatchlistState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );

  /// Cek apakah target harga tercapai untuk kartu tertentu.
  /// Membandingkan harga pasar saat ini dalam IDR dengan `alertPriceIdr`.
  static bool isTargetReached(WatchlistItemModel item) {
    if (item.alertPriceIdr == null || item.alertPriceIdr! <= 0) return false;
    final card = item.card;
    if (card == null) return false;

    // Ambil harga kartu dalam IDR (menggunakan CardPriceCalculator)
    final currentPriceIdr =
        CardPriceCalculator.getConvertedPrice(card, AppCurrency.idr);
    if (currentPriceIdr == null || currentPriceIdr <= 0) return false;

    return currentPriceIdr <= item.alertPriceIdr!;
  }
}

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  final Ref? ref;

  WatchlistNotifier([this.ref]) : super(const WatchlistState(isLoading: true)) {
    ref?.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.user?.id != next.user?.id) {
        state = const WatchlistState(isLoading: true);
        loadWatchlist();
      }
    });
    loadWatchlist();
  }

  Future<void> loadWatchlist() async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null) {
      state = const WatchlistState(
        items: [],
        isLoading: false,
        errorMessage: 'Silakan login untuk melihat Watchlist.',
      );
      return;
    }

    state = state.copyWith(isLoading: state.items.isEmpty, errorMessage: null);

    try {
      final items = await CollectionRepository.getWatchlist(userId);
      state = state.copyWith(
        items: items,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat Watchlist: $e',
      );
    }
  }

  Future<bool> removeItem(String cardId) async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null) return false;

    try {
      await CollectionRepository.removeFromWatchlist(userId, cardId);
      state = state.copyWith(
        items: state.items.where((i) => i.cardId != cardId).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAlertPrice(String cardId, double? alertPriceIdr) async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null) return false;

    try {
      await CollectionRepository.updateAlertPrice(userId, cardId, alertPriceIdr);
      state = state.copyWith(
        items: state.items.map((i) {
          if (i.cardId == cardId) {
            return i.copyWith(alertPriceIdr: alertPriceIdr);
          }
          return i;
        }).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  void clear() {
    state = const WatchlistState();
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  return WatchlistNotifier(ref);
});
