import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../providers/card_detail_provider.dart';
import '../widgets/holo_card_widget.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  final CardModel? initialCard;

  const CardDetailScreen({
    super.key,
    required this.cardId,
    this.initialCard,
  });

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  CardDetailArgs get _args => CardDetailArgs(widget.cardId, widget.initialCard);

  void _handleCollectionToggle() async {
    final notifier = ref.read(cardDetailProvider(_args).notifier);
    final result = await notifier.toggleCollection();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    switch (result) {
      case ToggleResult.added:
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.gold, size: 20),
                SizedBox(width: 8),
                Text('Kartu berhasil ditambahkan ke Koleksi!'),
              ],
            ),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case ToggleResult.removed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Kartu dihapus dari Koleksi.'),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case ToggleResult.notLoggedIn:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu.'),
            backgroundColor: AppColors.surfaceHighest,
          ),
        );
        break;
      case ToggleResult.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui status koleksi.'),
            backgroundColor: AppColors.error,
          ),
        );
        break;
    }
  }

  void _handleWatchlistToggle() async {
    final notifier = ref.read(cardDetailProvider(_args).notifier);
    final result = await notifier.toggleWatchlist();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    switch (result) {
      case ToggleResult.added:
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.favorite, color: AppColors.pink, size: 20),
                SizedBox(width: 8),
                Text('Kartu ditambahkan ke Watchlist!'),
              ],
            ),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case ToggleResult.removed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Kartu dihapus dari Watchlist.'),
            backgroundColor: AppColors.surfaceHighest,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case ToggleResult.notLoggedIn:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu.'),
            backgroundColor: AppColors.surfaceHighest,
          ),
        );
        break;
      case ToggleResult.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui status watchlist.'),
            backgroundColor: AppColors.error,
          ),
        );
        break;
    }
  }

  void _showAiAdvisorDialog(CardModel card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: AppColors.gold, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'AI Penasihat Kartu (Gemini)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analisis Nilai: ${card.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.goldSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.onGold,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(cardDetailProvider(_args));
    final card = detailState.card;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
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
        title: card == null
            ? const Text('Detail Kartu')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${card.name} #${card.localId ?? card.id}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    (card.setName ?? card.setId ?? 'Pokémon TCG').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Icon(
                detailState.inWatchlist ? Icons.favorite : Icons.favorite_border,
                color: detailState.inWatchlist ? AppColors.pink : AppColors.outline,
                size: 22,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: detailState.inWatchlist
                        ? AppColors.pink.withValues(alpha: 0.5)
                        : AppColors.surfaceHigh,
                  ),
                ),
              ),
              tooltip: detailState.inWatchlist
                  ? 'Hapus dari Watchlist'
                  : 'Tambah ke Watchlist',
              onPressed: _handleWatchlistToggle,
            ),
          ),
        ],
      ),
      body: detailState.isLoading && card == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : card == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(detailState.errorMessage ?? 'Kartu tidak ditemukan'),
                    ],
                  ),
                )
              : _buildCardContent(card, detailState),
    );
  }

  Widget _buildCardContent(CardModel card, CardDetailState detailState) {
    // Hitung harga dinamis IDR berdasarkan kurs live jika priceRefUsd ada
    final double displayPrice = card.priceRefUsd != null
        ? CurrencyService.convertRefUsdToIdr(card.priceRefUsd!)
        : (card.priceIdr ?? 0);

    final double? usdPrice = card.priceRefUsd ?? card.priceUsd;
    final double? eurPrice = card.priceEur ??
        (card.priceRefUsd != null
            ? card.priceRefUsd! * CurrencyService.eurToUsdRate
            : null);

    final bool isHolo = HoloCardWidget.isHoloRarity(card.rarity);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      child: Column(
        children: [
          // 1. Stage Kartu 3D Holo / Soft Light (Hero terhubung langsung ke gambar kartu)
          HoloCardWidget(
            cardId: card.id,
            imageUrl: card.highResImageUrl ?? card.imageUrl,
            placeholderUrl: card.lowResImageUrl,
            rarity: card.rarity,
            isHolo: isHolo,
            intensity: HoloCardWidget.intensityForRarity(card.rarity),
          ),

          const SizedBox(height: 16),

          // 2. Badges Row: Rarity, Local ID, Set
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (card.rarity != null && card.rarity!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.pink.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 12, color: AppColors.pink),
                      const SizedBox(width: 4),
                      Text(
                        card.rarity!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pink,
                        ),
                      ),
                    ],
                  ),
                ),
              if (card.localId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceHigh),
                  ),
                  child: Text(
                    'No. #${card.localId}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                ),
                child: Text(
                  card.setName ?? card.setId ?? 'TCG',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 4. Modul Harga Pasar & Multi-Currency (IDR/USD/EUR)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceHigh),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Harga Pasar Referensi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceHigh),
                      ),
                      child: Text(
                        card.priceSource?.toUpperCase() ?? 'TCGPLAYER',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatIdr(displayPrice),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.surfaceHigh, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceHigh),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'USD Eq.',
                              style: TextStyle(fontSize: 11, color: AppColors.outline),
                            ),
                            Text(
                              formatUsd(usdPrice),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceHigh),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'EUR Eq.',
                              style: TextStyle(fontSize: 11, color: AppColors.outline),
                            ),
                            Text(
                              formatEur(eurPrice),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Spesifikasi & Provenance Kartu (2x2 Grid)
          Container(
            padding: const EdgeInsets.all(16),
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
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppColors.gold, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Detail Kartu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'HoloDex Verified',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecTile('Ekspansi / Set', card.setName ?? card.setId ?? '-'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSpecTile('Nomor Kartu', '#${card.localId ?? card.id}'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecTile('Tipe Kartu', card.cardType ?? 'Pokémon'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSpecTile('Kelangkaan', card.rarity ?? 'Regular'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 5. Action Buttons (AI Penasihat & Tambah Koleksi)
          _buildActionButtons(card, detailState),
        ],
      ),
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.outline),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CardModel card, CardDetailState detailState) {
    return Row(
      children: [
        // Tombol AI Advisor
        OutlinedButton.icon(
          icon: const Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
          label: const Text('AI Penasihat'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: AppColors.goldSoft,
            side: const BorderSide(color: AppColors.surfaceHigh),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showAiAdvisorDialog(card),
        ),
        const SizedBox(width: 10),

        // Tombol Tambah ke Koleksi
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(
              detailState.inCollection
                  ? Icons.check_circle
                  : Icons.add_circle,
              color: detailState.inCollection ? AppColors.onSurface : AppColors.onGold,
              size: 20,
            ),
            label: Text(
              detailState.inCollection
                  ? 'Dalam Koleksi ✓'
                  : 'Tambah Koleksi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: detailState.inCollection ? AppColors.onSurface : AppColors.onGold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: detailState.inCollection
                  ? AppColors.surfaceHighest
                  : AppColors.gold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: detailState.inCollection
                      ? AppColors.surfaceHigh
                      : AppColors.gold,
                ),
              ),
            ),
            onPressed: detailState.isBusy ? null : _handleCollectionToggle,
          ),
        ),
      ],
    );
  }
}
