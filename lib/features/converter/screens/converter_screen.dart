import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';

/// Halaman Konverter Mata Uang multi-arah (USD <-> EUR <-> IDR)
/// dengan data kurs resmi ECB via Frankfurter API dan cache SQLite 24 jam.
class ConverterScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialCurrency;
  final String? cardName;

  const ConverterScreen({
    super.key,
    this.initialAmount,
    this.initialCurrency,
    this.cardName,
  });

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  late TextEditingController _amountController;
  late AppCurrency _sourceCurrency;

  @override
  void initState() {
    super.initState();
    _sourceCurrency = AppCurrency.fromCode(widget.initialCurrency);

    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      // Format desimal bersih
      final initialVal = widget.initialAmount!;
      final str = initialVal == initialVal.roundToDouble()
          ? initialVal.toInt().toString()
          : initialVal.toStringAsFixed(2);
      _amountController = TextEditingController(text: str);
    } else {
      _amountController = TextEditingController(text: '10');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _currentAmount {
    final text = _amountController.text.replaceAll(',', '.').trim();
    return double.tryParse(text) ?? 0.0;
  }

  void _addAmount(double delta) {
    final cur = _currentAmount;
    final next = (cur + delta).clamp(0.0, 10000000000.0);
    setState(() {
      _amountController.text = next == next.roundToDouble()
          ? next.toInt().toString()
          : next.toStringAsFixed(2);
    });
  }

  void _clearAmount() {
    setState(() {
      _amountController.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratesState = ref.watch(currencyRatesProvider);
    final rates = ratesState.rates;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konverter Mata Uang'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.surfaceHigh),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          IconButton(
            icon: ratesState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.gold),
            tooltip: 'Perbarui Kurs',
            onPressed: ratesState.isLoading
                ? null
                : () async {
                    final success = await ref
                        .read(currencyRatesProvider.notifier)
                        .refresh(force: true);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Kurs berhasil diperbarui dari Frankfurter (ECB).'
                              : 'Gagal memperbarui kurs online. Menggunakan cache.',
                        ),
                        backgroundColor:
                            success ? AppColors.surfaceHigh : AppColors.error,
                      ),
                    );
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner kartu jika dibuka dari Detail Kartu
            if (widget.cardName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.style_outlined, color: AppColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Konversi Harga: ${widget.cardName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Kotak Input Nominal Asal
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nominal Asal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      // Pilihan Mata Uang Asal (tanpa box/background terpisah)
                      DropdownButtonHideUnderline(
                        child: DropdownButton<AppCurrency>(
                          value: _sourceCurrency,
                          isDense: true,
                          dropdownColor: AppColors.surface,
                          items: AppCurrency.values.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.symbol} ${c.code}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.gold,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newCurrency) {
                            if (newCurrency != null) {
                              setState(() {
                                _sourceCurrency = newCurrency;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Simbol mata uang & input angka langsung dalam satu baris tanpa box ganda
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _sourceCurrency.symbol,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -0.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chip Penambah Nominal Cepat
                  _buildQuickChips(_sourceCurrency),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Hasil Konversi Instan ke 2 Mata Uang Lainnya
            if (rates == null || !CurrencyService.hasRates) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 40, color: AppColors.error),
                    const SizedBox(height: 10),
                    const Text(
                      'Data Kurs Belum Tersedia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Silakan sambungkan perangkat ke internet dan tekan tombol perbarui untuk memuat kurs ECB pertama kali.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.onGold,
                      ),
                      onPressed: () =>
                          ref.read(currencyRatesProvider.notifier).refresh(force: true),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Muat Kurs Sekarang'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'HASIL KONVERSI INSTAN',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.outline,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),

              // Render hasil ke 2 mata uang target
              ...AppCurrency.values
                  .where((c) => c != _sourceCurrency)
                  .map((targetCurrency) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildResultCard(
                    source: _sourceCurrency,
                    target: targetCurrency,
                    amount: _currentAmount,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChips(AppCurrency currency) {
    List<double> increments;
    switch (currency) {
      case AppCurrency.usd:
      case AppCurrency.eur:
        increments = [1, 5, 10, 25, 50, 100];
        break;
      case AppCurrency.idr:
        increments = [10000, 50000, 100000, 500000, 1000000];
        break;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...increments.map((val) {
            String label;
            if (currency == AppCurrency.idr) {
              if (val >= 1000000) {
                label = '+${(val / 1000000).toInt()}jt';
              } else {
                label = '+${(val / 1000).toInt()}rb';
              }
            } else {
              label = '+${currency.symbol}${val.toInt()}';
            }

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text(label),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                backgroundColor: AppColors.surfaceLowest,
                side: const BorderSide(color: AppColors.surfaceHigh),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                visualDensity: VisualDensity.compact,
                onPressed: () => _addAmount(val),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              label: const Text('Reset'),
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.outline,
              ),
              backgroundColor: AppColors.surfaceLowest,
              side: const BorderSide(color: AppColors.surfaceHigh),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              visualDensity: VisualDensity.compact,
              onPressed: _clearAmount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required AppCurrency source,
    required AppCurrency target,
    required double amount,
  }) {
    final converted = CurrencyService.convert(
      amount,
      from: source.code,
      to: target.code,
    );
    final unitRate = CurrencyService.getRate(
      from: source.code,
      to: target.code,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                target.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Text(
                  target.code,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            converted != null ? PriceFormatter.format(converted, target.code) : '-',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (unitRate != null)
            Text(
              'Nilai Kurs: 1 ${source.code} = ${PriceFormatter.format(unitRate, target.code)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
