import 'package:intl/intl.dart';

/// Formatter harga terpusat untuk katalog dan marketplace HoloDex.
/// Mendukung format baku IDR (tanpa desimal), USD (2 desimal), dan EUR (2 desimal)
/// menggunakan package `intl`.
class PriceFormatter {
  static final NumberFormat _idrFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static final NumberFormat _usdFormatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final NumberFormat _eurNumberFormatter = NumberFormat(
    '#,##0.00',
    'en_US',
  );

  /// Format angka sesuai kode mata uang ('IDR', 'USD', 'EUR').
  /// Mengembalikan '-' jika nilainya null.
  static String format(
    num? value,
    String currency, {
    bool showSymbol = true,
  }) {
    if (value == null) return '-';

    final cleanCurrency = currency.trim().toUpperCase();

    switch (cleanCurrency) {
      case 'IDR':
        final formatted = _idrFormatter.format(value.round());
        if (!showSymbol) {
          return formatted.replaceFirst('Rp', '').trim();
        }
        return formatted;

      case 'USD':
        final formatted = _usdFormatter.format(value);
        if (!showSymbol) {
          return formatted.replaceFirst(r'$', '').trim();
        }
        return formatted;

      case 'EUR':
        final formatted = _eurNumberFormatter.format(value);
        return showSymbol ? '€$formatted' : formatted;

      default:
        return value.toStringAsFixed(2);
    }
  }
}

/// Format angka ke Rupiah tanpa desimal, contoh: 100000 -> "Rp100.000".
String formatIdr(num? value) {
  return PriceFormatter.format(value, 'IDR');
}

/// Format angka ke USD dengan 2 desimal, contoh: 24.5 -> "$24.50".
String formatUsd(num? value) {
  return PriceFormatter.format(value, 'USD');
}

/// Format angka ke EUR dengan 2 desimal, contoh: 18.2 -> "€18.20".
String formatEur(num? value) {
  return PriceFormatter.format(value, 'EUR');
}
