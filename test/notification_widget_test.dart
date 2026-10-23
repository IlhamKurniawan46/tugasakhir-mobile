import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/features/converter/screens/calendar_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
  });

  Widget buildCalendarScreen({double textScale = 1.0}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const CalendarScreen(),
        ),
      ),
    );
  }

  group('Notification Widget Tests (Calendar Screen & Anti-Overflow)', () {
    testWidgets('Menampilkan tombol pengingat notifikasi pada event kalender',
        (tester) async {
      await tester.pumpWidget(buildCalendarScreen());
      await tester.pumpAndSettle();

      // Tombol pengingat hero card
      expect(find.text('Pasang Pengingat Notifikasi'), findsOneWidget);

      // Scroll hingga event card dengan tombol 'Ingatkan Saya' terlihat
      await tester.scrollUntilVisible(
        find.text('Ingatkan Saya'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ingatkan Saya'), findsWidgets);
    });

    testWidgets('Membuka bottom sheet pengingat dan opsi simulasi demo',
        (tester) async {
      await tester.pumpWidget(buildCalendarScreen());
      await tester.pumpAndSettle();

      // Ketuk tombol pengingat hero
      final reminderButton = find.text('Pasang Pengingat Notifikasi');
      await tester.tap(reminderButton);
      await tester.pumpAndSettle();

      // Bottom sheet opsi notifikasi muncul
      expect(find.text('Pengingat Rilis Pokémon'), findsOneWidget);
      expect(find.text('Jadwalkan Pengingat Rilis'), findsOneWidget);
      expect(find.text('Tes Notifikasi Sekarang (Simulasi 5 Detik)'), findsOneWidget);
      expect(find.text('Batalkan Pengingat Event Ini'), findsOneWidget);
    });

    testWidgets('Bebas dari overflow pada layar 320dp dan font scale 1.3',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildCalendarScreen(textScale: 1.3));
      await tester.pumpAndSettle();

      // Buka sheet opsi
      final reminderButton = find.text('Pasang Pengingat Notifikasi');
      await tester.tap(reminderButton);
      await tester.pumpAndSettle();

      // Pastikan tidak ada exception overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Pengingat Rilis Pokémon'), findsOneWidget);
    });
  });
}
