import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/dex/providers/search_provider.dart';

void main() {
  group('SearchState & Filtering Unit Tests', () {
    test('Initial SearchState has default values', () {
      const state = SearchState();
      expect(state.query, isEmpty);
      expect(state.selectedSetId, isNull);
      expect(state.selectedRarity, isNull);
      expect(state.minPrice, isNull);
      expect(state.maxPrice, isNull);
      expect(state.results, isEmpty);
      expect(state.hasActiveFilters, isFalse);
      expect(state.activeFilterCount, equals(0));
    });

    test('Active filters count updates correctly', () {
      var state = const SearchState().copyWith(
        selectedSetId: 'swsh3',
        selectedRarity: 'Rare',
        minPrice: 50000,
        maxPrice: 250000,
      );

      expect(state.hasActiveFilters, isTrue);
      expect(state.activeFilterCount, equals(3));

      // Hapus set filter
      state = state.copyWith(clearSet: true);
      expect(state.selectedSetId, isNull);
      expect(state.activeFilterCount, equals(2));

      // Hapus rarity filter
      state = state.copyWith(clearRarity: true);
      expect(state.selectedRarity, isNull);
      expect(state.activeFilterCount, equals(1));

      // Hapus price filter
      state = state.copyWith(clearPrice: true);
      expect(state.hasActiveFilters, isFalse);
      expect(state.activeFilterCount, equals(0));
    });

    test('Switching price filters from range to single bound does not retain previous min/max', () {
      // 1. Awalnya pilih 50rb - 250rb
      var state = const SearchState().copyWithFilters(
        selectedSetId: null,
        selectedRarity: null,
        minPrice: 50000,
        maxPrice: 250000,
      );
      expect(state.minPrice, equals(50000));
      expect(state.maxPrice, equals(250000));

      // 2. Kemudian ganti ke < 50.000 (minPrice: null, maxPrice: 50000)
      state = state.copyWithFilters(
        selectedSetId: null,
        selectedRarity: null,
        minPrice: null,
        maxPrice: 50000,
      );

      // Verifikasi bahwa minPrice benar-benar null, BUKAN 50000!
      expect(state.minPrice, isNull);
      expect(state.maxPrice, equals(50000));

      // 3. Kemudian ganti ke > 1.000.000 (minPrice: 1000000, maxPrice: null)
      state = state.copyWithFilters(
        selectedSetId: null,
        selectedRarity: null,
        minPrice: 1000000,
        maxPrice: null,
      );

      // Verifikasi bahwa maxPrice benar-benar null, BUKAN 50000!
      expect(state.minPrice, equals(1000000));
      expect(state.maxPrice, isNull);
    });

    test('Price filter dynamic USD conversion matches CardTile display rate', () {
      const double rate = 17921.0;
      const double filterMaxIdr = 250000.0;
      final double maxUsd = filterMaxIdr / rate;

      // Kartu dengan priceRefUsd = 14.0356 yang di UI menghasilkan Rp 251.532
      const double cardPriceRefUsd = 14.0356;
      final double displayedIdr = CurrencyService.convertRefUsdToIdr(cardPriceRefUsd);
      expect(displayedIdr, greaterThan(250000));

      // Dalam query, kartu ini harus ditolak karena cardPriceRefUsd > maxUsd
      expect(cardPriceRefUsd <= maxUsd, isFalse);
    });

    test('CardModel serialization matches SQLite mapping', () {
      const card = CardModel(
        id: 'swsh3-1',
        localId: '1',
        name: 'Butterfree V',
        setId: 'swsh3',
        setName: 'Darkness Ablaze',
        rarity: 'Rare Holo V',
        cardType: 'Grass',
        priceIdr: 25000,
        priceRefUsd: 1.5,
        hasPrice: true,
      );

      final map = card.toMap();
      expect(map['id'], equals('swsh3-1'));
      expect(map['name'], equals('Butterfree V'));
      expect(map['set_id'], equals('swsh3'));
      expect(map['rarity'], equals('Rare Holo V'));
      expect(map['price_idr'], equals(25000));
      expect(map['has_price'], equals(1));

      final restored = CardModel.fromMap(map);
      expect(restored.id, equals(card.id));
      expect(restored.name, equals(card.name));
      expect(restored.setId, equals(card.setId));
      expect(restored.rarity, equals(card.rarity));
      expect(restored.priceIdr, equals(card.priceIdr));
      expect(restored.hasPrice, isTrue);
    });
  });
}
