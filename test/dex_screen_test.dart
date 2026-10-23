import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holodex/core/services/timezone_service.dart';
import 'package:holodex/features/dex/screens/dex_screen.dart';

void main() {
  setUpAll(() {
    TimezoneService.ensureInitialized();
  });

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

      // Pastikan tidak ada exception layout (overflow dll)
      expect(tester.takeException(), isNull);

      // Verifikasi AppBar bersih (hanya judul, tanpa tombol aksi kalender)
      expect(find.text('HoloDex'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Verifikasi judul section & chip mata uang
      expect(find.text('Katalog dan Daftar Harga'), findsOneWidget);
      expect(find.text('IDR'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);

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
      expect(find.text('HoloDex'), findsOneWidget);

      // 2. Ketuk tile Konverter -> pindah ke /converter
      await tester.tap(find.text('Konverter'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman Konverter'), findsOneWidget);

      // Kembali ke Dex
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('HoloDex'), findsOneWidget);

      // 3. Ketuk tile Mini Game -> pindah ke /pack-opening
      await tester.tap(find.text('Mini Game'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman Mini Game'), findsOneWidget);

      // Kembali ke Dex
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('HoloDex'), findsOneWidget);

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
        const ProviderScope(
          child: MaterialApp(
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
