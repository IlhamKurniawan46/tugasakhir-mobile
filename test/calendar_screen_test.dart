import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/timezone_service.dart';
import 'package:holodex/features/converter/screens/calendar_screen.dart';

void main() {
  setUpAll(() {
    TimezoneService.ensureInitialized();
  });

  testWidgets(
    'CalendarScreen builds without layout overflow on narrow screen (320dp) and textScaleFactor 1.3',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 840);
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
                size: Size(320, 840),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const CalendarScreen(),
            ),
          ),
        ),
      );

      // Pastikan tidak ada exception layout (overflow dll)
      expect(tester.takeException(), isNull);

      // Cek AppBar judul baru yang ringkas
      expect(find.text('Kalender Event'), findsOneWidget);

      // Pastikan icon jam bertanda plus (more_time) sudah dihapus dari AppBar
      expect(find.byIcon(Icons.more_time), findsNothing);

      // Cek tombol refresh tetap ada
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Cek keberadaan jam 4 zona waktu (Grid 2x2)
      expect(find.text('Jam Digital 4 Zona Waktu (Live)'), findsOneWidget);
      expect(find.text('WIB'), findsWidgets);
      expect(find.text('WITA'), findsWidgets);
      expect(find.text('WIT'), findsWidgets);
      expect(find.text('LDN'), findsWidgets);

      // Cek Hero Countdown
      expect(find.text('HARI'), findsOneWidget);
      expect(find.text('JAM'), findsOneWidget);
      expect(find.text('MENIT'), findsOneWidget);
      expect(find.text('DETIK'), findsOneWidget);

      // Cek Timeline Agenda & Filter Chips horizontal scrollable
      expect(find.text('Timeline Agenda'), findsOneWidget);
      expect(find.text('Semua Event'), findsOneWidget);
      expect(find.text('Rilis Set'), findsOneWidget);
      expect(find.text('Turnamen'), findsOneWidget);

      // Cek Kartu Kalkulator Selisih Jam
      expect(find.text('Kalkulator Selisih Waktu 4 Zona'), findsOneWidget);
      expect(find.text('Konversi jam antar WIB, WITA, WIT, dan London'), findsOneWidget);

      // Pastikan tombol 'Ingatkan Saya' SUDAH TIDAK ADA (sesuai instruksi Sesi 14)
      expect(find.text('Ingatkan Saya'), findsNothing);

      // Pastikan TIDAK ADA kata Demo Day di tampilan
      expect(find.textContaining('Demo Day'), findsNothing);
    },
  );
}
