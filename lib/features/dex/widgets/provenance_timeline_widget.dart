import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/models/card_certificate_model.dart';
import '../../../core/models/card_model.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../shared/widgets/blockchain_verification_dialog.dart';
import '../providers/provenance_provider.dart';

/// Widget tampilan Sertifikat Keaslian & Riwayat Kepemilikan (Provenance Timeline).
/// Menampilkan rantai kepemilikan kartu dari pembuat/penjual hingga pembeli baru
/// beserta potongan TxHash dan tombol validasi PolygonScan.
class ProvenanceTimelineWidget extends ConsumerWidget {
  final CardModel card;

  const ProvenanceTimelineWidget({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provenanceAsync = ref.watch(cardProvenanceProvider(card.id));

    return Container(
      width: double.infinity,
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
          // Header Provenance & Badge
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.cyan,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Riwayat Kepemilikan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge Visual "Verified on Chain" (Biru Cyan Konsisten)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 11, color: AppColors.cyan),
                    SizedBox(width: 3.5),
                    Text(
                      'Verified on Chain',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyan,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Text(
            'Bukti keaslian kartu dan rantai kepemilikan tercatat permanen di Polygon Amoy.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 14),

          // Konten Riwayat / Timeline
          provenanceAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildTimelineList(context, records);
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Riwayat lokal belum tersinkronisasi. Silakan periksa koneksi.',
                      style: const TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.hub_outlined, size: 18, color: AppColors.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sertifikat Genesis Tersedia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Kartu ini terdaftar di katalog resmi HoloDex. Saat dibeli melalui marketplace, sertifikat kepemilikan baru akan otomatis dicatat di Polygon Amoy.',
            style: TextStyle(fontSize: 11, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList(
    BuildContext context,
    List<CardCertificateModel> records,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final record = records[index];
        final isGenesis = record.isMinted || record.fromAddress == null || record.fromAddress == '0x0000000000000000000000000000000000000000';
        final dateStr = record.createdAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(record.createdAt!)
            : 'Waktu belum tercatat';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isGenesis
                  ? AppColors.gold.withValues(alpha: 0.3)
                  : AppColors.surfaceHigh,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isGenesis ? Icons.stars : Icons.swap_horiz,
                        size: 16,
                        color: isGenesis ? AppColors.gold : AppColors.cyan,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGenesis ? 'Genesis Minting' : 'Transfer Kepemilikan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isGenesis ? AppColors.gold : AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10, color: AppColors.outline),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Alamat Rantai
              Row(
                children: [
                  const Text(
                    'Pemilik: ',
                    style: TextStyle(fontSize: 11, color: AppColors.outline),
                  ),
                  Expanded(
                    child: Text(
                      record.ownerUsername != null
                          ? '@${record.ownerUsername} (${CardCertificateModel.formatShortAddress(record.toAddress)})'
                          : CardCertificateModel.formatShortAddress(record.toAddress),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (record.priceIdr > 0) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text(
                      'Harga Beli: ',
                      style: TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                    Text(
                      PriceFormatter.formatIdr(record.priceIdr),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Potongan Hash & Tombol Buka PolygonScan / QR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        'Tx: ${record.shortTxHash}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.cyan,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      BlockchainVerificationDialog.show(
                        context,
                        txHash: record.txHash,
                        tokenId: record.tokenId,
                        cardName: card.name,
                        contractAddress: record.contractAddress,
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: const [
                          Icon(Icons.qr_code, size: 14, color: AppColors.gold),
                          SizedBox(width: 4),
                          Text(
                            'Verifikasi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
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
        );
      },
    );
  }
}
