import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/order_repository.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/providers/currency_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';

/// Layar "Pesanan Saya" (Escrow / Rekber) dengan Tab Pembelian dan Penjualan
class MyOrdersScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MyOrdersScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  OrderNotifier? _orderNotifier;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _orderNotifier = ref.read(orderProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orderNotifier?.loadOrders();
      _orderNotifier?.startPolling();
    });
  }

  @override
  void dispose() {
    _orderNotifier?.stopPolling();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Rekber'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: [
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pembelian'),
                    if (orderState.buyerOrders
                        .any((o) => o.isReserved && !o.isExpired())) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${orderState.buyerOrders.where((o) => o.isReserved && !o.isExpired()).length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Penjualan'),
                    if (orderState.sellerOrders
                        .any((o) => o.isReserved && !o.isExpired())) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyan,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${orderState.sellerOrders.where((o) => o.isReserved && !o.isExpired()).length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(orderProvider.notifier).loadOrders();
        },
        child: orderState.isLoading && orderState.orders.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : orderState.errorMessage != null && orderState.orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            orderState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.gold,
                              side: const BorderSide(color: AppColors.gold),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            onPressed: () =>
                                ref.read(orderProvider.notifier).loadOrders(),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Pembelian
                      _OrderListView(
                        orders: orderState.buyerOrders,
                        isBuyerList: true,
                        emptyMessage:
                            'Belum ada pesanan pembelian.\nPilih kartu yang kamu inginkan di Pasar!',
                      ),
                      // Tab 2: Penjualan
                      _OrderListView(
                        orders: orderState.sellerOrders,
                        isBuyerList: false,
                        emptyMessage:
                            'Belum ada kartu daganganmu yang dipesan.\nPasang listing menarik untuk kolektor lain!',
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Tampilan daftar pesanan per tab
class _OrderListView extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isBuyerList;
  final String emptyMessage;

  const _OrderListView({
    required this.orders,
    required this.isBuyerList,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBuyerList
                              ? Icons.shopping_bag_outlined
                              : Icons.storefront_outlined,
                          size: 40,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCardItem(
          key: ValueKey(order.id),
          order: order,
          isBuyer: isBuyerList,
        );
      },
    );
  }
}

/// Item Card Pesanan Rekber
class OrderCardItem extends ConsumerStatefulWidget {
  final OrderModel order;
  final bool isBuyer;

  const OrderCardItem({
    super.key,
    required this.order,
    required this.isBuyer,
  });

  @override
  ConsumerState<OrderCardItem> createState() => _OrderCardItemState();
}

class _OrderCardItemState extends ConsumerState<OrderCardItem> {
  bool _isProcessing = false;
  bool _isContacting = false;

  Future<void> _handleContactWhatsApp() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isContacting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final contactResult = await OrderRepository.getOrderContact(
        orderId: widget.order.id,
        userId: user.id,
      );

      if (!mounted) return;

      if (!contactResult.ok || contactResult.whatsappNumber == null) {
        final errText = contactResult.message ??
            (contactResult.errorCode == 'no_contact'
                ? 'Pihak lawan (@${widget.order.otherPartyUsername ?? 'Lawan'}) belum mengisi nomor WhatsApp.'
                : 'Kontak WhatsApp hanya dapat diakses saat pesanan masih aktif.');

        messenger.showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final phone = contactResult.whatsappNumber!;
      final cardName = widget.order.card?.name ?? 'Kartu Pokémon';
      final shortId = WhatsAppHelper.getShortOrderId(widget.order.id);
      final loc = widget.order.listing?.lat != null
          ? '${widget.order.listing!.lat!.toStringAsFixed(4)}, ${widget.order.listing!.lng!.toStringAsFixed(4)}'
          : 'titik COD yang disepakati';

      final message = WhatsAppHelper.buildInitialCodMessage(
        myName: user.username,
        cardName: cardName,
        shortOrderId: shortId,
        codLocation: loc,
      );

      final uri = WhatsAppHelper.buildWhatsAppUri(phone: phone, message: message);

      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }

      if (!launched && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka WhatsApp (${WhatsAppHelper.formatDisplayPhone(phone)})'),
            backgroundColor: AppColors.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Salin Nomor',
              textColor: AppColors.gold,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Nomor WhatsApp disalin ke clipboard!'),
                    backgroundColor: AppColors.snackBarSuccess,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menghubungi: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isContacting = false);
    }
  }

  Future<void> _handleConfirmReceipt() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Konfirmasi Serah Terima?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan kamu telah menerima kartu fisik ${widget.order.card?.name ?? 'Pokémon'} di titik COD dalam kondisi baik.',
              style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              'Saldo sebesar ${PriceFormatter.formatIdr(widget.order.amountIdr)} akan diserahkan ke penjual dan kartu resmi masuk ke Binder Koleksi Saya.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sudah Kuterima'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(orderProvider.notifier).confirmReceipt(
            orderId: widget.order.id,
            buyerId: user.id,
            cardName: widget.order.card?.name,
            cardId: widget.order.cardId,
            amountIdr: widget.order.amountIdr,
          );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Serah terima berhasil! Kartu ${widget.order.card?.name ?? ''} telah masuk ke Koleksi Saya.',
            ),
            backgroundColor: AppColors.snackBarSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal konfirmasi: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCancelOrder() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // Tampilkan dialog pembatalan mandiri yang mengelola siklus hidup controller-nya sendiri
    final reason = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CancelOrderDialog(
        isBuyer: widget.isBuyer,
        amountIdr: widget.order.amountIdr,
      ),
    );

    // Jika pengguna membatalkan dialog (tekan Kembali atau luar dialog)
    if (reason == null) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(orderProvider.notifier).cancelOrder(
            orderId: widget.order.id,
            userId: user.id,
            reason: reason.isNotEmpty ? reason : null,
          );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibatalkan dan saldo dikembalikan.'),
            backgroundColor: AppColors.snackBarSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan pesanan: $e'),
            backgroundColor: AppColors.snackBarError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedCurrency = ref.watch(currencyProvider);
    final order = widget.order;
    final card = order.card;
    final listing = order.listing;

    // Hitung harga sesuai preferensi mata uang
    String displayPrice;
    if (selectedCurrency == AppCurrency.idr) {
      displayPrice = PriceFormatter.formatIdr(order.amountIdr);
    } else {
      final converted = CurrencyService.convert(
        order.amountIdr,
        from: 'IDR',
        to: selectedCurrency.code,
      );
      displayPrice = converted != null
          ? PriceFormatter.format(converted, selectedCurrency.code)
          : PriceFormatter.formatIdr(order.amountIdr);
    }

    final canConfirm = OrderActions.canConfirm(
      order: order,
      isBuyer: widget.isBuyer,
    );
    final canCancel = OrderActions.canCancel(
      order: order,
      isBuyer: widget.isBuyer,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: order.isReserved
              ? AppColors.gold.withAlpha(90)
              : AppColors.surfaceHigh,
          width: 1,
        ),
      ),
      color: AppColors.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Header: Tanggal & Chip Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        widget.isBuyer
                            ? Icons.shopping_bag_outlined
                            : Icons.storefront_outlined,
                        size: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.isBuyer
                              ? 'Penjual: @${order.otherPartyUsername ?? 'Penjual'}'
                              : 'Pembeli: @${order.otherPartyUsername ?? 'Pembeli'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OrderActions.statusColor(order.status).withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: OrderActions.statusColor(order.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    OrderActions.statusLabel(order.status),
                    style: TextStyle(
                      color: OrderActions.statusColor(order.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 14),

            // Baris Konten: Gambar + Info Kartu & Harga
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 50,
                    height: 70,
                    color: AppColors.surfaceHigh,
                    child: card?.lowResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.lowResImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: AppColors.outline,
                            ),
                          )
                        : const Icon(Icons.style, size: 24, color: AppColors.outline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card?.name ?? 'Kartu Pokémon',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${card?.setName ?? card?.setId ?? 'TCG'} ${card?.localId != null ? '#${card!.localId}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayPrice,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Sisa Waktu Hitung Mundur (Isolasi Ringan)
            if (order.isReserved) ...[
              const SizedBox(height: 10),
              _CountdownBadge(expiresAt: order.expiresAt),
            ],

            // Info Titik COD
            if (listing != null &&
                listing.lat != null &&
                listing.lng != null) ...[
              const SizedBox(height: 8),
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
                      'title': 'Titik COD: ${card?.name ?? 'Pesanan'}',
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh.withAlpha(140),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withAlpha(80),
                      width: 1,
                    ),
                  ),
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
                              'Titik COD: ${listing.lat!.toStringAsFixed(4)}, ${listing.lng!.toStringAsFixed(4)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Pusatkan ke titik COD di peta',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: AppColors.cyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              'Lihat Peta',
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

            // Alasan Pembatalan bila dibatalkan
            if (order.cancelReason != null &&
                order.cancelReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Alasan: ${order.cancelReason}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Tombol Kontak WhatsApp (Hanya saat status reserved)
            if (order.isReserved) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isContacting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(
                    _isContacting
                        ? 'Menghubungkan...'
                        : 'Hubungi via WhatsApp',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _isContacting ? null : _handleContactWhatsApp,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security,
                    size: 13,
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Bertemu di tempat umum dan periksa kartu sebelum menekan "Sudah kuterima".',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.outline,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Tombol Aksi (Hanya jika masih reserved)
            if (canConfirm || canCancel) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _isProcessing ? null : _handleCancelOrder,
                        child: const Text(
                          'Batalkan',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (canConfirm && canCancel) const SizedBox(width: 8),
                  if (canConfirm)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _isProcessing ? null : _handleConfirmReceipt,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Sudah Kuterima',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget Hitung Mundur Terisolasi (Anti Rebuild Layar Penuh)
class _CountdownBadge extends StatefulWidget {
  final DateTime expiresAt;

  const _CountdownBadge({required this.expiresAt});

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateRemaining();
        });
      }
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (now.isAfter(widget.expiresAt)) {
      _remaining = Duration.zero;
      _timer?.cancel();
    } else {
      _remaining = widget.expiresAt.difference(now);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration diff) {
    if (diff == Duration.zero) return 'Kedaluwarsa';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (hours > 24) {
      final days = diff.inDays;
      final remHours = hours.remainder(24);
      return '${days}h ${remHours}j tersisa';
    } else if (hours > 0) {
      return '${hours}j ${minutes}m tersisa';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}d tersisa';
    } else {
      return '${seconds}d tersisa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStale = _remaining == Duration.zero;
    final text = _formatDuration(_remaining);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isStale
            ? AppColors.error.withAlpha(20)
            : AppColors.gold.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isStale ? AppColors.error : AppColors.gold.withAlpha(80),
          width: 0.8,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isStale ? Icons.timer_off_outlined : Icons.hourglass_top,
              size: 13,
              color: isStale ? AppColors.error : AppColors.gold,
            ),
            const SizedBox(width: 4),
            Text(
              'Batas konfirmasi: $text',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isStale ? AppColors.error : AppColors.gold,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog Pembatalan Pesanan dengan Pengelolaan Controller Mandiri
class _CancelOrderDialog extends StatefulWidget {
  final bool isBuyer;
  final double amountIdr;

  const _CancelOrderDialog({
    required this.isBuyer,
    required this.amountIdr,
  });

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Batalkan Pesanan?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isBuyer
                ? 'Saldo tertahan sebesar ${PriceFormatter.formatIdr(widget.amountIdr)} akan langsung dikembalikan utuh ke akun Anda, dan listing kartu kembali aktif.'
                : 'Pesanan akan dibatalkan, saldo akan dikembalikan ke pembeli, dan listing kartu Anda akan kembali aktif di Pasar.',
            style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Alasan pembatalan (opsional)',
              hintText: 'Contoh: Jadwal COD tidak cocok',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Kembali'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context, _reasonController.text.trim());
          },
          child: const Text('Ya, Batalkan'),
        ),
      ],
    );
  }
}
