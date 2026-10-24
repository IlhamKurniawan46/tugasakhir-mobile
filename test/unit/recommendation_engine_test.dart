import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/user_interaction_model.dart';
import 'package:holodex/core/services/interaction_service.dart';
import 'package:holodex/core/services/recommendation_engine.dart';

void main() {
  group('RecommendationEngine — Pure Functions', () {
    test('1. Ekstraksi nama Pokémon membuang sufiks dengan benar', () {
      expect(RecommendationEngine.extractPokemonName('Charizard ex'), 'Charizard');
      expect(RecommendationEngine.extractPokemonName('Umbreon VMAX'), 'Umbreon');
      expect(RecommendationEngine.extractPokemonName('Arceus VSTAR'), 'Arceus');
      expect(RecommendationEngine.extractPokemonName('Pikachu V'), 'Pikachu');
      expect(RecommendationEngine.extractPokemonName('Mewtwo GX'), 'Mewtwo');
      expect(RecommendationEngine.extractPokemonName('Greninja BREAK'), 'Greninja');
      expect(RecommendationEngine.extractPokemonName('Radiant Blastoise'), 'Blastoise');
      expect(RecommendationEngine.extractPokemonName('Gengar'), 'Gengar');
    });

    test('2. Peluruhan eksponensial (waktu paruh 14 hari, cutoff 90 hari)', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);

      // Event hari ini (umur 0 hari) -> bobot utuh
      final w0 = RecommendationEngine.calculateDecayedWeight(
        baseWeight: 5.0,
        eventTime: now,
        currentTime: now,
      );
      expect(w0, closeTo(5.0, 0.001));

      // Event 14 hari lalu -> bobot berkurang setengahnya (5.0 * 0.5 = 2.5)
      final w14 = RecommendationEngine.calculateDecayedWeight(
        baseWeight: 5.0,
        eventTime: now.subtract(const Duration(days: 14)),
        currentTime: now,
      );
      expect(w14, closeTo(2.5, 0.01));

      // Event 28 hari lalu -> bobot berkurang seperempatnya (5.0 * 0.25 = 1.25)
      final w28 = RecommendationEngine.calculateDecayedWeight(
        baseWeight: 5.0,
        eventTime: now.subtract(const Duration(days: 28)),
        currentTime: now,
      );
      expect(w28, closeTo(1.25, 0.01));

      // Event > 90 hari lalu -> bobot 0.0 (cutoff)
      final w95 = RecommendationEngine.calculateDecayedWeight(
        baseWeight: 5.0,
        eventTime: now.subtract(const Duration(days: 95)),
        currentTime: now,
      );
      expect(w95, 0.0);
    });

    test('3. Pita harga dan kedekatan harga bekerja dengan tepat', () {
      expect(PriceBracket.fromUsd(0.5), PriceBracket.under1);
      expect(PriceBracket.fromUsd(3.5), PriceBracket.oneToFive);
      expect(PriceBracket.fromUsd(15.0), PriceBracket.fiveToTwenty);
      expect(PriceBracket.fromUsd(50.0), PriceBracket.twentyToOneHundred);
      expect(PriceBracket.fromUsd(250.0), PriceBracket.aboveOneHundred);

      // Proximity
      expect(PriceBracket.under1.proximityTo(PriceBracket.under1), 1.0);
      expect(PriceBracket.under1.proximityTo(PriceBracket.oneToFive), 0.5);
      expect(PriceBracket.under1.proximityTo(PriceBracket.fiveToTwenty), 0.0);
    });

    test('4. Kartu yang cocok dengan profil minat mendapat skor lebih tinggi', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);

      const card1 = CardModel(
        id: 'swsh7-215',
        name: 'Umbreon VMAX',
        setId: 'swsh7',
        setName: 'Evolving Skies',
        rarity: 'Secret Rare',
        cardType: 'Darkness',
        priceRefUsd: 150.0,
      );

      const card2 = CardModel(
        id: 'sv01-1',
        name: 'Oddish',
        setId: 'sv01',
        setName: 'Scarlet & Violet',
        rarity: 'Common',
        cardType: 'Grass',
        priceRefUsd: 0.25,
      );

      // Simulasikan pengguna sering berinteraksi dengan Umbreon dan Evolving Skies
      final interactions = [
        UserInteraction(
          userId: 'user1',
          eventType: InteractionService.eventPurchase,
          cardId: 'swsh7-215',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        UserInteraction(
          userId: 'user1',
          eventType: InteractionService.eventCardView,
          cardId: 'swsh7-215',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      final cardMap = {'swsh7-215': card1, 'sv01-1': card2};
      final profile = RecommendationEngine.buildProfile(
        interactions: interactions,
        cardMap: cardMap,
        now: now,
      );

      expect(profile.isColdStart, isFalse);

      final scoreCard1 = RecommendationEngine.scoreCard(card: card1, profile: profile);
      final scoreCard2 = RecommendationEngine.scoreCard(card: card2, profile: profile);

      expect(scoreCard1.score, greaterThan(scoreCard2.score));
      expect(scoreCard1.reason, contains('Umbreon'));
    });

    test('5. Kartu di Binder, Watchlist, atau baru dilihat 24 jam dikecualikan', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);

      const cardA = CardModel(id: 'card-a', name: 'Charizard ex', setId: 'sv03.5', priceRefUsd: 50.0);
      const cardB = CardModel(id: 'card-b', name: 'Blastoise ex', setId: 'sv03.5', priceRefUsd: 40.0);
      const cardC = CardModel(id: 'card-c', name: 'Venusaur ex', setId: 'sv03.5', priceRefUsd: 30.0);
      const cardD = CardModel(id: 'card-d', name: 'Pikachu', setId: 'sv03.5', priceRefUsd: 20.0);

      final catalog = [cardA, cardB, cardC, cardD];

      // Profil dengan interaksi cukup agar bukan cold start
      final interactions = [
        UserInteraction(
          userId: 'user1',
          eventType: InteractionService.eventPurchase,
          cardId: 'card-a',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        UserInteraction(
          userId: 'user1',
          eventType: InteractionService.eventPurchase,
          cardId: 'card-b',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      final cardMap = {for (final c in catalog) c.id: c};
      final profile = RecommendationEngine.buildProfile(
        interactions: interactions,
        cardMap: cardMap,
        now: now,
      );

      final recs = RecommendationEngine.generateRecommendations(
        catalog: catalog,
        profile: profile,
        binderCardIds: {'card-a'}, // cardA ada di binder
        watchlistCardIds: {'card-b'}, // cardB ada di watchlist
        recentViewedCardIds: {'card-c'}, // cardC baru dilihat 24 jam
        userId: 'user1',
        now: now,
      );

      final recIds = recs.map((r) => r.card.id).toSet();
      expect(recIds.contains('card-a'), isFalse);
      expect(recIds.contains('card-b'), isFalse);
      expect(recIds.contains('card-c'), isFalse);
      expect(recIds.contains('card-d'), isTrue);
    });

    test('6. Batas maksimal 3 kartu per set dipatuhi', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);

      // Buat 6 kartu dari set yang sama 'set-x'
      final catalog = List.generate(
        6,
        (i) => CardModel(
          id: 'card-$i',
          name: 'Pokemon $i',
          setId: 'set-x',
          setName: 'Set X',
          priceRefUsd: 10.0 + i,
        ),
      );

      final interactions = [
        UserInteraction(
          userId: 'user1',
          eventType: InteractionService.eventPurchase,
          cardId: 'card-0',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        UserInteraction(
          userId: 'user1',
          eventType: InteractionService.eventPurchase,
          cardId: 'card-1',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final cardMap = {for (final c in catalog) c.id: c};
      final profile = RecommendationEngine.buildProfile(
        interactions: interactions,
        cardMap: cardMap,
        now: now,
      );

      final recs = RecommendationEngine.generateRecommendations(
        catalog: catalog,
        profile: profile,
        binderCardIds: {},
        watchlistCardIds: {},
        recentViewedCardIds: {},
        userId: 'user1',
        now: now,
      );

      final inSetX = recs.where((r) => r.card.setId == 'set-x').length;
      expect(inSetX, lessThanOrEqualTo(RecommendationEngine.maxCardsPerSet));
    });

    test('7. Cold start fallback aktif jika total bobot profil < 5.0', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);

      // Hanya 1 card_view (bobot 1.0 < 5.0)
      final interactions = [
        UserInteraction(
          userId: 'new_user',
          eventType: InteractionService.eventCardView,
          cardId: 'card-1',
          createdAt: now,
        ),
      ];

      const card1 = CardModel(id: 'card-1', name: 'Card 1', priceRefUsd: 10.0);
      const card2 = CardModel(id: 'card-2', name: 'Card 2', priceRefUsd: 200.0);
      const card3 = CardModel(id: 'card-3', name: 'Card 3', priceRefUsd: 50.0);

      final catalog = [card1, card2, card3];
      final cardMap = {for (final c in catalog) c.id: c};

      final profile = RecommendationEngine.buildProfile(
        interactions: interactions,
        cardMap: cardMap,
        now: now,
      );

      expect(profile.isColdStart, isTrue);

      final recs = RecommendationEngine.generateRecommendations(
        catalog: catalog,
        profile: profile,
        binderCardIds: {},
        watchlistCardIds: {},
        recentViewedCardIds: {},
        userId: 'new_user',
        now: now,
      );

      expect(recs.isNotEmpty, isTrue);
      expect(recs.first.reason, 'Pilihan populer');
    });

    test('8. Pemetaan kata kunci pencarian ke tipe dan Pokémon', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);

      const card1 = CardModel(id: 'c1', name: 'Gengar VMAX', cardType: 'Psychic');
      final cardMap = {'c1': card1};

      final interactions = [
        UserInteraction(
          userId: 'u1',
          eventType: InteractionService.eventSearchMatch,
          queryText: 'Psychic',
          createdAt: now,
        ),
        UserInteraction(
          userId: 'u1',
          eventType: InteractionService.eventSearchMatch,
          queryText: 'Gengar',
          createdAt: now,
        ),
      ];

      final profile = RecommendationEngine.buildProfile(
        interactions: interactions,
        cardMap: cardMap,
        now: now,
      );

      expect(profile.typeWeights['Psychic'], isNotNull);
      expect(profile.pokemonWeights['Gengar'], isNotNull);
    });

    test('9. UserInterestProfile.getTopInterests() mengembalikan urutan minat teratas & persentase proporsional', () {
      const profile = UserInterestProfile(
        pokemonWeights: {'Charizard': 15.0, 'Pikachu': 5.0},
        setWeights: {'sv03.5': 10.0},
        rarityWeights: {'Special Illustration Rare': 8.0},
        typeWeights: {'Fire': 12.0},
        priceBracketWeights: {PriceBracket.fiveToTwenty: 6.0},
        totalWeight: 56.0,
      );

      final top5 = profile.getTopInterests(limit: 5);

      expect(top5.length, 5);
      // Item pertama harus Charizard dengan bobot 15.0 dan percentage 1.0 (100%)
      expect(top5[0].category, 'Pokémon');
      expect(top5[0].label, 'Charizard');
      expect(top5[0].percentage, 1.0);

      // Item kedua harus Fire (12.0) dengan percentage 12/15 = 0.8 (80%)
      expect(top5[1].category, 'Tipe');
      expect(top5[1].label, 'Fire');
      expect(top5[1].percentage, closeTo(0.8, 0.01));

      // Item ketiga harus SV03.5 (10.0)
      expect(top5[2].category, 'Set');
      expect(top5[2].label, 'SV03.5');
    });

    test('10. Pemetaan jawaban kuis (type:, set:, price:) langsung tercatat ke profil', () {
      final now = DateTime.utc(2026, 10, 24, 12, 0);
      final interactions = [
        UserInteraction(
          userId: 'u1',
          eventType: InteractionService.eventQuiz,
          queryText: 'type:Water',
          createdAt: now,
        ),
        UserInteraction(
          userId: 'u1',
          eventType: InteractionService.eventQuiz,
          queryText: 'set:swsh7',
          createdAt: now,
        ),
        UserInteraction(
          userId: 'u1',
          eventType: InteractionService.eventQuiz,
          queryText: 'price:twentyToOneHundred',
          createdAt: now,
        ),
      ];

      final profile = RecommendationEngine.buildProfile(
        interactions: interactions,
        cardMap: const {},
        now: now,
      );

      expect(profile.typeWeights['Water'], isNotNull);
      expect(profile.setWeights['swsh7'], isNotNull);
      expect(profile.priceBracketWeights[PriceBracket.twentyToOneHundred], isNotNull);
    });
  });
}
