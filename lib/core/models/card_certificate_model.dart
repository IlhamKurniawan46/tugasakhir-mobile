/// Model data Sertifikat Keaslian & Riwayat Kepemilikan (Provenance) Kartu di Blockchain Polygon.
/// Ditulis manual tanpa code generation sesuai konvensi AGENTS.md.
class CardCertificateModel {
  final String id;
  final String cardId;
  final String tokenId;
  final String contractAddress;
  final String txHash;
  final String? fromAddress;
  final String toAddress;
  final String? ownerUsername;
  final String action; // 'minted' | 'transferred'
  final double priceIdr;
  final String? notes;
  final int? blockNumber;
  final DateTime? createdAt;

  const CardCertificateModel({
    required this.id,
    required this.cardId,
    required this.tokenId,
    required this.contractAddress,
    required this.txHash,
    this.fromAddress,
    required this.toAddress,
    this.ownerUsername,
    this.action = 'minted',
    this.priceIdr = 0,
    this.notes,
    this.blockNumber,
    this.createdAt,
  });

  bool get isMinted => action == 'minted';

  /// Format potongan hash ramah tampilan mobile (misal: 0x3a1b...8f4c)
  String get shortTxHash {
    if (txHash.length <= 12) return txHash;
    return '${txHash.substring(0, 6)}...${txHash.substring(txHash.length - 4)}';
  }

  /// Format potongan alamat Ethereum
  static String formatShortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  factory CardCertificateModel.fromJson(Map<String, dynamic> json) =>
      CardCertificateModel(
        id: json['id']?.toString() ?? '',
        cardId: json['card_id']?.toString() ?? '',
        tokenId: json['token_id']?.toString() ?? '',
        contractAddress: json['contract_address']?.toString() ?? '',
        txHash: json['tx_hash']?.toString() ?? '',
        fromAddress: json['from_address']?.toString(),
        toAddress: json['to_address']?.toString() ?? '',
        ownerUsername: json['owner_username']?.toString(),
        action: json['action']?.toString() ?? 'minted',
        priceIdr: (json['price_idr'] as num?)?.toDouble() ?? 0,
        notes: json['notes']?.toString(),
        blockNumber: (json['block_number'] as num?)?.toInt(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'card_id': cardId,
        'token_id': tokenId,
        'contract_address': contractAddress,
        'tx_hash': txHash,
        'from_address': fromAddress,
        'to_address': toAddress,
        'owner_username': ownerUsername,
        'action': action,
        'price_idr': priceIdr,
        'notes': notes,
        'block_number': blockNumber,
        'created_at': createdAt?.toIso8601String(),
      };

  factory CardCertificateModel.fromMap(Map<String, dynamic> map) =>
      CardCertificateModel(
        id: map['id']?.toString() ?? '',
        cardId: map['card_id']?.toString() ?? '',
        tokenId: map['token_id']?.toString() ?? '',
        contractAddress: map['contract_address']?.toString() ?? '',
        txHash: map['tx_hash']?.toString() ?? '',
        fromAddress: map['from_address']?.toString(),
        toAddress: map['to_address']?.toString() ?? '',
        ownerUsername: map['owner_username']?.toString(),
        action: map['action']?.toString() ?? 'minted',
        priceIdr: (map['price_idr'] as num?)?.toDouble() ?? 0,
        notes: map['notes']?.toString(),
        blockNumber: (map['block_number'] as num?)?.toInt(),
        createdAt: map['created_at'] != null
            ? (map['created_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
                : DateTime.tryParse(map['created_at'].toString()))
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'card_id': cardId,
        'token_id': tokenId,
        'contract_address': contractAddress,
        'tx_hash': txHash,
        'from_address': fromAddress,
        'to_address': toAddress,
        'owner_username': ownerUsername,
        'action': action,
        'price_idr': priceIdr,
        'notes': notes,
        'block_number': blockNumber,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };
}
