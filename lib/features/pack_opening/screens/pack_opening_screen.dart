import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../providers/pack_provider.dart';
import '../widgets/booster_pack_art.dart';
import '../widgets/card_reveal_widget.dart';

class PackOpeningScreen extends ConsumerStatefulWidget {
  const PackOpeningScreen({super.key});

  @override
  ConsumerState<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends ConsumerState<PackOpeningScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(packProvider.notifier).startListeningToSensors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final packState = ref.watch(packProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buka Booster Pack'),
        actions: [
          // Pilihan Set Booster Pack
          PopupMenuButton<String?>(
            icon: const Icon(Icons.style_outlined, color: AppColors.gold),
            tooltip: 'Pilih Set Booster',
            initialValue: packState.selectedSetId,
            onSelected: (setId) {
              ref.read(packProvider.notifier).changeSet(setId);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('Semua Set (Acak Campuran)'),
              ),
              const PopupMenuItem(
                value: 'swsh7',
                child: Text('Evolving Skies (swsh7)'),
              ),
              const PopupMenuItem(
                value: 'swsh3',
                child: Text('Darkness Ablaze (swsh3)'),
              ),
              const PopupMenuItem(
                value: 'sv01',
                child: Text('Scarlet & Violet (sv01)'),
              ),
              const PopupMenuItem(
                value: 'sv05',
                child: Text('Temporal Forces (sv05)'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Mini: Rekor Tarikan Tertinggi (Best Pull Record)
            _buildRecordHeader(context, packState.bestPullValueIdr),

            // Konten Utama Berdasarkan State Pack
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SingleChildScrollView(
                    child: _buildStageContent(context, packState),
                  ),
                ),
              ),
            ),

            // Bottom Action Bar Dinamis
            _buildBottomActionBar(context, packState),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordHeader(BuildContext context, double bestPullIdr) {
    final selectedCurrency = ref.watch(currencyProvider);
    String bestText = 'Rp0';
    if (bestPullIdr > 0) {
      if (selectedCurrency == AppCurrency.idr) {
        bestText = PriceFormatter.formatIdr(bestPullIdr);
      } else {
        final converted = CurrencyService.convert(
          bestPullIdr,
          from: 'IDR',
          to: selectedCurrency.code,
        );
        bestText = converted != null
            ? PriceFormatter.format(converted, selectedCurrency.code)
            : PriceFormatter.formatIdr(bestPullIdr);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceLow,
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppColors.gold, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Rekor Pull Terbaik:',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            bestText,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent(BuildContext context, PackState packState) {
    switch (packState.stage) {
      case PackStage.sealed:
      case PackStage.shaking:
      case PackStage.opening:
        return _buildSealedView(context, packState);

      case PackStage.revealing:
        return _buildRevealingView(context, packState);

      case PackStage.completed:
        return _buildCompletedView(context, packState);
    }
  }

  // Tampilan Pack Tertutup (Sealed View)
  Widget _buildSealedView(BuildContext context, PackState packState) {
    final accel = packState.currentAcceleration;
    final accelPercent = (accel / PackNotifier.shakeThreshold).clamp(0.0, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        // Booster Pack Artwork Interaktif
        BoosterPackArt(
          setId: packState.selectedSetId,
          currentAcceleration: accel,
          isOpening: packState.stage == PackStage.opening,
          onTap: () {
            ref.read(packProvider.notifier).openPack();
          },
        ),
        const SizedBox(height: 24),

        // Indikator Shake Meter Accelerometer
        Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceHigh),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Shake Meter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${accel.toStringAsFixed(1)} m/s²',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: accelPercent,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accelPercent >= 1.0 ? Colors.greenAccent : AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Text(
          'Goyangkan HP dengan kuat atau tekan pack',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  // Tampilan Buka Kartu Satu per Satu (Revealing View)
  Widget _buildRevealingView(BuildContext context, PackState packState) {
    if (packState.cards.isEmpty) {
      return const CircularProgressIndicator();
    }

    final currentIndex = packState.currentRevealIndex;
    final currentCard = packState.cards[currentIndex];
    final isRevealed = packState.revealedIndices.contains(currentIndex);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Indikator Kartu Ke-X
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceHigh),
          ),
          child: Text(
            'KARTU ${currentIndex + 1} DARI ${packState.cards.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: AppColors.gold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Flip Card Widget 3D
        CardRevealWidget(
          card: currentCard,
          isRevealed: isRevealed,
          onTap: () {
            ref.read(packProvider.notifier).revealNextCard();
          },
        ),
        const SizedBox(height: 12),

        const Text(
          'Ketuk kartu untuk membuka kartu berikutnya',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Tampilan Ringkasan Selesai (Completed Summary View)
  Widget _buildCompletedView(BuildContext context, PackState packState) {
    final selectedCurrency = ref.watch(currencyProvider);
    final totalIdr = packState.totalPullValueIdr;

    String totalText;
    if (selectedCurrency == AppCurrency.idr) {
      totalText = PriceFormatter.formatIdr(totalIdr);
    } else {
      final converted = CurrencyService.convert(
        totalIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      totalText = converted != null
          ? PriceFormatter.format(converted, selectedCurrency.code)
          : PriceFormatter.formatIdr(totalIdr);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (packState.isNewRecord)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.stars, color: Colors.black, size: 16),
                SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'REKOR PULL BARU!',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Ringkasan Total Nilai Tarikan
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold),
          ),
          child: Column(
            children: [
              const Text(
                'TOTAL PULL VALUE:',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalText,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daftar 5 Kartu Hasil Tarikan
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '5 Kartu yang Didapat:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: packState.cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final card = packState.cards[index];
              return _buildSummaryCardItem(card);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCardItem(CardModel card) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: card.lowResImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: card.lowResImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Container(color: AppColors.surfaceHigh),
                    )
                  : Container(color: AppColors.surfaceHigh),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  PriceFormatter.formatIdr(card.priceIdr),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bar Aksi Bawah Dinamis
  Widget _buildBottomActionBar(BuildContext context, PackState packState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceHigh)),
      ),
      child: SafeArea(
        top: false,
        child: _buildActionButtonsForStage(context, packState),
      ),
    );
  }

  Widget _buildActionButtonsForStage(
      BuildContext context, PackState packState) {
    switch (packState.stage) {
      case PackStage.sealed:
      case PackStage.shaking:
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.catching_pokemon, size: 20),
            label: const Text(
              'Buka Pack Sekarang',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            onPressed: () {
              ref.read(packProvider.notifier).openPack();
            },
          ),
        );

      case PackStage.opening:
        return const SizedBox(
          height: 44,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Membuka Booster Pack...',
                  style: TextStyle(fontSize: 13, color: AppColors.gold),
                ),
              ],
            ),
          ),
        );

      case PackStage.revealing:
        final isLast = packState.currentRevealIndex >= packState.cards.length - 1;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  side: const BorderSide(color: AppColors.surfaceHigh),
                ),
                onPressed: () {
                  ref.read(packProvider.notifier).revealAllCards();
                },
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Buka Semua (Skip)'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  ref.read(packProvider.notifier).revealNextCard();
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isLast ? 'Lihat Hasil' : 'Buka Selanjutnya',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        );

      case PackStage.completed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.surfaceHigh),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Selesai'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.replay, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Buka Pack Lagi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                onPressed: () {
                  ref.read(packProvider.notifier).resetPack();
                },
              ),
            ),
          ],
        );
    }
  }
}
