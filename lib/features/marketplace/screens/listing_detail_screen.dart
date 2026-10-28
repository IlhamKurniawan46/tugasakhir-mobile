import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/models/listing_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/interaction_service.dart';
import '../../../core/services/marketplace_repository.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/providers/currency_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/order_provider.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  final ListingModel? initialListing;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  ListingModel? _listing;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _listing = widget.initialListing;
    if (_listing != null) {
      _logListingView(_listing!.cardId);
    } else {
      _loadDetail();
    }
  }

  void _logListingView(String cardId) async {
    final userId = await SessionService.getActiveUserId();
    if (userId != null) {
      await InteractionService.instance.logListingView(
        userId: userId,
        cardId: cardId,
      );
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail =
          await MarketplaceRepository.getListingDetail(widget.listingId);
      if (mounted) {
        setState(() {
          _listing = detail;
          _isLoading = false;
          if (detail == null) {
            _errorMessage = 'Listing tidak ditemukan atau telah dihapus.';
          } else {
            _logListingView(detail.cardId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat detail listing: $e';
        });
      }
    }
  }

  Future<void> _handleBuy() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu untuk membeli kartu.'),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final listing = _listing;
    if (listing == null) return;

    if (user.balanceIdr < listing.priceIdr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo Anda tidak mencukupi untuk memesan kartu ini.'),
          backgroundColor: AppColors.snackBarError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedCurrency = ref.read(currencyProvider);
    String displayPrice;
    if (selectedCurrency == AppCurrency.idr) {
      displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
    } else {
      final converted = CurrencyService.convert(
        listing.priceIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      displayPrice = converted != null
          ? PriceFormatter.format(converted, selectedCurrency.code)
          : PriceFormatter.formatIdr(listing.priceIdr);
    }

    final remainingBalance = user.balanceIdr - listing.priceIdr;

    // Tampilkan BottomSheet Konfirmasi Pemesanan (Rekber COD)
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_clock,
                        color: AppColors.gold, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Pesan Kartu (Rekber COD)',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kartu:'),
                          Flexible(
                            child: Text(
                              listing.card?.name ?? 'Kartu Pokémon',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kondisi:'),
                          Text(listing.conditionLabel,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Penjual:'),
                          Text('@${listing.sellerUsername ?? 'Penjual'}'),
                        ],
                      ),
                      if (listing.lat != null && listing.lng != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Titik COD:'),
                            Flexible(
                              child: Text(
                                '${listing.lat!.toStringAsFixed(4)}, ${listing.lng!.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Harga Kartu:'),
                          Text(
                            selectedCurrency == AppCurrency.idr
                                ? displayPrice
                                : '$displayPrice (${PriceFormatter.formatIdr(listing.priceIdr)})',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Saldo Setelah Ditahan:'),
                          Text(
                            PriceFormatter.formatIdr(remainingBalance),
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saldo ditahan sampai kamu mengonfirmasi kartu diterima. Pesanan otomatis batal dalam 72 jam bila tidak ada konfirmasi.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Pesan Sekarang',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isPurchasing = true);

    try {
      await ref.read(orderProvider.notifier).reserveListing(
            listingId: listing.id,
            buyerId: user.id,
          );

      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _listing = _listing?.copyWith(status: 'reserved');
        });

        // Dialog Berhasil Memesan Kartu
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: AppColors.success, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pesanan Berhasil Dibuat!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo Anda sebesar ${PriceFormatter.formatIdr(listing.priceIdr)} telah ditahan dengan aman di sistem Rekber.',
                  style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Temui penjual @${listing.sellerUsername ?? 'Penjual'} di titik COD yang disepakati. Setelah memeriksa fisik kartu, tekan "Sudah Kuterima" di menu Pesanan Saya.',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            actionsOverflowButtonSpacing: 8,
            actionsAlignment: MainAxisAlignment.end,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                  context.push('/marketplace/orders');
                },
                child: const Text('Lihat Pesanan Saya'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pemesanan gagal: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelListing() async {
    final user = ref.read(authProvider).user;
    if (user == null || _listing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Batalkan Listing?'),
        content: const Text(
          'Kartu ini akan ditarik dari Pasar dan tidak dapat dibeli oleh pengguna lain lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(marketplaceProvider.notifier).cancelListing(
            listingId: _listing!.id,
            sellerId: user.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing berhasil dibatalkan.'),
            backgroundColor: AppColors.snackBarSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan listing: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = ref.watch(authProvider).user;
    final selectedCurrency = ref.watch(currencyProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Listing')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (_errorMessage != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Listing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Listing tidak ditemukan.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final listing = _listing!;
    final card = listing.card;
    final isOwnListing = user != null && user.id == listing.sellerId;
    final canBuy = listing.isActive &&
        !listing.isReserved &&
        !isOwnListing &&
        user != null &&
        user.balanceIdr >= listing.priceIdr;

    // Hitung harga terkonversi
    String displayPrice;
    if (selectedCurrency == AppCurrency.idr) {
      displayPrice = PriceFormatter.formatIdr(listing.priceIdr);
    } else {
      final converted = CurrencyService.convert(
        listing.priceIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      displayPrice = converted != null
          ? PriceFormatter.format(converted, selectedCurrency.code)
          : PriceFormatter.formatIdr(listing.priceIdr);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          card?.name ?? 'Detail Kartu',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(
                color: AppColors.surfaceHigh,
                width: 1,
              ),
            ),
          ),
          child: isOwnListing
              ? listing.isActive
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text(
                          'Batalkan Listing Ini',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _handleCancelListing,
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: Text(
                        listing.isReserved
                            ? 'Listing sedang Dipesan oleh Pembeli'
                            : listing.isSold
                                ? 'Kartu ini telah terjual'
                                : 'Listing ini telah dibatalkan',
                        style: TextStyle(
                          color: listing.isReserved
                              ? AppColors.gold
                              : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Harga Listing',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayPrice,
                              style: textTheme.titleLarge?.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                canBuy ? AppColors.gold : AppColors.surfaceHigh,
                            foregroundColor:
                                canBuy ? Colors.black : AppColors.onSurfaceVariant,
                            elevation: canBuy ? 3 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: (_isPurchasing || !listing.isActive || listing.isReserved)
                              ? null
                              : (user == null || user.balanceIdr < listing.priceIdr)
                                  ? () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Saldo tidak cukup. Silakan top up di menu pasar.'),
                                          backgroundColor: AppColors.snackBarError,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  : _handleBuy,
                          child: _isPurchasing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  listing.isSold
                                      ? 'Sudah Terjual'
                                      : listing.isReserved
                                          ? 'Dipesan'
                                          : (!listing.isActive)
                                              ? 'Tidak Tersedia'
                                              : (user != null &&
                                                      user.balanceIdr <
                                                          listing.priceIdr)
                                                  ? 'Saldo Kurang'
                                                  : 'Pesan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Kartu Besar
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 63 / 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: card?.highResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.highResImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: AppColors.surfaceHigh),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceHigh,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceHigh,
                            child: const Icon(
                              Icons.style_outlined,
                              size: 48,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Nama & Set Kartu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card?.name ?? 'Kartu Pokémon',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card?.setName ?? card?.setId ?? 'TCG Set'} · ${card?.rarity ?? 'Common'}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge Kondisi
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: listing.conditionBadgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    listing.conditionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Kotak Perbandingan Harga Pasar Resmi vs Listing
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.query_stats, color: AppColors.gold, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Informasi & Acuan Harga',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    spacing: 8,
                    children: [
                      const Text(
                        'Harga Listing Penjual:',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        displayPrice,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (card?.priceIdr != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      spacing: 8,
                      children: [
                        const Text(
                          'Harga Pasar Acuan TCG:',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                        Text(
                          PriceFormatter.formatIdr(card!.priceIdr),
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profil Penjual & Lokasi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceHigh,
                        child: const Icon(Icons.person, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${listing.sellerUsername ?? 'Penjual'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (isOwnListing)
                              const Text(
                                'Ini adalah listing milik Anda sendiri',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11,
                                ),
                              )
                            else
                              const Text(
                                'Penjual Terverifikasi HoloDex',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (listing.lat != null && listing.lng != null) ...[
                    const Divider(height: 20),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        context.push(
                          '/marketplace/map',
                          extra: {
                            'lat': listing.lat,
                            'lng': listing.lng,
                            'zoom': 15.5,
                            'listing': listing,
                            'title': 'Titik COD: ${listing.card?.name ?? 'Penjual'}',
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Koordinat COD: ${listing.lat!.toStringAsFixed(4)}, ${listing.lng!.toStringAsFixed(4)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Ketuk untuk lihat posisi di peta',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.cyan,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.gold, width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map_outlined, size: 12, color: AppColors.gold),
                                  SizedBox(width: 4),
                                  Text(
                                    'Buka Peta',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Deskripsi Kondisi dari Penjual
            if (listing.description != null &&
                listing.description!.trim().isNotEmpty) ...[
              Text(
                'Catatan Penjual',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Text(
                  listing.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Rincian Saldo Pembeli Saat Ini
            if (!isOwnListing && user != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.withAlpha(128),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 6,
                  spacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.wallet, size: 18, color: AppColors.gold),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Saldo (simulasi):',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      PriceFormatter.formatIdr(user.balanceIdr),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: user.balanceIdr >= listing.priceIdr
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
