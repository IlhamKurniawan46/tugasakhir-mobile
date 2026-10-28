import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/listing_model.dart';
import 'package:holodex/core/models/transaction_model.dart';
import 'package:holodex/core/models/user_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/auth/providers/auth_provider.dart';
import 'package:holodex/features/marketplace/providers/marketplace_provider.dart';
import 'package:holodex/features/marketplace/screens/listing_detail_screen.dart';
import 'package:holodex/features/marketplace/screens/marketplace_screen.dart';
import 'package:holodex/features/marketplace/screens/transaction_history_screen.dart';

class FakeMarketplaceNotifier extends MarketplaceNotifier {
  final MarketplaceState initialState;
  FakeMarketplaceNotifier(super.ref, this.initialState) {
    state = initialState;
  }

  @override
  Future<void> loadListings({bool forceRefresh = false}) async {}
}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  FakeAuthNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> refreshProfile() async {}
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

  const sampleCard = CardModel(
    id: 'swsh3-19',
    localId: '19',
    name: 'Charizard V',
    setId: 'swsh3',
    setName: 'Darkness Ablaze',
    rarity: 'Ultra Rare',
    priceIdr: 250000,
    priceUsd: 15.5,
    hasPrice: true,
  );

  const sampleListing = ListingModel(
    id: 'list-101',
    cardId: 'swsh3-19',
    sellerId: 'user-seller-1',
    sellerUsername: 'kolektor_jkt',
    priceIdr: 220000,
    condition: 'mint',
    description: 'Kondisi prima no scratch.',
    card: sampleCard,
    status: 'active',
  );

  const testUser = UserModel(
    id: 'user-buyer-1',
    username: 'ilham_collector',
    balanceIdr: 1000000,
  );

  group('Unit Tests: ListingModel & TransactionModel', () {
    test('ListingModel fromJson and toJson serialization', () {
      final json = sampleListing.toJson();
      final parsed = ListingModel.fromJson(json);

      expect(parsed.id, 'list-101');
      expect(parsed.priceIdr, 220000);
      expect(parsed.condition, 'mint');
      expect(parsed.conditionLabel, 'Mint (Sempurna)');
      expect(parsed.sellerUsername, 'kolektor_jkt');
      expect(parsed.card?.name, 'Charizard V');
    });

    test('TransactionModel fromJson and toJson serialization', () {
      final transaction = TransactionModel(
        id: 'tx-201',
        listingId: 'list-101',
        buyerId: 'user-buyer-1',
        sellerId: 'user-seller-1',
        cardId: 'swsh3-19',
        priceIdr: 220000,
        createdAt: DateTime.parse('2026-10-22T10:00:00Z'),
        card: sampleCard,
        buyerUsername: 'ilham_collector',
        sellerUsername: 'kolektor_jkt',
        isBuyer: true,
      );

      final json = transaction.toJson();
      final parsed = TransactionModel.fromJson(json);

      expect(parsed.id, 'tx-201');
      expect(parsed.priceIdr, 220000);
      expect(parsed.isBuyer, true);
      expect(parsed.buyerUsername, 'ilham_collector');
      expect(parsed.sellerUsername, 'kolektor_jkt');
    });
  });

  group('Unit Tests: Marketplace Filtering & Sorting', () {
    test('Filtering by search query and condition', () {
      final listing2 = sampleListing.copyWith(
        id: 'list-102',
        condition: 'good',
        priceIdr: 150000,
        card: const CardModel(
          id: 'swsh3-20',
          name: 'Pikachu V',
          priceIdr: 180000,
        ),
      );

      final state = MarketplaceState(
        listings: [sampleListing, listing2],
        searchQuery: 'Pikachu',
      );

      expect(state.filteredListings.length, 1);
      expect(state.filteredListings.first.card?.name, 'Pikachu V');

      final conditionState = MarketplaceState(
        listings: [sampleListing, listing2],
        selectedCondition: 'good',
      );

      expect(conditionState.filteredListings.length, 1);
      expect(conditionState.filteredListings.first.id, 'list-102');
    });

    test('Sorting by cheapest and priciest', () {
      final listingA = sampleListing.copyWith(id: 'a', priceIdr: 300000);
      final listingB = sampleListing.copyWith(id: 'b', priceIdr: 100000);

      final stateCheapest = MarketplaceState(
        listings: [listingA, listingB],
        sortBy: MarketplaceSort.cheapest,
      );

      expect(stateCheapest.filteredListings.first.id, 'b');

      final statePriciest = MarketplaceState(
        listings: [listingA, listingB],
        sortBy: MarketplaceSort.priciest,
      );

      expect(statePriciest.filteredListings.first.id, 'a');
    });
  });

  group('Widget Tests: Marketplace Screens (Anti-Overflow & 320dp)', () {
    testWidgets(
        'MarketplaceScreen builds grid on 320dp with fontScale 1.3 without error',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? errorDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceProvider.overrideWith(
              (ref) => FakeMarketplaceNotifier(
                ref,
                const MarketplaceState(
                  listings: [sampleListing],
                  isLoading: false,
                ),
              ),
            ),
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
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
              child: const MarketplaceScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      FlutterError.onError = oldHandler;

      expect(find.text('Pasar HoloDex'), findsOneWidget);
      expect(find.text('Charizard V'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(errorDetails, isNull);
    });

    testWidgets(
        'ListingDetailScreen builds and renders buyer balance on 320dp without error',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? errorDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
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
              child: const ListingDetailScreen(
                listingId: 'list-101',
                initialListing: sampleListing,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      FlutterError.onError = oldHandler;

      expect(find.text('Charizard V'), findsWidgets);
      expect(find.text('Pesan'), findsOneWidget);
      expect(find.text('@kolektor_jkt'), findsOneWidget);
      expect(errorDetails, isNull);
    });

    testWidgets(
        'ListingDetailScreen with reserved listing renders "Dipesan" disabled button',
        (tester) async {
      final reservedListing = sampleListing.copyWith(status: 'reserved');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: ListingDetailScreen(
              listingId: 'list-101',
              initialListing: reservedListing,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Dipesan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'TransactionHistoryScreen renders tabs and empty state without error',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
              ),
            ),
            userTransactionsProvider('user-buyer-1').overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const TransactionHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Pembelian Saya'), findsOneWidget);
      expect(find.text('Penjualan Saya'), findsOneWidget);
      expect(find.text('Belum Ada Pembelian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
