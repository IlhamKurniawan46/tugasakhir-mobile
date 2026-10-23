import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

void main() async {
  // Baca .env secara murni tanpa dependensi Flutter
  final envMap = <String, String>{};
  final envFile = File('.env');
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final idx = trimmed.indexOf('=');
      if (idx > 0) {
        envMap[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
      }
    }
    // ignore: avoid_print
    print('File .env berhasil dibaca.');
  }

  final rpcUrl = envMap['POLYGON_AMOY_RPC_URL'] ?? 'https://polygon-amoy-bor-rpc.publicnode.com';
  final contractAddress = envMap['BLOCKCHAIN_CONTRACT_ADDRESS'] ?? '';
  final privateKey = envMap['BLOCKCHAIN_OPERATOR_PRIVATE_KEY'] ?? '';

  // ignore: avoid_print
  print('==================================================');
  // ignore: avoid_print
  print('       HoloDex Polygon Amoy Connection Test       ');
  // ignore: avoid_print
  print('==================================================');
  // ignore: avoid_print
  print('RPC Endpoint: $rpcUrl');

  final httpClient = http.Client();
  final client = Web3Client(rpcUrl, httpClient);

  try {
    final chainId = await client.getChainId();
    final block = await client.getBlockNumber();
    // ignore: avoid_print
    print('Status RPC:    TERHUBUNG (Online)');
    // ignore: avoid_print
    print('Chain ID:      $chainId (Target Amoy: 80002)');
    // ignore: avoid_print
    print('Block Height:  #$block');

    if (privateKey.isNotEmpty) {
      final sanitizedKey = privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
      final creds = EthPrivateKey.fromHex(sanitizedKey);
      final address = creds.address;
      final balance = await client.getBalance(address);
      // ignore: avoid_print
      print('Operator Addr: 0x$address');
      // ignore: avoid_print
      print('Saldo Testnet: ${balance.getValueInUnit(EtherUnit.ether)} POL');

      if (balance.getInWei == BigInt.zero) {
        // ignore: avoid_print
        print('STATUS: Saldo masih 0 POL. Klaim token gratis di faucet.');
      } else {
        // ignore: avoid_print
        print('STATUS SIAP: Akun memiliki saldo POL untuk gas fee transaksi!');
      }
    } else {
      // ignore: avoid_print
      print('PERINGATAN: BLOCKCHAIN_OPERATOR_PRIVATE_KEY belum diisi di .env');
    }

    if (contractAddress.isNotEmpty && contractAddress != '0x0000000000000000000000000000000000000000') {
      // ignore: avoid_print
      print('Kontrak Amoy:  $contractAddress');
      // ignore: avoid_print
      print('Explorer URL:  https://amoy.polygonscan.com/address/$contractAddress');
    }
  } catch (e) {
    // ignore: avoid_print
    print('GAGAL terhubung ke RPC: $e');
  } finally {
    client.dispose();
    httpClient.close();
  }
  // ignore: avoid_print
  print('==================================================');
}
