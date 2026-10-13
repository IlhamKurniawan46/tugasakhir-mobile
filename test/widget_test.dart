import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app.dart';

void main() {
  testWidgets('HoloDex auth smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HoloDexApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi bahwa aplikasi render dengan layar login
    expect(find.text('HoloDex'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
  });
}
