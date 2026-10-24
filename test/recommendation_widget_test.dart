import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/recommendation_engine.dart';
import 'package:holodex/features/dex/providers/recommendation_provider.dart';
import 'package:holodex/features/dex/widgets/recommendation_carousel.dart';

void main() {
  const testCard1 = CardModel(
    id: 'test-1',
    name: 'Charizard ex',
    setId: 'sv03.5',
    setName: '151',
    rarity: 'Special Illustration Rare',
    cardType: 'Fire',
    priceRefUsd: 120.0,
  );

  const testCard2 = CardModel(
    id: 'test-2',
    name: 'Umbreon VMAX',
    setId: 'swsh7',
    setName: 'Evolving Skies',
    rarity: 'Secret Rare',
    cardType: 'Darkness',
    priceRefUsd: 250.0,
  );

  final testItems = [
    const RecommendedCard(
      card: testCard1,
      score: 0.85,
      reason: 'Karena kamu sering melihat Charizard',
      isExploration: false,
    ),
    const RecommendedCard(
      card: testCard2,
      score: 0.65,
      reason: 'Coba jelajahi',
      isExploration: true,
    ),
  ];

  Widget buildTestWidget({
    required RecommendationState state,
    double width = 360,
    double height = 640,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        recommendationProvider.overrideWith(
          (ref) => _MockRecommendationNotifier(state),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: RecommendationCarousel(),
            ),
          ),
        ),
      ),
    );
  }

  group('RecommendationCarousel Widget Tests', () {
    testWidgets('1. Tampil dengan benar saat data rekomendasi tersedia', (tester) async {
      final state = RecommendationState(
        items: testItems,
        isLoading: false,
        isColdStart: false,
      );

      await tester.pumpWidget(buildTestWidget(state: state));
      await tester.pumpAndSettle();

      expect(find.text('Rekomendasi Untukmu'), findsOneWidget);
      expect(find.text('Charizard ex'), findsOneWidget);
      expect(find.text('Umbreon VMAX'), findsOneWidget);
      expect(find.text('Karena kamu sering melihat Charizard'), findsOneWidget);
      expect(find.text('Coba jelajahi'), findsOneWidget);
    });

    testWidgets('2. Menampilkan judul Pilihan Awal saat Cold Start', (tester) async {
      final state = RecommendationState(
        items: testItems,
        isLoading: false,
        isColdStart: true,
      );

      await tester.pumpWidget(buildTestWidget(state: state));
      await tester.pumpAndSettle();

      expect(find.text('Pilihan Awal Untukmu'), findsOneWidget);
    });

    testWidgets('3. Aman dari overflow pada layar sempit 320dp dan font scale 1.3', (tester) async {
      final state = RecommendationState(
        items: testItems,
        isLoading: false,
        isColdStart: false,
      );

      await tester.pumpWidget(buildTestWidget(
        state: state,
        width: 320,
        height: 600,
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Mengembalikan SizedBox.shrink saat daftar kosong', (tester) async {
      const state = RecommendationState(
        items: [],
        isLoading: false,
        isColdStart: true,
      );

      await tester.pumpWidget(buildTestWidget(state: state));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
    });
  });
}

class _MockRecommendationNotifier extends RecommendationNotifier {
  final RecommendationState _mockState;
  _MockRecommendationNotifier(this._mockState);

  @override
  RecommendationState get state => _mockState;

  @override
  Future<void> loadRecommendations({bool force = false}) async {}
}
