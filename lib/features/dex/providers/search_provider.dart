import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_db.dart';
import '../../../core/database/supabase_client.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/currency_service.dart';

class SearchState {
  final String query;
  final String? selectedSetId;
  final String? selectedRarity;
  final double? minPrice;
  final double? maxPrice;
  final List<CardModel> results;
  final bool isLoading;
  final List<Map<String, String>> availableSets;
  final List<String> availableRarities;
  final int totalLocalCount;

  const SearchState({
    this.query = '',
    this.selectedSetId,
    this.selectedRarity,
    this.minPrice,
    this.maxPrice,
    this.results = const [],
    this.isLoading = false,
    this.availableSets = const [],
    this.availableRarities = const [],
    this.totalLocalCount = 0,
  });

  bool get hasActiveFilters =>
      selectedSetId != null ||
      selectedRarity != null ||
      minPrice != null ||
      maxPrice != null;

  int get activeFilterCount {
    int count = 0;
    if (selectedSetId != null) count++;
    if (selectedRarity != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    return count;
  }

  /// Copy dengan modifikasi eksplisit untuk filter (mencegah bug fallback null yang tidak disengaja)
  SearchState copyWithFilters({
    String? query,
    required String? selectedSetId,
    required String? selectedRarity,
    required double? minPrice,
    required double? maxPrice,
    List<CardModel>? results,
    bool? isLoading,
    List<Map<String, String>>? availableSets,
    List<String>? availableRarities,
    int? totalLocalCount,
  }) =>
      SearchState(
        query: query ?? this.query,
        selectedSetId: selectedSetId,
        selectedRarity: selectedRarity,
        minPrice: minPrice,
        maxPrice: maxPrice,
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        availableSets: availableSets ?? this.availableSets,
        availableRarities: availableRarities ?? this.availableRarities,
        totalLocalCount: totalLocalCount ?? this.totalLocalCount,
      );

  SearchState copyWith({
    String? query,
    String? selectedSetId,
    bool clearSet = false,
    String? selectedRarity,
    bool clearRarity = false,
    double? minPrice,
    double? maxPrice,
    bool clearPrice = false,
    List<CardModel>? results,
    bool? isLoading,
    List<Map<String, String>>? availableSets,
    List<String>? availableRarities,
    int? totalLocalCount,
  }) =>
      SearchState(
        query: query ?? this.query,
        selectedSetId: clearSet ? null : (selectedSetId ?? this.selectedSetId),
        selectedRarity:
            clearRarity ? null : (selectedRarity ?? this.selectedRarity),
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        availableSets: availableSets ?? this.availableSets,
        availableRarities: availableRarities ?? this.availableRarities,
        totalLocalCount: totalLocalCount ?? this.totalLocalCount,
      );
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    await CurrencyService.initRates();
    await _ensureDatabaseSeeded();
    await _loadFilterOptions();
    await _performSearch();
  }

