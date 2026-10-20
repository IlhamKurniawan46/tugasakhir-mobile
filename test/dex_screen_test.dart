import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

      // Verifikasi komponen utama di AppBar & Header
      expect(find.text('HoloDex'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Verifikasi chip mata uang & konverter
      expect(find.text('IDR'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('Konverter'), findsOneWidget);

      // Pastikan chip Event SUDAH TIDAK ADA di baris chip
      expect(find.text('Event'), findsNothing);
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
