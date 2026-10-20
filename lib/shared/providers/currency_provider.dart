import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/card_model.dart';
import '../../core/services/currency_service.dart';
import '../../core/utils/price_formatter.dart';

/// 3 mata uang utama yang didukung HoloDex.
enum AppCurrency {
  idr('IDR', 'Rp', 'Rupiah (IDR)'),
  usd('USD', r'$', 'US Dollar (USD)'),
  eur('EUR', '€', 'Euro (EUR)');

  final String code;
  final String symbol;
  final String label;

  const AppCurrency(this.code, this.symbol, this.label);

  static AppCurrency fromCode(String? code) {
    if (code == null) return AppCurrency.idr;
    final upper = code.trim().toUpperCase();
    for (final c in AppCurrency.values) {
      if (c.code == upper) return c;
    }
    return AppCurrency.idr;
  }
}

/// Notifier untuk mengelola mata uang global aplikasi yang persisten.
class CurrencyNotifier extends StateNotifier<AppCurrency> {
  static const String _kStorageKey = 'holodex_selected_currency';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  CurrencyNotifier() : super(AppCurrency.idr) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final savedCode = await _storage.read(key: _kStorageKey);
      if (savedCode != null && savedCode.isNotEmpty) {
        state = AppCurrency.fromCode(savedCode);
      }
    } catch (_) {
      // Default to IDR jika secure storage belum siap
    }
  }

  Future<void> setCurrency(AppCurrency newCurrency) async {
    if (state == newCurrency) return;
    state = newCurrency;
    try {
      await _storage.write(key: _kStorageKey, value: newCurrency.code);
    } catch (_) {}
  }
}

/// Provider preferensi mata uang global (default: IDR)
final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, AppCurrency>((ref) {
  return CurrencyNotifier();
});

/// State untuk kurs live dan status refresh
class CurrencyRatesState {
  final CurrencyRates? rates;
  final bool isLoading;
  final String? errorMessage;

  const CurrencyRatesState({
    this.rates,
    this.isLoading = false,
    this.errorMessage,
  });

  CurrencyRatesState copyWith({
    CurrencyRates? rates,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CurrencyRatesState(
      rates: rates ?? this.rates,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CurrencyRatesNotifier extends StateNotifier<CurrencyRatesState> {
  CurrencyRatesNotifier()
      : super(CurrencyRatesState(rates: CurrencyService.currentRates)) {
    init();
  }

  Future<void> init() async {
    if (!CurrencyService.isInitialized) {
      state = state.copyWith(isLoading: true);
      await CurrencyService.initRates();
    }
    state = state.copyWith(
      rates: CurrencyService.currentRates,
      isLoading: false,
    );
  }

  Future<bool> refresh({bool force = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final success = await CurrencyService.refreshRates(force: force);
      state = state.copyWith(
        rates: CurrencyService.currentRates,
        isLoading: false,
        errorMessage: success ? null : 'Gagal memuat kurs online terbaru',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

/// Provider kurs nilai tukar live dan status sinkronisasi
final currencyRatesProvider =
    StateNotifierProvider<CurrencyRatesNotifier, CurrencyRatesState>((ref) {
  return CurrencyRatesNotifier();
});

/// Helper terpusat untuk kalkulasi dan format harga kartu Pokémon
class CardPriceCalculator {
  /// Mengonversi harga acuan kartu ke mata uang target.
  /// Mengutamakan `priceRefUsd` (USD) lalu dikonversi secara live.
  static double? getConvertedPrice(CardModel card, AppCurrency targetCurrency) {
    if (card.priceRefUsd != null) {
      final converted = CurrencyService.convert(
        card.priceRefUsd!,
        from: 'USD',
        to: targetCurrency.code,
      );
      if (converted != null) return converted;
    }

    // Fallback jika priceRefUsd null atau kurs gagal dimuat
    switch (targetCurrency) {
      case AppCurrency.idr:
        return card.priceIdr;
      case AppCurrency.usd:
        return card.priceUsd ?? card.priceRefUsd;
      case AppCurrency.eur:
        return card.priceEur;
    }
  }

  /// Format harga terkonversi kartu menjadi teks siap tampil.
  static String formatCardPrice(CardModel card, AppCurrency targetCurrency) {
    final price = getConvertedPrice(card, targetCurrency);
    if (price == null || price <= 0) return '-';
    return PriceFormatter.format(price, targetCurrency.code);
  }
}
