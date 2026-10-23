import 'dart:math';
import 'package:web3dart/web3dart.dart';

void main() {
  final rng = Random.secure();
  final creds = EthPrivateKey.createRandom(rng);
  final address = '0x${creds.address}';
  final privateKeyHex = '0x${creds.privateKeyInt.toRadixString(16).padLeft(64, '0')}';

  // ignore: avoid_print
  print('==================================================');
  // ignore: avoid_print
  print('       HoloDex Polygon Amoy Wallet Generator      ');
  // ignore: avoid_print
  print('==================================================');
  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('Public Address:  $address');
  // ignore: avoid_print
  print('Private Key:     $privateKeyHex');
  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('Langkah Selanjutnya:');
  // ignore: avoid_print
  print('1. Buka Faucet Polygon Amoy di browser:');
  // ignore: avoid_print
  print('   https://faucet.polygon.technology/ atau https://www.alchemy.com/faucets/polygon-amoy');
  // ignore: avoid_print
  print('2. Masukkan Public Address di atas untuk mendapatkan gratis testnet POL.');
  // ignore: avoid_print
  print('3. Salin Private Key ke file .env Anda:');
  // ignore: avoid_print
  print('   BLOCKCHAIN_OPERATOR_PRIVATE_KEY=$privateKeyHex');
  // ignore: avoid_print
  print('==================================================');
}
