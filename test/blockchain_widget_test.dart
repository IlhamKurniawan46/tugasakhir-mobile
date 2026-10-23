import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:holodex/core/models/card_certificate_model.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/features/dex/providers/provenance_provider.dart';
import 'package:holodex/features/dex/widgets/provenance_timeline_widget.dart';
import 'package:holodex/shared/widgets/blockchain_verification_dialog.dart';

void main() {
  group('Blockchain Widgets & Provenance UI Tests', () {
    const testTxHash =
        '0x3a1b023456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0';

    testWidgets('BlockchainVerificationDialog merender QR Code, info token, dan tombol explorer tanpa overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlockchainVerificationDialog(
              txHash: testTxHash,
              tokenId: '101',
              cardName: 'Charizard VMAX',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi judul dialog dan jaringan
      expect(find.text('Sertifikat On-Chain'), findsOneWidget);
      expect(find.text('Polygon Testnet (Amoy)'), findsOneWidget);
      expect(find.text('Charizard VMAX'), findsOneWidget);
      expect(find.text('ERC-721 Token ID #101'), findsOneWidget);

      // Verifikasi QR Code berhasil terpasang
      expect(find.byType(QrImageView), findsOneWidget);

      // Verifikasi potongan hash dan tombol
      expect(find.text('0x3a1b...def0'), findsOneWidget);
      expect(find.text('Lihat di PolygonScan'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('ProvenanceTimelineWidget merender badge Verified on Chain dan daftar timeline', (tester) async {
      const card = CardModel(
        id: 'swsh3-1',
        name: 'Butterfree VMAX',
      );

      final mockCertificates = [
        CardCertificateModel(
          id: 'cert-1',
          cardId: 'swsh3-1',
          tokenId: '1',
          contractAddress: '0x1234567890123456789012345678901234567890',
          txHash: testTxHash,
          fromAddress: '0x0000000000000000000000000000000000000000',
          toAddress: '0x742d35Cc6634C0532925a3b844Bc454e4438f44e',
          ownerUsername: 'SatoshiCollector',
          action: 'minted',
          priceIdr: 0,
          createdAt: DateTime(2026, 10, 24, 10, 0),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cardProvenanceProvider('swsh3-1').overrideWith(
              (ref) async => mockCertificates,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProvenanceTimelineWidget(card: card),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi judul dan badge visual
      expect(find.text('Riwayat Kepemilikan'), findsOneWidget);
      expect(find.text('Verified on Chain'), findsOneWidget);

      // Verifikasi item timeline
      expect(find.text('Genesis Minting'), findsOneWidget);
      expect(find.textContaining('SatoshiCollector'), findsOneWidget);
      expect(find.textContaining('Tx: 0x3a1b...def0'), findsOneWidget);
      expect(find.text('Verifikasi'), findsOneWidget);

      // Ketuk tombol Verifikasi -> Harus memunculkan dialog
      await tester.tap(find.text('Verifikasi'));
      await tester.pumpAndSettle();

      expect(find.byType(BlockchainVerificationDialog), findsOneWidget);
    });
  });
}
