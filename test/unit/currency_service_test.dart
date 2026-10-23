import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/core/utils/price_formatter.dart';

void main() {
  group('CurrencyService Conversion Tests', () {
    const mockRates = CurrencyRates(
      usdToIdr: 18000.0,
      usdToEur: 0.9,
      usdToJpy: 150.0,
      ecbDate: '2026-10-19',
    );

    setUp(() {
      CurrencyService.setMockRates(mockRates);
    });

    test('USD to IDR and vice-versa conversion', () {
      final idr = CurrencyService.convert(10, from: 'USD', to: 'IDR');
      expect(idr, equals(180000.0));

      final usd = CurrencyService.convert(180000, from: 'IDR', to: 'USD');
      expect(usd, equals(10.0));
    });

    test('USD to EUR and vice-versa conversion', () {
      final eur = CurrencyService.convert(10, from: 'USD', to: 'EUR');
      expect(eur, equals(9.0));

      final usd = CurrencyService.convert(9, from: 'EUR', to: 'USD');
      expect(usd, closeTo(10.0, 0.0001));
    });

    test('USD to JPY and vice-versa conversion', () {
      final jpy = CurrencyService.convert(10, from: 'USD', to: 'JPY');
      expect(jpy, equals(1500.0));

      final usd = CurrencyService.convert(1500, from: 'JPY', to: 'USD');
      expect(usd, closeTo(10.0, 0.0001));
    });

    test('All-direction cross conversion involving JPY, EUR, and IDR', () {
      // 10 USD = 9 EUR = 180,000 IDR = 1,500 JPY
      // EUR to JPY & JPY to EUR
      final jpyFromEur = CurrencyService.convert(9, from: 'EUR', to: 'JPY');
      expect(jpyFromEur, closeTo(1500.0, 0.0001));

      final eurFromJpy = CurrencyService.convert(1500, from: 'JPY', to: 'EUR');
      expect(eurFromJpy, closeTo(9.0, 0.0001));

      // IDR to JPY & JPY to IDR
      final jpyFromIdr = CurrencyService.convert(180000, from: 'IDR', to: 'JPY');
      expect(jpyFromIdr, closeTo(1500.0, 0.0001));

      final idrFromJpy = CurrencyService.convert(1500, from: 'JPY', to: 'IDR');
      expect(idrFromJpy, closeTo(180000.0, 0.0001));

      // EUR to IDR & IDR to EUR
      final idrFromEur = CurrencyService.convert(9, from: 'EUR', to: 'IDR');
      expect(idrFromEur, closeTo(180000.0, 0.0001));

      final eurFromIdr = CurrencyService.convert(180000, from: 'IDR', to: 'EUR');
      expect(eurFromIdr, closeTo(9.0, 0.0001));
    });

    test('Cross consistency round-trip tolerance (USD -> JPY -> USD)', () {
      const initialUsd = 123.45;
      final jpy = CurrencyService.convert(initialUsd, from: 'USD', to: 'JPY')!;
      final backToUsd = CurrencyService.convert(jpy, from: 'JPY', to: 'USD')!;
      expect(backToUsd, closeTo(initialUsd, 0.0001));
    });

    test('Zero amount conversion returns zero', () {
      expect(CurrencyService.convert(0, from: 'USD', to: 'JPY'), equals(0.0));
      expect(CurrencyService.convert(0, from: 'JPY', to: 'IDR'), equals(0.0));
      expect(CurrencyService.convert(0, from: 'EUR', to: 'JPY'), equals(0.0));
    });

    test('Identical currency conversion returns exact value', () {
      expect(CurrencyService.convert(42.5, from: 'USD', to: 'USD'), equals(42.5));
      expect(CurrencyService.convert(50000, from: 'IDR', to: 'IDR'), equals(50000.0));
      expect(CurrencyService.convert(15.75, from: 'EUR', to: 'EUR'), equals(15.75));
      expect(CurrencyService.convert(2500, from: 'JPY', to: 'JPY'), equals(2500.0));
    });

    test('Missing rates returns null without fake numbers or zeros', () {
      CurrencyService.setMockRates(null);

      final result = CurrencyService.convert(100, from: 'USD', to: 'IDR');
      expect(result, isNull);
      expect(CurrencyService.hasRates, isFalse);
    });

    test('Legacy cache without JPY returns null for JPY and does not crash', () {
      const legacyRatesWithoutJpy = CurrencyRates(
        usdToIdr: 18000.0,
        usdToEur: 0.9,
        usdToJpy: null, // belum ada kurs JPY
        ecbDate: '2026-10-18',
      );
      CurrencyService.setMockRates(legacyRatesWithoutJpy);

      // USD & IDR tetap berfungsi
      expect(CurrencyService.convert(10, from: 'USD', to: 'IDR'), equals(180000.0));
      // JPY mengembalikan null, BUKAN 0 atau angka palsu
      expect(CurrencyService.convert(10, from: 'USD', to: 'JPY'), isNull);
      expect(CurrencyService.convert(1500, from: 'JPY', to: 'IDR'), isNull);
      expect(CurrencyService.getRate(from: 'USD', to: 'JPY'), isNull);
    });

    test('getRate returns unit exchange rate', () {
      expect(CurrencyService.getRate(from: 'USD', to: 'IDR'), equals(18000.0));
      expect(CurrencyService.getRate(from: 'USD', to: 'EUR'), equals(0.9));
      expect(CurrencyService.getRate(from: 'USD', to: 'JPY'), equals(150.0));
      expect(CurrencyService.getRate(from: 'EUR', to: 'IDR'), closeTo(20000.0, 0.001));
      expect(CurrencyService.getRate(from: 'EUR', to: 'JPY'), closeTo(166.6666, 0.001));
    });
  });

  group('PriceFormatter Tests', () {
    test('Format IDR without decimals and Indonesian style separator', () {
      expect(PriceFormatter.format(18043, 'IDR'), equals('Rp18.043'));
      expect(PriceFormatter.format(1000000, 'IDR'), equals('Rp1.000.000'));
      expect(PriceFormatter.format(500, 'IDR'), equals('Rp500'));
    });

    test('Format USD with 2 decimal places', () {
      expect(PriceFormatter.format(24.5, 'USD'), equals(r'$24.50'));
      expect(PriceFormatter.format(100, 'USD'), equals(r'$100.00'));
      expect(PriceFormatter.format(0.75, 'USD'), equals(r'$0.75'));
    });

    test('Format EUR with 2 decimal places', () {
      expect(PriceFormatter.format(18.2, 'EUR'), equals('€18.20'));
      expect(PriceFormatter.format(9, 'EUR'), equals('€9.00'));
    });

    test('Format JPY without decimals with ¥ symbol and proper grouping', () {
      expect(PriceFormatter.format(1500, 'JPY'), equals('¥1,500'));
      expect(PriceFormatter.format(25000, 'JPY'), equals('¥25,000'));
      expect(PriceFormatter.format(42.8, 'JPY'), equals('¥43')); // pembulatan wajar
      expect(PriceFormatter.formatJpy(1234567), equals('¥1,234,567'));
    });

    test('Null value returns "-" placeholder', () {
      expect(PriceFormatter.format(null, 'IDR'), equals('-'));
      expect(PriceFormatter.format(null, 'USD'), equals('-'));
      expect(PriceFormatter.format(null, 'EUR'), equals('-'));
      expect(PriceFormatter.format(null, 'JPY'), equals('-'));
    });
  });
}
