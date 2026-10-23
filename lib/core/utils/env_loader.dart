import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvLoader {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // Jika file .env belum dibuat atau gagal dibaca
      print('[HoloDex Error] Gagal memuat file .env: $e');
    }
  }

  static String get supabaseUrl {
    if (!dotenv.isInitialized) return '';
    final raw = (dotenv.env['SUPABASE_URL'] ?? '').trim();
    // Hilangkan trailing /rest/v1 atau garis miring di akhir jika terisi tidak sengaja
    return raw
        .replaceAll(RegExp(r'/rest/v1/?$'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  static String get supabaseAnonKey {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();
  }

  static String get geminiApiKey {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
  }

  // Blockchain Configuration (Polygon Amoy Testnet)
  static String get polygonRpcUrl {
    if (!dotenv.isInitialized) return 'https://polygon-amoy-bor-rpc.publicnode.com';
    final url = dotenv.env['POLYGON_AMOY_RPC_URL']?.trim();
    return (url != null && url.isNotEmpty)
        ? url
        : 'https://polygon-amoy-bor-rpc.publicnode.com';
  }

  static int get polygonChainId {
    if (!dotenv.isInitialized) return 80002;
    final val = int.tryParse(dotenv.env['POLYGON_CHAIN_ID'] ?? '');
    return val ?? 80002;
  }

  static String get blockchainContractAddress {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env['BLOCKCHAIN_CONTRACT_ADDRESS'] ?? '').trim();
  }

  static String get blockchainOperatorPrivateKey {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env['BLOCKCHAIN_OPERATOR_PRIVATE_KEY'] ?? '').trim();
  }

  static String get polygonExplorerBaseUrl {
    if (!dotenv.isInitialized) return 'https://amoy.polygonscan.com';
    final url = dotenv.env['POLYGON_EXPLORER_BASE_URL']?.trim();
    return (url != null && url.isNotEmpty) ? url : 'https://amoy.polygonscan.com';
  }

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('your-anon-key');
}
