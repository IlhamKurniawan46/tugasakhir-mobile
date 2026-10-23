import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/pack_service.dart';

void main() {
  group('PackService Unit Tests', () {
    const card1 = CardModel(
      id: 'swsh3-1',
      localId: '1',
      name: 'Butterfree V',
      priceIdr: 45000,
      priceRefUsd: 2.8,
      hasPrice: true,
    );

    const card2 = CardModel(
      id: 'swsh3-20',
      localId: '20',
      name: 'Charizard VMAX',
      priceIdr: 850000,
      priceRefUsd: 52.0,
      hasPrice: true,
    );

    const card3 = CardModel(
      id: 'sv01-25',
      localId: '25',
      name: 'Pikachu',
      priceIdr: 15000,
      priceRefUsd: 0.95,
      hasPrice: true,
    );

    test('calculateTotalValueIdr correctly sums priceIdr of all cards', () {
      final total = PackService.calculateTotalValueIdr([card1, card2, card3]);
      expect(total, 45000 + 850000 + 15000);
    });

    test('calculateTotalValueIdr handles empty list and null prices', () {
      expect(PackService.calculateTotalValueIdr([]), 0.0);

      const nullPriceCard = CardModel(
        id: 'card-null',
        localId: '0',
        name: 'Unknown Card',
        priceIdr: null,
      );
      expect(PackService.calculateTotalValueIdr([nullPriceCard]), 0.0);
    });

    test('getRandomPackCards sorts cards ascending so chase card is at the end',
        () async {
      final cards = await PackService.getRandomPackCards(count: 5);

      expect(cards.length, 5);
      // Verifikasi urutan harga naik (kartu bernilai terendah di awal, tertinggi di akhir)
      for (int i = 0; i < cards.length - 1; i++) {
        final currentPrice = cards[i].priceRefUsd ?? cards[i].priceIdr ?? 0.0;
        final nextPrice =
            cards[i + 1].priceRefUsd ?? cards[i + 1].priceIdr ?? 0.0;
        expect(currentPrice, lessThanOrEqualTo(nextPrice));
      }
    });
  });
}
