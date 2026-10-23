import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/pack_opening/providers/pack_provider.dart';
import 'package:holodex/features/pack_opening/screens/pack_opening_screen.dart';

class FakePackNotifier extends PackNotifier {
  final PackState initialState;
  FakePackNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  void startListeningToSensors() {}

  @override
  void stopListeningToSensors() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    CurrencyService.setMockRates(const CurrencyRates(
      usdToEur: 0.92,
      usdToIdr: 16000.0,
      ecbDate: '2026-10-22',
    ));
  });

  const sampleCard1 = CardModel(
    id: 'sv01-25',
    localId: '25',
    name: 'Pikachu',
    rarity: 'Common',
    priceIdr: 15000,
    priceUsd: 0.95,
    hasPrice: true,
  );

  const sampleCard2 = CardModel(
    id: 'swsh3-1',
    localId: '1',
    name: 'Butterfree V',
    rarity: 'Ultra Rare',
    priceIdr: 45000,
    priceUsd: 2.8,
    hasPrice: true,
  );

  const sampleCard3 = CardModel(
    id: 'swsh3-20',
    localId: '20',
    name: 'Charizard VMAX',
    rarity: 'Secret Rare',
    priceIdr: 850000,
    priceUsd: 52.0,
    hasPrice: true,
  );

  Widget createTestWidget({
    required Widget child,
    PackState? packState,
    double textScale = 1.0,
    Size size = const Size(360, 640),
  }) {
    return ProviderScope(
      overrides: [
        packProvider.overrideWith(
          (ref) => FakePackNotifier(
            packState ?? const PackState(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('PackOpeningScreen Widget Tests (Mini Game & Anti-Overflow)', () {
    testWidgets(
        'PackOpeningScreen builds sealed view on 320dp with fontScale 1.3 without error',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createTestWidget(
        child: const PackOpeningScreen(),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Verifikasi judul AppBar & Rekor Header
      expect(find.text('Buka Booster Pack'), findsOneWidget);
      expect(find.textContaining('Rekor Pull Terbaik'), findsOneWidget);

      // Verifikasi komponen sealed pack
      expect(find.text('Shake Meter'), findsOneWidget);
      expect(find.text('Buka Pack Sekarang'), findsOneWidget);
    });

    testWidgets(
        'PackOpeningScreen builds revealing view with suspense flip card on 320dp',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createTestWidget(
        child: const PackOpeningScreen(),
        packState: const PackState(
          stage: PackStage.revealing,
          cards: [sampleCard1, sampleCard2, sampleCard3],
          currentRevealIndex: 0,
          revealedIndices: {0},
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Verifikasi indikator kartu
      expect(find.text('KARTU 1 DARI 3'), findsOneWidget);
      expect(find.text('Buka Selanjutnya'), findsOneWidget);
      expect(find.text('Buka Semua (Skip)'), findsOneWidget);
    });

    testWidgets(
        'PackOpeningScreen builds completed view with total pull value and card list',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createTestWidget(
        child: const PackOpeningScreen(),
        packState: const PackState(
          stage: PackStage.completed,
          cards: [sampleCard1, sampleCard2, sampleCard3],
          revealedIndices: {0, 1, 2},
          isNewRecord: true,
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Verifikasi ringkasan
      expect(find.text('REKOR PULL BARU!'), findsOneWidget);
      expect(find.text('TOTAL PULL VALUE:'), findsOneWidget);
      expect(find.text('5 Kartu yang Didapat:'), findsOneWidget);
      expect(find.text('Buka Pack Lagi'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
    });
  });
}
