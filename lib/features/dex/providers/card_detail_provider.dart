import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/database/local_db.dart';
import '../../../core/database/supabase_client.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/collection_service.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/session_service.dart';

class CardDetailState {
  final CardModel? card;
  final bool isLoading;
  final String? errorMessage;
  final bool inCollection;
  final bool inWatchlist;
  final bool isBusy;

  const CardDetailState({
    this.card,
    this.isLoading = false,
    this.errorMessage,
    this.inCollection = false,
    this.inWatchlist = false,
    this.isBusy = false,
  });

  CardDetailState copyWith({
    CardModel? card,
    bool? isLoading,
    String? errorMessage,
    bool? inCollection,
    bool? inWatchlist,
    bool? isBusy,
  }) =>
      CardDetailState(
        card: card ?? this.card,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        inCollection: inCollection ?? this.inCollection,
        inWatchlist: inWatchlist ?? this.inWatchlist,
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

    final results = await Future.wait([
      CollectionService.isInCollection(userId, cardId),
      CollectionService.isInWatchlist(userId, cardId),
    ]);
    if (!mounted) return;
    state = state.copyWith(inCollection: results[0], inWatchlist: results[1]);
  }

  Future<ToggleResult> toggleCollection() => _toggle(
        isOn: state.inCollection,
        add: CollectionService.addToCollection,
        remove: CollectionService.removeFromCollection,
        apply: (value) => state.copyWith(inCollection: value, isBusy: false),
      );

  Future<ToggleResult> toggleWatchlist() => _toggle(
        isOn: state.inWatchlist,
        add: (u, c) => CollectionService.addToWatchlist(u, c),
        remove: CollectionService.removeFromWatchlist,
        apply: (value) => state.copyWith(inWatchlist: value, isBusy: false),
      );

  Future<ToggleResult> _toggle({
    required bool isOn,
    required Future<void> Function(String userId, String cardId) add,
    required Future<void> Function(String userId, String cardId) remove,
    required CardDetailState Function(bool value) apply,
  }) async {
    if (state.isBusy) return ToggleResult.failed;

    final userId = await SessionService.getActiveUserId();
    if (userId == null) return ToggleResult.notLoggedIn;

    state = state.copyWith(isBusy: true);
    try {
      if (isOn) {
        await remove(userId, cardId);
      } else {
        await add(userId, cardId);
      }
      if (!mounted) return ToggleResult.failed;
      state = apply(!isOn);
      return isOn ? ToggleResult.removed : ToggleResult.added;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal ubah koleksi/watchlist: $e');
      if (mounted) state = state.copyWith(isBusy: false);
      return ToggleResult.failed;
    }
  }
}

/// Argumen family: id kartu + model awal (opsional) dari grid
/// agar detail langsung tampil tanpa menunggu query.
class CardDetailArgs {
  final String cardId;
  final CardModel? initialCard;

  const CardDetailArgs(this.cardId, [this.initialCard]);

  // Kesetaraan hanya berdasarkan id supaya provider tidak dibuat ulang
  // saat objek CardModel yang sama dikirim dari tempat berbeda.
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
