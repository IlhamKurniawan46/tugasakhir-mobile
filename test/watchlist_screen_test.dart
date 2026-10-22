import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/watchlist_item_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/profile/providers/watchlist_provider.dart';
import 'package:holodex/features/profile/screens/watchlist_screen.dart';

class FakeWatchlistNotifier extends WatchlistNotifier {
  final WatchlistState initialState;
  FakeWatchlistNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> loadWatchlist() async {}
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
      'WatchlistScreen builds empty state on 320dp with fontScale 1.3 without layout exception',
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
          watchlistProvider.overrideWith(
            (ref) => FakeWatchlistNotifier(
              const WatchlistState(items: [], isLoading: false),
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
            child: const WatchlistScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Watchlist & Target Harga'), findsOneWidget);
    expect(find.text('Watchlist Masih Kosong'), findsOneWidget);
  });

  testWidgets(
      'WatchlistScreen displays cards with target reached badge without layout exception',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const card = CardModel(
      id: 'swsh7-215',
      name: 'Umbreon VMAX',
      localId: '215',
      setName: 'Evolving Skies',
      priceRefUsd: 100.0,
      priceIdr: 1600000,
      hasPrice: true,
    );

    final items = [
      const WatchlistItemModel(
        cardId: 'swsh7-215',
        userId: 'u1',
        alertPriceIdr: 1800000, // Target lebih tinggi dari harga pasar => Tercapai!
        card: card,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchlistProvider.overrideWith(
            (ref) => FakeWatchlistNotifier(
              WatchlistState(items: items, isLoading: false),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WatchlistScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Umbreon VMAX'), findsOneWidget);
    expect(find.text('Target Tercapai'), findsOneWidget);
  });
}
