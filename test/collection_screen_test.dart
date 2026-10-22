import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/collection_item_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/profile/providers/collection_provider.dart';
import 'package:holodex/features/profile/screens/collection_screen.dart';

class FakeCollectionNotifier extends CollectionNotifier {
  final CollectionState initialState;
  FakeCollectionNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> loadCollection({bool forceRefresh = false}) async {}
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

  testWidgets(
      'CollectionScreen builds empty state on 320dp with fontScale 1.3 without layout exception',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 700 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionProvider.overrideWith(
            (ref) => FakeCollectionNotifier(
              const CollectionState(items: [], isLoading: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const CollectionScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Koleksi Saya'), findsOneWidget);
    expect(find.text('Koleksi Masih Kosong'), findsOneWidget);
    expect(find.byIcon(Icons.storefront), findsOneWidget);
  });

  testWidgets(
      'CollectionScreen displays items and portfolio summary without layout exception',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const fakeCard = CardModel(
      id: 'swsh3-19',
      name: 'Charizard V',
      localId: '19',
      setName: 'Darkness Ablaze',
      rarity: 'Ultra Rare',
      priceRefUsd: 15.0,
      priceIdr: 240000,
      hasPrice: true,
    );

    final fakeItems = [
      CollectionItemModel(
        cardId: 'swsh3-19',
        userId: 'u1',
        acquiredVia: 'purchase',
        acquiredAt: DateTime.now(),
        card: fakeCard,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionProvider.overrideWith(
            (ref) => FakeCollectionNotifier(
              CollectionState(items: fakeItems, isLoading: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
            ),
            child: CollectionScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Estimasi Nilai Koleksi'), findsOneWidget);
    expect(find.text('1 Kartu Fisik'), findsOneWidget);
    expect(find.text('Charizard V'), findsOneWidget);
    expect(find.text('Pasar'), findsOneWidget);
  });
}
