import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/collection_item_model.dart';
import 'package:holodex/core/models/watchlist_item_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/profile/providers/collection_provider.dart';
import 'package:holodex/features/profile/providers/watchlist_provider.dart';
import 'package:holodex/shared/providers/currency_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Collection / Koleksi Saya Unit Tests', () {
    test('CollectionItemModel serialization and defaults', () {
      final now = DateTime.now();
      final item = CollectionItemModel(
        cardId: 'swsh3-19',
        userId: 'user-uuid-1',
        acquiredVia: 'purchase',
        acquiredAt: now,
      );

      final map = item.toMap();
      expect(map['card_id'], equals('swsh3-19'));
      expect(map['user_id'], equals('user-uuid-1'));
      expect(map['acquired_via'], equals('purchase'));
      expect(map['acquired_at'], equals(now.millisecondsSinceEpoch));

      final recreated = CollectionItemModel.fromMap(map);
      expect(recreated.cardId, equals('swsh3-19'));
      expect(recreated.acquiredVia, equals('purchase'));
    });

    test('CollectionState calculates totalRefUsd and exclusions correctly', () {
      const cardWithPrice1 = CardModel(
        id: 'c1',
        name: 'Charizard',
        priceRefUsd: 100.0,
        priceIdr: 1550000,
        hasPrice: true,
      );
      const cardWithPrice2 = CardModel(
        id: 'c2',
        name: 'Pikachu',
        priceRefUsd: 50.0,
        priceIdr: 775000,
        hasPrice: true,
      );
      const cardWithoutPrice = CardModel(
        id: 'c3',
        name: 'Caterpie',
        priceRefUsd: null,
        hasPrice: false,
      );

      final state = CollectionState(
        items: [
          const CollectionItemModel(cardId: 'c1', userId: 'u1', card: cardWithPrice1),
          const CollectionItemModel(cardId: 'c2', userId: 'u1', card: cardWithPrice2),
          const CollectionItemModel(cardId: 'c3', userId: 'u1', card: cardWithoutPrice),
        ],
      );

      expect(state.items.length, equals(3));
      expect(state.pricedCount, equals(2));
      expect(state.unpricedCount, equals(1));
      expect(state.totalRefUsd, equals(150.0));
    });

    test('CollectionState currency conversion reflects active rates', () {
      // Inisialisasi rates manual untuk unit test
      CurrencyService.setMockRates(const CurrencyRates(
        usdToEur: 0.92,
        usdToIdr: 16000.0,
        ecbDate: '2026-10-22',
      ));

      const card = CardModel(
        id: 'c1',
        name: 'Rayquaza',
        priceRefUsd: 10.0,
        hasPrice: true,
      );

      final state = CollectionState(
        items: [
          const CollectionItemModel(cardId: 'c1', userId: 'u1', card: card),
        ],
      );

      final totalIdr = state.getTotalInCurrency(AppCurrency.idr);
      expect(totalIdr, equals(160000.0));

      final totalEur = state.getTotalInCurrency(AppCurrency.eur);
      expect(totalEur, closeTo(9.20, 0.0001));

      final totalUsd = state.getTotalInCurrency(AppCurrency.usd);
      expect(totalUsd, equals(10.0));
    });
  });

  group('Watchlist Unit Tests', () {
    test('WatchlistItemModel serialization and copyWith', () {
      const item = WatchlistItemModel(
        cardId: 'swsh7-215',
        userId: 'user-uuid-1',
        alertPriceIdr: 500000.0,
      );

      final map = item.toMap();
      expect(map['card_id'], equals('swsh7-215'));
      expect(map['alert_price_idr'], equals(500000.0));

      final updated = item.copyWith(alertPriceIdr: 450000.0);
      expect(updated.alertPriceIdr, equals(450000.0));
      expect(updated.cardId, equals('swsh7-215'));
    });

    test('WatchlistState.isTargetReached evaluates condition accurately', () {
      CurrencyService.setMockRates(const CurrencyRates(
        usdToEur: 0.92,
        usdToIdr: 16000.0,
        ecbDate: '2026-10-22',
      ));

      // Kartu dengan priceRefUsd 10.0 => Rp160.000
      const card = CardModel(
        id: 'c1',
        name: 'Gengar',
        priceRefUsd: 10.0,
        priceIdr: 160000.0,
        hasPrice: true,
      );

      // Kasus 1: Target Rp180.000 (Harga saat ini Rp160.000 <= 180.000) => TARGET TERCAPAI
      const itemReached = WatchlistItemModel(
        cardId: 'c1',
        userId: 'u1',
        alertPriceIdr: 180000.0,
        card: card,
      );
      expect(WatchlistState.isTargetReached(itemReached), isTrue);

      // Kasus 2: Target Rp150.000 (Harga saat ini Rp160.000 > 150.000) => BELUM TERCAPAI
      const itemNotReached = WatchlistItemModel(
        cardId: 'c1',
        userId: 'u1',
        alertPriceIdr: 150000.0,
        card: card,
      );
      expect(WatchlistState.isTargetReached(itemNotReached), isFalse);

      // Kasus 3: Target null => FALSE
      const itemNullTarget = WatchlistItemModel(
        cardId: 'c1',
        userId: 'u1',
        alertPriceIdr: null,
        card: card,
      );
      expect(WatchlistState.isTargetReached(itemNullTarget), isFalse);
    });
  });
}
