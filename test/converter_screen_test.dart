import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/converter/screens/converter_screen.dart';
import 'package:holodex/shared/providers/currency_provider.dart';

class FakeCurrencyRatesNotifier extends CurrencyRatesNotifier {
  final CurrencyRates mockRates;
  FakeCurrencyRatesNotifier(this.mockRates) : super() {
    state = CurrencyRatesState(rates: mockRates, isLoading: false);
  }

  @override
  Future<void> init() async {
    state = CurrencyRatesState(rates: mockRates, isLoading: false);
  }

  @override
  Future<bool> refresh({bool force = false}) async => true;
}

const testMockRates = CurrencyRates(
  usdToEur: 0.9,
  usdToIdr: 18000.0,
  usdToJpy: 150.0,
  ecbDate: '2026-10-23',
);

void main() {
  setUpAll(() {
    CurrencyService.setMockRates(testMockRates);
  });

  testWidgets(
    'ConverterScreen: Ketika asal IDR, hasil menyertakan USD, EUR, dan JPY',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyRatesProvider.overrideWith(
              (ref) => FakeCurrencyRatesNotifier(testMockRates),
            ),
          ],
          child: const MaterialApp(
            home: ConverterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Pada default asal IDR, kartu hasil harus menampilkan USD, EUR, dan JPY
      expect(find.text('US Dollar (USD)'), findsOneWidget);
      expect(find.text('Euro (EUR)'), findsOneWidget);
      expect(find.text('Yen Jepang (JPY)'), findsOneWidget);
      expect(find.text('Rupiah (IDR)'), findsNothing); // Tidak muncul di kartu hasil karena merupakan asal
    },
  );

  testWidgets(
    'ConverterScreen: Ketika asal JPY, hasil menampilkan IDR, USD, dan EUR',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyRatesProvider.overrideWith(
              (ref) => FakeCurrencyRatesNotifier(testMockRates),
            ),
          ],
          child: const MaterialApp(
            home: ConverterScreen(initialCurrency: 'JPY'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hasil harus menampilkan tiga mata uang lainnya
      expect(find.text('Rupiah (IDR)'), findsOneWidget);
      expect(find.text('US Dollar (USD)'), findsOneWidget);
      expect(find.text('Euro (EUR)'), findsOneWidget);
      expect(find.text('Yen Jepang (JPY)'), findsNothing); // asal tidak ada di hasil

      // Quick chips untuk JPY harus berisi kelipatan ¥
      expect(find.text('+¥1rb'), findsOneWidget);
      expect(find.text('+¥5rb'), findsOneWidget);
      expect(find.text('+¥10rb'), findsOneWidget);
    },
  );

  testWidgets(
    'ConverterScreen: Bebas overflow pada layar 320dp dan textScaleFactor 1.3',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyRatesProvider.overrideWith(
              (ref) => FakeCurrencyRatesNotifier(testMockRates),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const ConverterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      if (exception != null && caughtDetails != null) {
        // ignore: avoid_print
        FlutterError.dumpErrorToConsole(caughtDetails!);
      }
      expect(exception, isNull);
    },
  );
}
