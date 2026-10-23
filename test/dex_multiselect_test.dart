import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/dex/providers/dex_provider.dart';
import 'package:holodex/features/dex/screens/dex_screen.dart';

class FakeDexNotifier extends DexNotifier {
  final DexState initialState;
  FakeDexNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> fetchCards({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {}
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
      'DexScreen multi-select triggers contextual AppBar and handles 320dp fontScale 1.3 safely',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 700 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const fakeCards = [
      CardModel(
        id: 'c1',
        name: 'Pikachu',
        localId: '25',
        setName: 'Base Set',
        priceRefUsd: 20.0,
        priceIdr: 320000,
        hasPrice: true,
      ),
      CardModel(
        id: 'c2',
        name: 'Mewtwo',
        localId: '150',
        setName: 'Base Set',
        priceRefUsd: 50.0,
        priceIdr: 800000,
        hasPrice: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dexProvider.overrideWith(
            (ref) => FakeDexNotifier(
              const DexState(cards: fakeCards, isLoading: false),
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
            child: const DexScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    // 1. Kondisi normal: Tidak ada mode pilih, judul "HoloDex", tile fitur terlihat
    expect(tester.takeException(), isNull);
    expect(find.text('HoloDex'), findsOneWidget);
    expect(find.text('Event'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    expect(find.text('Pikachu'), findsOneWidget);

    // 2. Long press pada Pikachu untuk memicu mode multi-select
    await tester.longPress(find.text('Pikachu'));
    await tester.pump();

    // 3. Masuk mode pilih: Contextual AppBar muncul dan baris fitur disembunyikan
    expect(tester.takeException(), isNull);
    expect(find.text('1 dipilih'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    expect(find.text('Event'), findsNothing);

    // 4. Tap pada Mewtwo untuk menambah pilihan
    await tester.tap(find.text('Mewtwo'));
    await tester.pump();
    expect(find.text('2 dipilih'), findsOneWidget);

    // 5. Tap tombol tutup (X) untuk membatalkan mode pilih
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    // 6. Kembali ke mode normal: AppBar normal & baris fitur muncul kembali
    expect(find.text('HoloDex'), findsOneWidget);
    expect(find.text('Event'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
  });
}