  /// Memastikan seluruh 914 kartu dari katalog Supabase di-cache ke SQLite lokal
  Future<void> _ensureDatabaseSeeded() async {
    try {
      final db = await LocalDb.instance;
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM cards');
      final localCount = Sqflite.firstIntValue(countResult) ?? 0;

      state = state.copyWith(totalLocalCount: localCount);

      // Jika cache SQLite kurang dari katalog penuh (914 kartu) dan Supabase aktif
      if (localCount < 900 && SupabaseService.isInitialized) {
        debugPrint('[HoloDex] Menyinkronkan seluruh katalog ke SQLite (Lokal: $localCount)...');
        final client = SupabaseService.client;
        final response = await client
            .from('cards')
            .select()
            .range(0, 1500)
            .order('price_ref_usd', ascending: false);

        final List<CardModel> allCards = (response as List)
            .map((item) => CardModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        final batch = db.batch();
        for (final card in allCards) {
          batch.insert(
            'cards',
            card.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);

        debugPrint('[HoloDex] Berhasil sinkronisasi ${allCards.length} kartu ke SQLite');
        state = state.copyWith(totalLocalCount: allCards.length);

        // Muat ulang opsi filter dengan data katalog lengkap
        await _loadFilterOptions();
      }
    } catch (e) {
      debugPrint('[HoloDex Warning] Background sync katalog ke SQLite: $e');
    }
  }

  /// Mengambil daftar set dan rarity lengkap dari database lokal
  Future<void> _loadFilterOptions() async {
    try {
      final db = await LocalDb.instance;

      // Ambil set unik beserta nama dan jumlah kartu
      final setRows = await db.rawQuery('''
        SELECT DISTINCT set_id, set_name 
        FROM cards 
        WHERE set_id IS NOT NULL AND set_id != '' 
        ORDER BY set_name ASC
      ''');

      final List<Map<String, String>> sets = setRows.map((row) {
        final id = row['set_id'] as String;
        final name = (row['set_name'] as String?) ?? id.toUpperCase();
        return {'id': id, 'name': name};
      }).toList();

      // Ambil rarity unik
      final rarityRows = await db.rawQuery('''
        SELECT DISTINCT rarity 
        FROM cards 
        WHERE rarity IS NOT NULL AND rarity != '' 
        ORDER BY rarity ASC
      ''');

      final List<String> rarities =
          rarityRows.map((row) => row['rarity'] as String).toList();

      state = state.copyWith(
        availableSets: sets,
        availableRarities: rarities,
      );
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal memuat filter options: $e');
    }
  }

  /// Ubah kata kunci pencarian secara real-time
  void setQuery(String newQuery) {
    state = state.copyWith(query: newQuery);
    _performSearch();
  }

  /// Terapkan filter set, rarity, dan rentang harga secara eksplisit
  void applyFilters({
    String? setId,
    String? rarity,
    double? minPrice,
    double? maxPrice,
  }) {
    state = state.copyWithFilters(
      selectedSetId: setId,
      selectedRarity: rarity,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    _performSearch();
  }

  void clearSetFilter() {
    state = state.copyWithFilters(
      selectedSetId: null,
      selectedRarity: state.selectedRarity,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );
    _performSearch();
  }

  void clearRarityFilter() {
    state = state.copyWithFilters(
      selectedSetId: state.selectedSetId,
      selectedRarity: null,
      minPrice: state.minPrice,
      maxPrice: state.maxPrice,
    );
    _performSearch();
  }

  void clearPriceFilter() {
    state = state.copyWithFilters(
      selectedSetId: state.selectedSetId,
      selectedRarity: state.selectedRarity,
      minPrice: null,
      maxPrice: null,
    );
    _performSearch();
  }

  void clearAllFilters() {
    state = state.copyWithFilters(
      selectedSetId: null,
      selectedRarity: null,
      minPrice: null,
      maxPrice: null,
    );
    _performSearch();
  }

  void resetAll() {
    state = const SearchState().copyWith(
      availableSets: state.availableSets,
      availableRarities: state.availableRarities,
      totalLocalCount: state.totalLocalCount,
    );
    _performSearch();
  }

  /// Eksekusi pencarian lokal SQLite dengan sinkronisasi kurs live
  Future<void> _performSearch() async {
    state = state.copyWith(isLoading: true);

    try {
      final db = await LocalDb.instance;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      // 1. Filter kata kunci (nama kartu atau nomor localId)
      final cleanQuery = state.query.trim();
      if (cleanQuery.isNotEmpty) {
        whereClauses.add('(name LIKE ? OR local_id LIKE ?)');
        whereArgs.add('%$cleanQuery%');
        whereArgs.add('%$cleanQuery%');
      }

      // 2. Filter Set ID (case-insensitive)
      if (state.selectedSetId != null && state.selectedSetId!.isNotEmpty) {
        whereClauses.add('LOWER(set_id) = LOWER(?)');
        whereArgs.add(state.selectedSetId);
      }

      // 3. Filter Rarity (case-insensitive)
      if (state.selectedRarity != null && state.selectedRarity!.isNotEmpty) {
        whereClauses.add('LOWER(rarity) = LOWER(?)');
        whereArgs.add(state.selectedRarity);
      }

      // 4. Filter Rentang Harga berdasarkan Kurs Live yang tampil di UI
      // CardTile menampilkan harga berdasarkan: priceRefUsd * usdToIdrRate
      final rate = CurrencyService.usdToIdrRate > 0
          ? CurrencyService.usdToIdrRate
          : 17921.0;

      if (state.minPrice != null) {
        final minUsd = state.minPrice! / rate;
        whereClauses.add(
          '((price_ref_usd IS NOT NULL AND price_ref_usd >= ?) OR (price_ref_usd IS NULL AND price_idr >= ?))',
        );
        whereArgs.add(minUsd);
        whereArgs.add(state.minPrice);
      }

      if (state.maxPrice != null) {
        final maxUsd = state.maxPrice! / rate;
        whereClauses.add(
          '((price_ref_usd IS NOT NULL AND price_ref_usd <= ?) OR (price_ref_usd IS NULL AND price_idr <= ?))',
        );
        whereArgs.add(maxUsd);
        whereArgs.add(state.maxPrice);
      }

      final whereString =
          whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final rows = await db.query(
        'cards',
        where: whereString,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'price_ref_usd DESC NULLS LAST, name ASC',
      );

      final List<CardModel> results =
          rows.map((row) => CardModel.fromMap(row)).toList();

      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal eksekusi pencarian SQLite: $e');
      state = state.copyWith(
        results: [],
        isLoading: false,
      );
    }
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});
