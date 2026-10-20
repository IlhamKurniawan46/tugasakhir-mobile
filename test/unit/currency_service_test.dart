import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/core/utils/price_formatter.dart';

void main() {
  group('CurrencyService Conversion Tests', () {
    const mockRates = CurrencyRates(
      usdToIdr: 18000.0,
      usdToEur: 0.9,
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

    test('Cross conversion EUR to IDR and IDR to EUR', () {
      // 9 EUR = 10 USD = 180,000 IDR
      final idr = CurrencyService.convert(9, from: 'EUR', to: 'IDR');
      expect(idr, closeTo(180000.0, 0.0001));

      final eur = CurrencyService.convert(180000, from: 'IDR', to: 'EUR');
      expect(eur, closeTo(9.0, 0.0001));
    });

    test('Identical currency conversion returns exact value', () {
      expect(CurrencyService.convert(42.5, from: 'USD', to: 'USD'), equals(42.5));
      expect(CurrencyService.convert(50000, from: 'IDR', to: 'IDR'), equals(50000.0));
      expect(CurrencyService.convert(15.75, from: 'EUR', to: 'EUR'), equals(15.75));
    });

    test('Missing rates returns null without fake numbers or zeros', () {
      CurrencyService.setMockRates(null);

      final result = CurrencyService.convert(100, from: 'USD', to: 'IDR');
      expect(result, isNull);
      expect(CurrencyService.hasRates, isFalse);
    });

    test('getRate returns unit exchange rate', () {
      expect(CurrencyService.getRate(from: 'USD', to: 'IDR'), equals(18000.0));
      expect(CurrencyService.getRate(from: 'USD', to: 'EUR'), equals(0.9));
      expect(CurrencyService.getRate(from: 'EUR', to: 'IDR'), closeTo(20000.0, 0.001));
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

    test('Null value returns "-" placeholder', () {
      expect(PriceFormatter.format(null, 'IDR'), equals('-'));
      expect(PriceFormatter.format(null, 'USD'), equals('-'));
      expect(PriceFormatter.format(null, 'EUR'), equals('-'));
    });
  });
}
