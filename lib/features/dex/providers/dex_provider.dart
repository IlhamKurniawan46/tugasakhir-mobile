import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_db.dart';
import '../../../core/database/supabase_client.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/notification_service.dart';

enum SortOrder {
  expensiveFirst('Termahal', 'Harga tertinggi ke terendah'),
  cheapestFirst('Termurah', 'Harga terendah ke tertinggi'),
  nameAsc('Nama (A-Z)', 'Urutkan alfabetis nama kartu');

  final String label;
  final String description;
  const SortOrder(this.label, this.description);
}

class DexState {
  final List<CardModel> cards;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isOffline;
  final String? errorMessage;
  final SortOrder sortOrder;
  final int page;
  final bool hasMore;

  const DexState({
    this.cards = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isOffline = false,
    this.errorMessage,
    this.sortOrder = SortOrder.expensiveFirst,
    this.page = 0,
    this.hasMore = true,
  });

  DexState copyWith({
    List<CardModel>? cards,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isOffline,
    String? errorMessage,
    SortOrder? sortOrder,
    int? page,
    bool? hasMore,
  }) =>
      DexState(
        cards: cards ?? this.cards,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isOffline: isOffline ?? this.isOffline,
        errorMessage: errorMessage,
        sortOrder: sortOrder ?? this.sortOrder,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
      );
}

class DexNotifier extends StateNotifier<DexState> {
  static const int pageSize = 30;

  DexNotifier() : super(const DexState()) {
    fetchCards(refresh: true);
  }

  /// Mengambil daftar kartu dari Supabase dengan fallback ke SQLite lokal jika offline.
  Future<void> fetchCards({bool refresh = false}) async {
    if (state.isLoading) return;

    final targetPage = refresh ? 0 : state.page;
    final isFirstLoad = targetPage == 0;

    state = state.copyWith(
      isLoading: isFirstLoad,
      isLoadingMore: !isFirstLoad,
      errorMessage: null,
    );

    // Inisialisasi kurs jika belum
    await CurrencyService.initRates();

    final offset = targetPage * pageSize;

    try {
      // 1. Coba ambil dari Supabase
      if (SupabaseService.isInitialized) {
        final client = SupabaseService.client;
        final filterQuery = client.from('cards').select().eq('has_price', true);

        final orderQuery = switch (state.sortOrder) {
          SortOrder.nameAsc => filterQuery.order('name', ascending: true),
          SortOrder.cheapestFirst =>
            filterQuery.order('price_ref_usd', ascending: true),
          SortOrder.expensiveFirst =>
            filterQuery.order('price_ref_usd', ascending: false),
        };

        final response = await orderQuery.range(offset, offset + pageSize - 1);

        final List<CardModel> fetchedCards = (response as List)
            .map((item) => CardModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        // Simpan cache ke SQLite lokal di background
        _cacheCardsToLocal(fetchedCards);

        final updatedList = refresh
            ? fetchedCards
            : [...state.cards, ...fetchedCards];

        state = state.copyWith(
          cards: updatedList,
          isLoading: false,
          isLoadingMore: false,
          isOffline: false,
          page: targetPage + 1,
          hasMore: fetchedCards.length >= pageSize,
        );

        // Periksa alert target harga kartu favorit di watchlist (Sesi 14)
        if (targetPage == 0) {
          NotificationService.instance.checkWatchlistPriceAlerts(
            catalogCards: updatedList,
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('[HoloDex Warning] Gagal fetch dari Supabase, beralih ke cache lokal: $e');
    }

    // 2. Fallback: Ambil dari SQLite Cache
    try {
      final db = await LocalDb.instance;
      final String orderBy;
      switch (state.sortOrder) {
        case SortOrder.nameAsc:
          orderBy = 'name ASC';
          break;
        case SortOrder.cheapestFirst:
          orderBy = 'price_ref_usd ASC';
          break;
        case SortOrder.expensiveFirst:
          orderBy = 'price_ref_usd DESC';
          break;
      }

      final rows = await db.query(
        'cards',
        where: 'has_price = 1',
        orderBy: orderBy,
        limit: pageSize,
        offset: offset,
      );

      final List<CardModel> cachedCards =
          rows.map((r) => CardModel.fromMap(r)).toList();

      final updatedList = refresh
          ? cachedCards
          : [...state.cards, ...cachedCards];

      state = state.copyWith(
        cards: updatedList,
        isLoading: false,
        isLoadingMore: false,
        isOffline: true,
        page: targetPage + 1,
        hasMore: cachedCards.length >= pageSize,
      );
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal membaca cache SQLite: $e');
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: 'Gagal memuat katalog kartu.',
      );
    }
  }

  /// Ubah urutan kartu ke opsi tertentu (Termahal, Termurah, Nama)
  void setSortOrder(SortOrder newOrder) {
    if (state.sortOrder == newOrder) return;
    state = state.copyWith(sortOrder: newOrder);
    fetchCards(refresh: true);
  }

  /// Ganti urutan harga termahal <-> termurah
  void toggleSortOrder() {
    final nextOrder = state.sortOrder == SortOrder.expensiveFirst
        ? SortOrder.cheapestFirst
        : SortOrder.expensiveFirst;

    state = state.copyWith(sortOrder: nextOrder);
    fetchCards(refresh: true);
  }

  /// Paginasi (infinite scroll) saat user mencapai bawah grid
  void loadMore() {
    if (!state.isLoading && !state.isLoadingMore && state.hasMore) {
      fetchCards(refresh: false);
    }
  }

  /// Simpan batch kartu ke SQLite lokal untuk mode offline
  Future<void> _cacheCardsToLocal(List<CardModel> cards) async {
    try {
      final db = await LocalDb.instance;
      final batch = db.batch();

      for (final card in cards) {
        batch.insert(
          'cards',
          card.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal cache kartu ke SQLite: $e');
    }
  }
}

final dexProvider = StateNotifierProvider<DexNotifier, DexState>(
  (ref) => DexNotifier(),
);
