import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/web3_blockchain_service.dart';

void main() {
  group('Web3BlockchainService Unit Tests', () {
    late Web3BlockchainService service;

    setUp(() {
      service = Web3BlockchainService.instance;
    });

    test('Validasi format alamat Ethereum / Polygon', () {
      // Alamat valid (0x + 40 karakter hex)
      expect(
        service.isValidAddress('0x742d35Cc6634C0532925a3b844Bc454e4438f44e'),
        isTrue,
      );
      expect(
        service.isValidAddress('0x0000000000000000000000000000000000000000'),
        isTrue,
      );

      // Alamat tidak valid
      expect(service.isValidAddress(''), isFalse);
      expect(service.isValidAddress('0x123'), isFalse); // Terlalu pendek
      expect(service.isValidAddress('742d35Cc6634C0532925a3b844Bc454e4438f44e'), isFalse); // Tanpa 0x
      expect(service.isValidAddress('0xZZZd35Cc6634C0532925a3b844Bc454e4438f44e'), isFalse); // Non-hex
      expect(
        service.isValidAddress('0x742d35Cc6634C0532925a3b844Bc454e4438f44eAA'),
        isFalse, // Terlalu panjang (42 hex char)
      );
    });

    test('Validasi format TxHash Ethereum / Polygon', () {
      final validTxHash =
          '0x${'1234567890abcdef' * 4}';
      expect(service.isValidTxHash(validTxHash), isTrue);

      // Hash tidak valid
      expect(service.isValidTxHash(''), isFalse);
      expect(service.isValidTxHash('0x3a1b'), isFalse); // Kurang dari 64 hex
      expect(service.isValidTxHash('1234567890abcdef' * 4), isFalse); // Tanpa 0x
      expect(service.isValidTxHash('0x${'GGGG567890abcdef' * 4}'), isFalse); // Karakter non-hex
    });

    test('Format potongan hash ramah tampilan layar mobile', () {
      const hash =
          '0x3a1b023456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0';
      final formatted = service.formatShortHash(hash);
      expect(formatted, equals('0x3a1b...def0'));

      // Jika teks pendek, tidak dipotong
      expect(service.formatShortHash('0x123'), equals('0x123'));
    });

    test('Format potongan alamat ramah tampilan layar mobile', () {
      const addr = '0x742d35Cc6634C0532925a3b844Bc454e4438f44e';
      final formatted = service.formatShortAddress(addr);
      expect(formatted, equals('0x742d...f44e'));
    });

    test('Pembuatan URL PolygonScan Explorer yang aman dan valid', () {
      const tx = '0x3a1b023456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0';
      final txUrl = service.getExplorerTxUrl(tx);
      expect(txUrl, contains('https://amoy.polygonscan.com/tx/$tx'));

      const addr = '0x742d35Cc6634C0532925a3b844Bc454e4438f44e';
      final addrUrl = service.getExplorerAddressUrl(addr);
      expect(addrUrl, contains('https://amoy.polygonscan.com/address/$addr'));
    });

    test('Penanganan error asinkronus saat kredensial operator belum diset', () async {
      // Saat .env belum memiliki private key atau alamat kontrak,
      // minting harus mengembalikan null dengan anggun tanpa crash.
      final result = await service.mintCertificate(
        cardId: 'swsh3-1',
        cardName: 'Butterfree VMAX',
      );
      expect(result, isNull);
    });
  });
}
