import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/app.dart';

void main() {
  testWidgets('HoloDex splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HoloDexApp(),
      ),
    );

    // Verifikasi bahwa aplikasi render dengan logo HoloDex di splash screen
    expect(find.text('HoloDex'), findsOneWidget);
    expect(find.text('Pokémon TCG Vault & Marketplace'), findsOneWidget);

    // Selesaikan timer splash screen
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
