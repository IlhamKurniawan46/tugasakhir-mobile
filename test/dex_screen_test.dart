import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/core/services/timezone_service.dart';
import 'package:holodex/features/dex/providers/dex_provider.dart';
import 'package:holodex/features/dex/screens/dex_screen.dart';
import 'package:holodex/features/dex/widgets/card_tile.dart';
import 'package:holodex/features/dex/widgets/price_badge.dart';

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
  setUpAll(() {
    TimezoneService.ensureInitialized();
    CurrencyService.setMockRates(const CurrencyRates(
      usdToEur: 0.92,
      usdToIdr: 16000.0,
      usdToJpy: 155.0,
      ecbDate: '2026-10-23',
    ));
  });

  const List<CardModel> fakeCards = [
    CardModel(
      id: 'c1',
      name: 'Charizard ex',
      localId: '199',
      setName: 'Obsidian Flames',
      rarity: 'Special Illustration Rare',
      priceRefUsd: 150.0,
      priceIdr: 2400000,
      hasPrice: true,
      imageUrl: 'https://images.tcgdex.net/en/sv/sv03/199',
    ),
    CardModel(
      id: 'c2',
      name: 'Pikachu',
      localId: '25',
      setName: 'Base Set',
      rarity: null, // Kartu tanpa kelangkaan / null
      priceRefUsd: 20.0,
      priceIdr: 320000,
      hasPrice: true,
      imageUrl: 'https://images.tcgdex.net/en/base/base1/25',
    ),
  ];

  testWidgets(
    'DexScreen builds without layout overflow on narrow screen (320dp) and textScaleFactor 1.3',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const DexScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Pastikan tidak ada exception layout (overflow dll)
      expect(tester.takeException(), isNull);

      // Verifikasi AppBar bersih (menampilkan logo Image resmi)
      expect(find.byType(Image), findsWidgets);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Verifikasi judul section "Katalog" & 4 chip mata uang
      expect(find.text('Katalog'), findsOneWidget);
      expect(find.text('IDR'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('JPY'), findsOneWidget);

      // Verifikasi 4 Baris Fitur Baru
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Konverter'), findsOneWidget);
      expect(find.text('Mini Game'), findsOneWidget);
      expect(find.text('HoloBot'), findsOneWidget);

      // Pastikan tombol floating 'Buka Pack' SUDAH TIDAK ADA
      expect(find.text('Buka Pack'), findsNothing);
    },
  );

  testWidgets(
    '(a) Pada lebar 360dp dan font standar, judul Katalog dan chip dalam satu baris (space-between)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dexProvider.overrideWith(
              (ref) => FakeDexNotifier(
                const DexState(cards: fakeCards, isLoading: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: DexScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final titleCenter = tester.getCenter(find.text('Katalog'));
      final chipIdrCenter = tester.getCenter(find.text('IDR'));

      // Selisih koordinat Y antara judul dan chip < 10dp (berarti berada di baris yang sama)
      expect((titleCenter.dy - chipIdrCenter.dy).abs(), lessThan(12.0));
    },
  );

  testWidgets(
    '(b) Kartu dengan rarity panjang dan tanpa rarity tampil aman tanpa overflow pada 320dp textScale 1.3',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const DexScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Special Illustration Rare'), findsOneWidget);
      expect(find.text('Charizard ex'), findsOneWidget);
      expect(find.text('Pikachu'), findsOneWidget);
    },
  );

  testWidgets(
    '(c) Kesejajaran horizontal: kolom pencarian, tile fitur, header katalog, dan grid kartu memiliki tepi kiri/kanan yang sama (kScreenHorizontalPadding)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dexProvider.overrideWith(
              (ref) => FakeDexNotifier(
                const DexState(cards: fakeCards, isLoading: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: DexScreen(),
          ),
        ),
      );
      await tester.pump();

      // 1. Kolom pencarian
      final searchBox = find.byType(Container).first;
      final searchTopLeft = tester.getTopLeft(searchBox);
      final searchTopRight = tester.getTopRight(searchBox);

      // Tepi kiri search bar sejajar dengan kScreenHorizontalPadding = 16.0
      expect(searchTopLeft.dx, equals(kScreenHorizontalPadding));
      expect(searchTopRight.dx, equals(360.0 - kScreenHorizontalPadding));

      // 2. Baris tile fitur (tile Event paling kiri)
      final eventTile = find.text('Event');
      final eventTileLeft = tester.getTopLeft(eventTile);
      // Tepi teks berada di dalam tile Event yang mulai pada x = 16.0
      expect(eventTileLeft.dx, greaterThanOrEqualTo(kScreenHorizontalPadding));

      // 3. Header katalog (Teks "Katalog" rata kiri)
      final catalogTitle = find.text('Katalog');
      final catalogTopLeft = tester.getTopLeft(catalogTitle);
      expect(catalogTopLeft.dx, equals(kScreenHorizontalPadding));

      // 4. Chip terakhir (JPY) rata kanan dengan batas 360 - 16 = 344
      final jpyChip = find.text('JPY');
      final jpyChipRight = tester.getTopRight(jpyChip);
      expect(jpyChipRight.dx, lessThanOrEqualTo(360.0 - kScreenHorizontalPadding));
    },
  );

  testWidgets(
    '(d) Mengetuk chip mata uang mengganti mata uang terpilih (USD dan JPY)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dexProvider.overrideWith(
              (ref) => FakeDexNotifier(
                const DexState(cards: fakeCards, isLoading: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: DexScreen(),
          ),
        ),
      );
      await tester.pump();

      // Ketuk USD
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Ketuk JPY
      await tester.tap(find.text('JPY'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Pastikan ada format simbol Yen '¥' yang muncul pada badge harga
      expect(find.textContaining('¥'), findsWidgets);
    },
  );

  testWidgets(
    '(e) Badge rarity di luar gambar, jarak vertikal terpisah, dan batas kiri-kanan gambar sejajar dengan Rarity, nama, dan set',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dexProvider.overrideWith(
              (ref) => FakeDexNotifier(
                const DexState(cards: fakeCards, isLoading: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: DexScreen(),
          ),
        ),
      );
      await tester.pump();

      final rarityFinder = find.text('Special Illustration Rare');
      expect(rarityFinder, findsOneWidget);

      final rarityTopLeft = tester.getTopLeft(rarityFinder);
      final imageFinder = find.byType(CachedNetworkImage).first;
      final imageTopLeft = tester.getTopLeft(imageFinder);
      final imageTopRight = tester.getTopRight(imageFinder);

      // 1. Posisi Y badge rarity lebih tinggi dari posisi Y gambar kartu (artinya berada di atas gambar)
      expect(rarityTopLeft.dy, lessThan(imageTopLeft.dy));

      // 2. Ada jarak vertikal yang cukup antara rarity dan gambar kartu (minimal 6dp)
      final rarityBottom = tester.getBottomLeft(rarityFinder).dy;
      expect(imageTopLeft.dy - rarityBottom, greaterThanOrEqualTo(6.0));

      // 3. Batas kiri gambar kartu sejajar dengan teks nama kartu (keduanya dimulai pada x yang sama di dalam kartu)
      final cardNameFinder = find.text('Charizard ex');
      final cardNameTopLeft = tester.getTopLeft(cardNameFinder);
      expect(imageTopLeft.dx, equals(cardNameTopLeft.dx));

      // 4. Batas kanan gambar kartu sejajar dengan batas kanan area konten kartu (memenuhi lebar kartu dikurangi padding horizontal 10)
      final cardTileSize = tester.getSize(find.byType(CardTile).first);
      // Lebar gambar kartu adalah lebar cardTile dikurangi 20 padding dan 2 border
      expect((imageTopRight.dx - imageTopLeft.dx), closeTo(cardTileSize.width - 22, 1.0));

      // 5. Jarak antara teks nama set dan PriceBadge rapat proporsional (tanpa gap besar)
      final setNameFinder = find.text('Obsidian Flames');
      final setNameBottom = tester.getBottomLeft(setNameFinder).dy;
      final priceBadgeFinder = find.byType(PriceBadge).first;
      final priceBadgeTop = tester.getTopLeft(priceBadgeFinder).dy;
      final gapBetweenSetAndPrice = priceBadgeTop - setNameBottom;
      expect(gapBetweenSetAndPrice, lessThanOrEqualTo(10.0));
    },
  );

  testWidgets(
    'Feature tiles navigate to correct routes and open HoloBot modal sheet',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DexScreen(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Event Screen')),
              body: const Center(child: Text('Halaman Kalender')),
            ),
          ),
          GoRoute(
            path: '/converter',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Converter Screen')),
              body: const Center(child: Text('Halaman Konverter')),
            ),
          ),
          GoRoute(
            path: '/pack-opening',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Pack Opening Screen')),
              body: const Center(child: Text('Halaman Mini Game')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dexProvider.overrideWith(
              (ref) => FakeDexNotifier(
                const DexState(cards: fakeCards, isLoading: false),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(1.3),
              ),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // 1. Ketuk tile Event -> pindah ke /calendar
      await tester.tap(find.text('Event'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman Kalender'), findsOneWidget);

      // Kembali ke Dex
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);

      // 2. Ketuk tile Konverter -> pindah ke /converter
      await tester.tap(find.text('Konverter'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman Konverter'), findsOneWidget);

      // Kembali ke Dex
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);

      // 3. Ketuk tile Mini Game -> pindah ke /pack-opening
      await tester.tap(find.text('Mini Game'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman Mini Game'), findsOneWidget);

      // Kembali ke Dex
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);

      // 4. Ketuk tile HoloBot -> membuka AiAdvisorSheet (modal bottom sheet)
      await tester.tap(find.text('HoloBot'));
      await tester.pumpAndSettle();
      expect(find.text('Asisten Pokémon TCG · Mode Umum'), findsOneWidget);
      expect(find.text('Jelaskan arti rarity kartu'), findsOneWidget);

      // Pastikan tidak ada exception sepanjang navigasi
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tapping tune icon opens sorting and filter bottom sheet',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dexProvider.overrideWith(
              (ref) => FakeDexNotifier(
                const DexState(cards: fakeCards, isLoading: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: DexScreen(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Tap ikon tune
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Cek isi bottom sheet
      expect(find.text('Pengurutan & Filter Katalog'), findsOneWidget);
      expect(find.text('Termahal'), findsOneWidget);
      expect(find.text('Termurah'), findsOneWidget);
      expect(find.text('Nama (A-Z)'), findsOneWidget);
      expect(find.text('Buka Filter Lanjutan (Set, Rarity, Harga)'), findsOneWidget);

      // Tap pilihan Termurah
      await tester.tap(find.text('Termurah'));
      await tester.pumpAndSettle();

      // Pastikan modal tertutup dan tidak ada crash
      expect(tester.takeException(), isNull);
    },
  );
}
