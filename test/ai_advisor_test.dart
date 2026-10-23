import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/features/ai/widgets/ai_advisor_sheet.dart';

void main() {
  final dummyCard = CardModel(
    id: 'sv01-198',
    name: 'Miraidon ex',
    setName: 'Scarlet & Violet',
    setId: 'sv01',
    localId: '198',
    rarity: 'Special Illustration Rare',
    cardType: 'Pokémon',
    priceIdr: 450000,
    priceUsd: 30.0,
    priceEur: 28.0,
  );

  Widget createTestWidget({double textScale = 1.0}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => AiAdvisorSheet.show(context, dummyCard),
                child: const Text('Buka HoloBot'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('AiAdvisorSheet Widget Tests', () {
    testWidgets('Menampilkan header HoloBot, disclaimer dan chip pertanyaan',
        (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tekan tombol untuk membuka bottom sheet
      await tester.tap(find.text('Buka HoloBot'));
      await tester.pumpAndSettle();

      // Cek judul dan nama kartu
      expect(find.text('HoloBot — AI Penasihat Kartu'), findsOneWidget);
      expect(find.textContaining('Miraidon ex'), findsWidgets);

      // Cek disclaimer finansial wajib
      expect(
        find.textContaining('Bukan nasihat keuangan'),
        findsOneWidget,
      );

      // Cek quick prompts chips
      expect(
        find.text('Apakah harga pasar saat ini wajar?'),
        findsOneWidget,
      );
      expect(
        find.text('Layak disimpan untuk koleksi atau dijual?'),
        findsOneWidget,
      );

      // Cek text field input
      expect(
        find.byType(TextField),
        findsOneWidget,
      );
    });

    testWidgets('Bebas dari overflow pada layar 320dp dan font scale 1.3',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(textScale: 1.3));

      await tester.tap(find.text('Buka HoloBot'));
      await tester.pumpAndSettle();

      // Tidak ada overflow exception
      expect(tester.takeException(), isNull);
      expect(find.text('HoloBot — AI Penasihat Kartu'), findsOneWidget);
    });
  });
}
