import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/services/web3_blockchain_service.dart';

/// Dialog verifikasi sertifikat blockchain on-chain pada Polygon Testnet (Amoy).
/// Menampilkan QR Code tautan explorer agar dosen penguji dapat memindai langsung
/// via kamera ponsel mereka, tombol buka browser eksternal, dan informasi token.
class BlockchainVerificationDialog extends StatelessWidget {
  final String txHash;
  final String? tokenId;
  final String? cardName;
  final String? contractAddress;

  const BlockchainVerificationDialog({
    super.key,
    required this.txHash,
    this.tokenId,
    this.cardName,
    this.contractAddress,
  });

  static void show(
    BuildContext context, {
    required String txHash,
    String? tokenId,
    String? cardName,
    String? contractAddress,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => BlockchainVerificationDialog(
        txHash: txHash,
        tokenId: tokenId,
        cardName: cardName,
        contractAddress: contractAddress,
      ),
    );
  }

  Future<void> _launchPolygonScan(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showToast(context, 'Tautan URL tidak valid');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showToast(context, 'Gagal membuka peramban web');
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Perangkat offline atau peramban tidak tersedia');
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final explorerUrl = Web3BlockchainService.instance.getExplorerTxUrl(txHash);
    final shortHash = Web3BlockchainService.instance.formatShortHash(txHash);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gold, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Dialog
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: AppColors.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sertifikat On-Chain',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Polygon Testnet (Amoy)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.outline),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (cardName != null) ...[
                Text(
                  cardName!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],

              if (tokenId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ERC-721 Token ID #$tokenId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Tampilan QR Code untuk Verifikasi Langsung oleh Dosen
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: explorerUrl,
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1E1035),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1E1035),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'Pindai QR dengan kamera smartphone untuk validasi publik di PolygonScan Explorer',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.outline,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Box Ringkasan Hash
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHigh),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction Hash (TxHash):',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.outline,
                            ),
                          ),
                          Text(
                            shortHash,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.gold),
                      tooltip: 'Salin TxHash',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: txHash));
                        _showToast(context, 'TxHash disalin ke papan klip');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Buka di PolygonScan Explorer
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _launchPolygonScan(context, explorerUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'Lihat di PolygonScan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
