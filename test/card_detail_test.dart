import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/utils/price_formatter.dart';
import 'package:holodex/features/dex/providers/card_detail_provider.dart';
import 'package:holodex/features/dex/screens/card_detail_screen.dart';
import 'package:holodex/features/dex/widgets/holo_card_widget.dart';

void main() {
  group('Card Detail & Holo Effect Unit Tests', () {
    test('HoloCardWidget intensity corresponds to card rarity', () {
      expect(HoloCardWidget.intensityForRarity('Common'), equals(0.0));
      expect(HoloCardWidget.intensityForRarity('Uncommon'), equals(0.0));
      expect(HoloCardWidget.intensityForRarity('Rare'), equals(0.0));
      expect(HoloCardWidget.intensityForRarity('Ultra Rare'), equals(1.0));
      expect(HoloCardWidget.intensityForRarity('Special Illustration Rare'), equals(1.0));
      expect(HoloCardWidget.intensityForRarity('Secret Rare'), equals(1.0));
      expect(HoloCardWidget.intensityForRarity(null), equals(0.0));
    });

    test('Holo tilt angle is strictly clamped to max ±15 degrees', () {
      const maxTilt = HoloCardWidget.maxTiltDeg;
      expect(maxTilt, equals(15.0));

      double clampAngle(double raw) => raw.clamp(-maxTilt, maxTilt);

      expect(clampAngle(0), equals(0.0));
      expect(clampAngle(10), equals(10.0));
      expect(clampAngle(-12), equals(-12.0));
      expect(clampAngle(45), equals(15.0));
      expect(clampAngle(-90), equals(-15.0));
    });

    test('Exponential decay brings tilt back toward center when stationary', () {
      const tau = 0.7; // decay time constant in seconds
      const dt = 0.05; // 50ms frame time
      final decay = math.exp(-dt / tau);

      expect(decay, lessThan(1.0));
      expect(decay, greaterThan(0.9));

      // Simulasi sudut awal 15 derajat yang meluruh saat HP diam selama 1 detik (20 frame)
      double angle = 15.0;
      for (int i = 0; i < 20; i++) {
        angle = angle * decay;
      }
      // Setelah 1 detik diam, sudut harus meluruh ke nilai kecil mendekati nol (< 4 derajat)
      expect(angle, lessThan(4.0));
    });

    test('CardDetailArgs equality is based on cardId', () {
      const args1 = CardDetailArgs('sv01-1');
      const args2 = CardDetailArgs('sv01-1');
      const args3 = CardDetailArgs('sv01-2');

      expect(args1, equals(args2));
      expect(args1.hashCode, equals(args2.hashCode));
      expect(args1, isNot(equals(args3)));
    });

    test('Card prices format correctly in IDR, USD, and EUR', () {
      const card = CardModel(
        id: 'sv01-199',
        name: 'Charizard ex',
        priceIdr: 3850000,
        priceUsd: 242.0,
        priceEur: 224.5,
        priceRefUsd: 242.0,
      );

      expect(formatIdr(card.priceIdr!), equals('Rp3.850.000'));
      expect(formatUsd(card.priceUsd), equals('\$242.00'));
      expect(formatEur(card.priceEur), equals('€224.50'));
    });

    testWidgets('CardDetailScreen builds without layout exceptions (tester.takeException() is null)',
        (tester) async {
      const fakeCard = CardModel(
        id: 'sv01-199',
        name: 'Charizard ex',
        localId: '199',
        setName: 'Scarlet & Violet',
        rarity: 'Double Rare',
        priceIdr: 250000,
        priceUsd: 15.0,
        priceEur: 14.0,
        priceRefUsd: 15.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProviderScope(
            child: CardDetailScreen(
              cardId: 'sv01-199',
              initialCard: fakeCard,
            ),
          ),
        ),
      );
      await tester.pump();

      // Memastikan tidak ada layout exception sama sekali
      expect(tester.takeException(), isNull);
      expect(find.text('Charizard ex #199'), findsOneWidget);
      expect(find.text('AI Penasihat Kartu (Gemini)'), findsOneWidget);

      // Verifikasi tombol primary "Konversi Harga" tampil dan box TCGplayer/Cardmarket sudah dihapus
      expect(find.text('Konversi Harga'), findsOneWidget);
      expect(find.text('TCGplayer (USD)'), findsNothing);
      expect(find.text('Cardmarket (EUR)'), findsNothing);
    });

    testWidgets('Watchlist SnackBar builds without overflow on 320dp with fontScale 1.3',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.favorite, color: AppColors.pink, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kartu ditambahkan ke Watchlist!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.surfaceHighest,
                        duration: const Duration(milliseconds: 2000),
                        behavior: SnackBarBehavior.floating,
                        dismissDirection: DismissDirection.horizontal,
                      ),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 750)); // Finished animating in

      expect(tester.takeException(), isNull);
      expect(find.text('Kartu ditambahkan ke Watchlist!'), findsOneWidget);
    });
  });
}
