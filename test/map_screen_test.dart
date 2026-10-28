import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/listing_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/marketplace/providers/map_provider.dart';
import 'package:holodex/features/marketplace/providers/marketplace_provider.dart';
import 'package:holodex/features/marketplace/screens/map_screen.dart';
import 'package:latlong2/latlong.dart';

class FakeMapNotifier extends MapNotifier {
  final MapState initialState;
  FakeMapNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> initUserLocation() async {}
}

class FakeMarketplaceNotifier extends MarketplaceNotifier {
  final MarketplaceState initialState;
  FakeMarketplaceNotifier(super.ref, this.initialState) {
    state = initialState;
  }

  @override
  Future<void> loadListings({bool forceRefresh = false}) async {}
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
    sellerId: 'user-200',
    sellerUsername: 'kolektor_bandung',
    cardId: 'swsh3-19',
    card: sampleCard,
    priceIdr: 250000,
    condition: 'near_mint',
    description: 'Koleksi pribadi mulus',
    lat: -6.9175,
    lng: 107.6191,
    status: 'active',
  );

  Widget createTestWidget({
    required Widget child,
    MapState? mapState,
    List<ListingModel>? listings,
    double textScale = 1.0,
    Size size = const Size(360, 640),
  }) {
    return ProviderScope(
      overrides: [
        mapStateProvider.overrideWith((ref) => FakeMapNotifier(
              mapState ??
                  const MapState(
                    userLocation: LatLng(-6.2088, 106.8456),
                  ),
            )),
        marketplaceProvider.overrideWith((ref) => FakeMarketplaceNotifier(
              ref,
              MarketplaceState(
                listings: listings ?? [sampleListing],
                isLoading: false,
              ),
            )),
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

  group('MapScreen Widget Tests (LBS & Anti-Overflow)', () {
    testWidgets('MapScreen renders AppBar, radius chips, and FAB on 320dp without error',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createTestWidget(
        child: const MapScreen(),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Verifikasi judul app bar
      expect(find.text('Peta Penjual Terdekat'), findsOneWidget);

      // Verifikasi filter radius chip
      expect(find.text('Semua Jarak'), findsOneWidget);
      expect(find.text('5 km'), findsOneWidget);
      expect(find.text('10 km'), findsOneWidget);

      // Verifikasi FAB my_location
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('MapScreen displays listing bottom card when listing is selected',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createTestWidget(
        child: const MapScreen(),
        mapState: const MapState(
          userLocation: LatLng(-6.2088, 106.8456),
          selectedListing: sampleListing,
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Verifikasi kartu info listing terpilih muncul
      expect(find.text('Charizard V'), findsOneWidget);
      expect(find.textContaining('kolektor_bandung'), findsOneWidget);
      expect(find.text('Lihat Detail Kartu'), findsOneWidget);
    });

    testWidgets('MapScreen shows info banner if GPS permission is denied',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createTestWidget(
        child: const MapScreen(),
        mapState: const MapState(
          userLocation: LatLng(-6.1754, 106.8272),
          locationErrorMessage:
              'Izin lokasi tidak diberikan. Menampilkan pusat Jakarta sebagai titik acuan.',
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Izin lokasi tidak diberikan'),
        findsOneWidget,
      );
    });

    testWidgets('MapScreen renders COD initialCenter and focusedListing pin on center of map',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      const codListing = ListingModel(
        id: 'order-listing-99',
        sellerId: 'user-seller-1',
        sellerUsername: 'penjual_bandung',
        cardId: 'swsh3-19',
        card: sampleCard,
        priceIdr: 250000,
        condition: 'near_mint',
        lat: -6.9175,
        lng: 107.6191,
        status: 'reserved',
      );

      await tester.pumpWidget(createTestWidget(
        child: const MapScreen(
          initialCenter: LatLng(-6.9175, 107.6191),
          initialZoom: 15.5,
          focusedListing: codListing,
          title: 'Titik COD Pesanan',
        ),
        size: const Size(320, 568),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      // Verifikasi judul kustom
      expect(find.text('Titik COD Pesanan'), findsOneWidget);

      // Verifikasi FAB Titik COD muncul
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);

      // Verifikasi marker handshake titik COD muncul
      expect(find.byIcon(Icons.handshake), findsWidgets);

      // Verifikasi bottom card listing otomatis muncul
      expect(find.text('Charizard V'), findsOneWidget);
    });
  });
}
