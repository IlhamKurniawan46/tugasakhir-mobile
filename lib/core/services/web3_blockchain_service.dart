import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../utils/env_loader.dart';

/// Service terpusat untuk interaksi Web3 & Smart Contract ERC-721
/// pada jaringan Polygon Testnet (Amoy).
/// Mengikuti konvensi AGENTS.md (isolasi private key di .env, error handling aman tanpa crash).
class Web3BlockchainService {
  Web3BlockchainService._();
  static final Web3BlockchainService instance = Web3BlockchainService._();

  http.Client? _httpClient;
  Web3Client? _web3client;

  // ABI JSON minimal untuk HoloDexCertificate (ERC-721)
  static const String _contractAbiJson = '''
  [
    {
      "inputs": [],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "name": "ownerOf",
      "outputs": [{"name": "", "type": "address"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "name": "cardIdOf",
      "outputs": [{"name": "", "type": "string"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"name": "recipient", "type": "address"},
        {"name": "cardId", "type": "string"},
        {"name": "uri", "type": "string"}
      ],
      "name": "mintCard",
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"name": "from", "type": "address"},
        {"name": "to", "type": "address"},
        {"name": "tokenId", "type": "uint256"},
        {"name": "priceIdr", "type": "uint256"},
        {"name": "notes", "type": "string"}
      ],
      "name": "recordTransfer",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"name": "tokenId", "type": "uint256"}],
      "name": "getProvenanceCount",
      "outputs": [{"name": "", "type": "uint256"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"name": "tokenId", "type": "uint256"},
        {"name": "index", "type": "uint256"}
      ],
      "name": "getProvenanceEntry",
      "outputs": [
        {"name": "from", "type": "address"},
        {"name": "to", "type": "address"},
        {"name": "timestamp", "type": "uint256"},
        {"name": "priceIdr", "type": "uint256"},
        {"name": "notes", "type": "string"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  DeployedContract? _cachedContract;

  /// Inisialisasi klien Web3 ke RPC Polygon Amoy
  Web3Client get client {
    if (_web3client == null) {
      _httpClient = http.Client();
      _web3client = Web3Client(EnvLoader.polygonRpcUrl, _httpClient!);
    }
    return _web3client!;
  }

  /// Ambil objek DeployedContract jika alamat kontrak sudah diatur
  DeployedContract? get contract {
    final addressStr = EnvLoader.blockchainContractAddress;
    if (addressStr.isEmpty || !isValidAddress(addressStr)) {
      return null;
    }
    try {
      _cachedContract ??= DeployedContract(
        ContractAbi.fromJson(_contractAbiJson, 'HoloDexCertificate'),
        EthereumAddress.fromHex(addressStr),
      );
      return _cachedContract;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal memuat DeployedContract: $e');
      return null;
    }
  }

  /// Kredensial operator dari .env (Private Key)
  EthPrivateKey? get operatorCredentials {
    final key = EnvLoader.blockchainOperatorPrivateKey;
    if (key.isEmpty) return null;
    try {
      final sanitizedKey = key.startsWith('0x') ? key.substring(2) : key;
      return EthPrivateKey.fromHex(sanitizedKey);
    } catch (e) {
      debugPrint('[HoloDex Error] Format Private Key Operator tidak valid: $e');
      return null;
    }
  }

  /// Alamat publik operator
  EthereumAddress? get operatorAddress {
    final creds = operatorCredentials;
    if (creds == null) return null;
    return creds.address;
  }

  /// Validasi format alamat Ethereum (0x + 40 hex char)
  bool isValidAddress(String address) {
    final clean = address.trim();
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(clean);
  }

  /// Validasi format hash transaksi Ethereum/Polygon (0x + 64 hex char)
  bool isValidTxHash(String hash) {
    final clean = hash.trim();
    return RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(clean);
  }

  /// Format potongan hash ramah tampilan mobile (misal: 0x3a1b...8f4c)
  String formatShortHash(String hash) {
    final clean = hash.trim();
    if (clean.length <= 12) return clean;
    return '${clean.substring(0, 6)}...${clean.substring(clean.length - 4)}';
  }

  /// Format potongan alamat (misal: 0x3a1b...8f4c)
  String formatShortAddress(String address) {
    final clean = address.trim();
    if (clean.length <= 10) return clean;
    return '${clean.substring(0, 6)}...${clean.substring(clean.length - 4)}';
  }

  /// Tautan web explorer PolygonScan untuk transaksi
  String getExplorerTxUrl(String txHash) {
    final base = EnvLoader.polygonExplorerBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/tx/$txHash';
  }

  /// Tautan web explorer PolygonScan untuk alamat / kontrak
  String getExplorerAddressUrl(String address) {
    final base = EnvLoader.polygonExplorerBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/address/$address';
  }

  /// Cek koneksi RPC & ambil nomor blok terkini Polygon Amoy
  Future<int?> getCurrentBlockNumber() async {
    try {
      return await client.getBlockNumber();
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal membaca block number: $e');
      return null;
    }
  }

  /// Cek saldo POL/MATIC akun operator
  Future<EtherAmount?> getOperatorBalance() async {
    final addr = operatorAddress;
    if (addr == null) return null;
    try {
      return await client.getBalance(addr);
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal cek saldo operator: $e');
      return null;
    }
  }

  /// Minting Sertifikat Keaslian Baru ke Polygon Amoy
  /// Mengembalikan TxHash transaksi on-chain jika sukses
  Future<String?> mintCertificate({
    required String cardId,
    required String cardName,
    String? recipientAddress,
    String? metadataUri,
  }) async {
    final creds = operatorCredentials;
    if (creds == null) {
      debugPrint('[HoloDex Error] Operator private key belum diset di .env');
      return null;
    }

    final deployed = contract;
    if (deployed == null) {
      debugPrint('[HoloDex Error] Alamat kontrak belum valid atau belum diset di .env');
      return null;
    }

    final targetRecipient = (recipientAddress != null && isValidAddress(recipientAddress))
        ? EthereumAddress.fromHex(recipientAddress)
        : creds.address;

    final uri = metadataUri ?? 'https://holodex.app/api/cards/$cardId';

    try {
      final function = deployed.function('mintCard');
      final txHash = await client.sendTransaction(
        creds,
        Transaction.callContract(
          contract: deployed,
          function: function,
          parameters: [targetRecipient, cardId, uri],
          maxGas: 300000,
        ),
        chainId: EnvLoader.polygonChainId,
      );

      debugPrint('[HoloDex Web3] Minting sukses, TxHash: $txHash');
      return txHash;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal minting sertifikat on-chain: $e');
      return null;
    }
  }

  /// Mencatat riwayat pemindahan kepemilikan token on-chain (recordTransfer)
  /// Mengembalikan TxHash transaksi on-chain jika sukses
  Future<String?> recordTransferOnChain({
    required BigInt tokenId,
    required String fromAddress,
    required String toAddress,
    required double priceIdr,
    String notes = 'Marketplace Purchase',
  }) async {
    final creds = operatorCredentials;
    if (creds == null) {
      debugPrint('[HoloDex Error] Operator private key belum diset di .env');
      return null;
    }

    final deployed = contract;
    if (deployed == null) {
      debugPrint('[HoloDex Error] Alamat kontrak belum valid atau belum diset di .env');
      return null;
    }

    if (!isValidAddress(fromAddress) || !isValidAddress(toAddress)) {
      debugPrint('[HoloDex Error] Alamat pengirim atau penerima tidak valid: from=$fromAddress to=$toAddress');
      return null;
    }

    try {
      final function = deployed.function('recordTransfer');
      final txHash = await client.sendTransaction(
        creds,
        Transaction.callContract(
          contract: deployed,
          function: function,
          parameters: [
            EthereumAddress.fromHex(fromAddress),
            EthereumAddress.fromHex(toAddress),
            tokenId,
            BigInt.from(priceIdr.toInt()),
            notes,
          ],
          maxGas: 350000,
        ),
        chainId: EnvLoader.polygonChainId,
      );

      debugPrint('[HoloDex Web3] Record transfer on-chain sukses, TxHash: $txHash');
      return txHash;
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal record transfer on-chain: $e');
      return null;
    }
  }

  /// Menutup koneksi Web3 saat aplikasi ditutup
  void dispose() {
    _web3client?.dispose();
    _httpClient?.close();
    _web3client = null;
    _httpClient = null;
    _cachedContract = null;
  }
}
