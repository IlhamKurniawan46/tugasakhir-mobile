import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/widgets/blockchain_verification_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Transaksi')),
        body: const Center(
          child: Text('Silakan login untuk melihat riwayat transaksi.'),
        ),
      );
    }

    final asyncTransactions = ref.watch(userTransactionsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(
              icon: Icon(Icons.shopping_cart_outlined, size: 20),
              text: 'Pembelian Saya',
            ),
            Tab(
              icon: Icon(Icons.sell_outlined, size: 20),
              text: 'Penjualan Saya',
            ),
          ],
        ),
      ),
      body: asyncTransactions.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat riwayat transaksi: $err',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(userTransactionsProvider(user.id)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (transactions) {
          final purchases = transactions.where((t) => t.isBuyer).toList();
          final sales = transactions.where((t) => !t.isBuyer).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // Tab Pembelian
              _buildTransactionList(
                transactions: purchases,
                userId: user.id,
                emptyTitle: 'Belum Ada Pembelian',
                emptySubtitle:
                    'Kartu yang Anda beli di Marketplace HoloDex akan tercatat di sini dan tersimpan di Koleksi Saya.',
                isPurchaseTab: true,
              ),

              // Tab Penjualan
              _buildTransactionList(
                transactions: sales,
                userId: user.id,
                emptyTitle: 'Belum Ada Penjualan',
                emptySubtitle:
                    'Pasang listing kartu fisik Anda di Marketplace untuk mulai menjual ke sesama kolektor.',
                isPurchaseTab: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionList({
    required List<TransactionModel> transactions,
    required String userId,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isPurchaseTab,
  }) {
    if (transactions.isEmpty) {
      return RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(userTransactionsProvider(userId));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPurchaseTab
                            ? Icons.shopping_bag_outlined
                            : Icons.storefront_outlined,
                        size: 64,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptySubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(userTransactionsProvider(userId));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = transactions[index];
          final card = item.card;
          final dateStr = item.createdAt != null
              ? dateFormat.format(item.createdAt!.toLocal())
              : '-';

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceHigh),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Gambar Kartu
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 50,
                    height: 70,
                    child: card?.lowResImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: card!.lowResImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: AppColors.surfaceHigh),
                          )
                        : Container(color: AppColors.surfaceHigh),
                  ),
                ),
                const SizedBox(width: 12),

                // Info Transaksi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              card?.name ?? 'Kartu Pokémon',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SELESAI',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${card?.setName ?? card?.setId ?? 'TCG'} · ${isPurchaseTab ? 'Penjual: @${item.sellerUsername ?? 'seller'}' : 'Pembeli: @${item.buyerUsername ?? 'buyer'}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            PriceFormatter.formatIdr(item.priceIdr),
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (item.txHash != null && item.txHash!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            BlockchainVerificationDialog.show(
                              context,
                              txHash: item.txHash!,
                              tokenId: item.tokenId,
                              cardName: card?.name,
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, size: 12, color: AppColors.cyan),
                                const SizedBox(width: 4),
                                Text(
                                  'On-Chain: ${item.shortTxHash}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.cyan,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.qr_code, size: 14, color: AppColors.gold),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
