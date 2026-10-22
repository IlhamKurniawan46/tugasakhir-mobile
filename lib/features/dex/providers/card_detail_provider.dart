import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/database/local_db.dart';
import '../../../core/database/supabase_client.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/session_service.dart';

class CardDetailState {
  final CardModel? card;
  final bool isLoading;
  final String? errorMessage;
  final bool inCollection;
  final bool inWatchlist;
  final double? alertPriceIdr;
  final bool isBusy;

  const CardDetailState({
    this.card,
    this.isLoading = false,
    this.errorMessage,
    this.inCollection = false,
    this.inWatchlist = false,
    this.alertPriceIdr,
    this.isBusy = false,
  });

  CardDetailState copyWith({
    CardModel? card,
    bool? isLoading,
    String? errorMessage,
    bool? inCollection,
    bool? inWatchlist,
    double? alertPriceIdr,
    bool? isBusy,
  }) =>
      CardDetailState(
        card: card ?? this.card,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        inCollection: inCollection ?? this.inCollection,
        inWatchlist: inWatchlist ?? this.inWatchlist,
        alertPriceIdr: alertPriceIdr ?? this.alertPriceIdr,
        isBusy: isBusy ?? this.isBusy,
      );
}

/// Hasil aksi toggle, dipakai layar untuk menampilkan SnackBar.
enum ToggleResult { added, removed, notLoggedIn, failed }

class CardDetailNotifier extends StateNotifier<CardDetailState> {
  final String cardId;

  CardDetailNotifier(this.cardId, CardModel? initialCard)
      : super(CardDetailState(card: initialCard, isLoading: initialCard == null)) {
    _init();
  }

  Future<void> _init() async {
    await CurrencyService.initRates();

    if (state.card == null) {
      final card = await _loadCard();
      if (!mounted) return;
      if (card == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Kartu tidak ditemukan.',
        );
        return;
      }
      state = state.copyWith(card: card, isLoading: false);
    }

    await _loadFlags();
  }

  /// SQLite dulu (cepat & offline), Supabase sebagai cadangan.
  Future<CardModel?> _loadCard() async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'cards',
        where: 'id = ?',
        whereArgs: [cardId],
        limit: 1,
      );
      if (rows.isNotEmpty) return CardModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal baca kartu $cardId dari SQLite: $e');
    }

    try {
      if (SupabaseService.isInitialized) {
        final row = await SupabaseService.client
            .from('cards')
            .select()
            .eq('id', cardId)
            .maybeSingle();
        if (row != null) return CardModel.fromJson(row);
      }
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal ambil kartu $cardId dari Supabase: $e');
    }
    return null;
  }

  Future<void> _loadFlags() async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null || !mounted) return;

    final inCollection =
        await CollectionRepository.isCardInCollection(userId, cardId);
    final inWatchlist = await CollectionRepository.isInWatchlist(userId, cardId);

    double? alertPrice;
    if (inWatchlist) {
      final db = await LocalDb.instance;
      final rows = await db.query(
        'watchlist',
        columns: ['alert_price_idr'],
        where: 'user_id = ? AND card_id = ?',
        whereArgs: [userId, cardId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        alertPrice = (rows.first['alert_price_idr'] as num?)?.toDouble();
      }
    }

    if (!mounted) return;
    state = state.copyWith(
      inCollection: inCollection,
      inWatchlist: inWatchlist,
      alertPriceIdr: alertPrice,
    );
  }

  Future<ToggleResult> toggleWatchlist({double? alertPriceIdr}) async {
    if (state.isBusy) return ToggleResult.failed;

    final userId = await SessionService.getActiveUserId();
    if (userId == null) return ToggleResult.notLoggedIn;

    state = state.copyWith(isBusy: true);
    try {
      if (state.inWatchlist) {
        await CollectionRepository.removeFromWatchlist(userId, cardId);
        if (!mounted) return ToggleResult.failed;
        state = state.copyWith(inWatchlist: false, alertPriceIdr: null, isBusy: false);
        return ToggleResult.removed;
      } else {
        await CollectionRepository.addToWatchlist(
          userId,
          cardId,
          alertPriceIdr: alertPriceIdr,
        );
        if (!mounted) return ToggleResult.failed;
        state = state.copyWith(
          inWatchlist: true,
          alertPriceIdr: alertPriceIdr,
          isBusy: false,
        );
        return ToggleResult.added;
      }
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal ubah watchlist: $e');
      if (mounted) state = state.copyWith(isBusy: false);
      return ToggleResult.failed;
    }
  }

  Future<bool> setWatchlistAlertPrice(double? alertPriceIdr) async {
    final userId = await SessionService.getActiveUserId();
    if (userId == null) return false;

    try {
      await CollectionRepository.updateAlertPrice(userId, cardId, alertPriceIdr);
      if (mounted) {
        state = state.copyWith(alertPriceIdr: alertPriceIdr);
      }
      return true;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal set alert price: $e');
      return false;
    }
  }
}

/// Argumen family: id kartu + model awal (opsional) dari grid
class CardDetailArgs {
  final String cardId;
  final CardModel? initialCard;

  const CardDetailArgs(this.cardId, [this.initialCard]);

  @override
  bool operator ==(Object other) =>
      other is CardDetailArgs && other.cardId == cardId;

  @override
  int get hashCode => cardId.hashCode;
}

final cardDetailProvider = StateNotifierProvider.autoDispose
    .family<CardDetailNotifier, CardDetailState, CardDetailArgs>(
  (ref, args) => CardDetailNotifier(args.cardId, args.initialCard),
);
