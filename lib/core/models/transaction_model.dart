import 'card_model.dart';

/// Model data transaksi jual beli kartu di Marketplace HoloDex.
/// Ditulis manual tanpa code generation sesuai konvensi AGENTS.md.
class TransactionModel {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String cardId;
  final double priceIdr;
  final DateTime? createdAt;
  final String? txHash;
  final String? tokenId;
  final String? contractAddress;
  final String? blockchainStatus;

  // Joined fields
  final CardModel? card;
  final String? buyerUsername;
  final String? sellerUsername;
  final bool isBuyer;

  const TransactionModel({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.cardId,
    required this.priceIdr,
    this.createdAt,
    this.txHash,
    this.tokenId,
    this.contractAddress,
    this.blockchainStatus = 'confirmed',
    this.card,
    this.buyerUsername,
    this.sellerUsername,
    this.isBuyer = true,
  });

  /// Potongan TxHash untuk tampilan mobile
  String? get shortTxHash {
    if (txHash == null || txHash!.isEmpty) return null;
    if (txHash!.length <= 12) return txHash;
    return '${txHash!.substring(0, 6)}...${txHash!.substring(txHash!.length - 4)}';
  }

  TransactionModel copyWith({
    String? id,
    String? listingId,
    String? buyerId,
    String? sellerId,
    String? cardId,
    double? priceIdr,
    DateTime? createdAt,
    String? txHash,
    String? tokenId,
    String? contractAddress,
    String? blockchainStatus,
    CardModel? card,
    String? buyerUsername,
    String? sellerUsername,
    bool? isBuyer,
  }) =>
      TransactionModel(
        id: id ?? this.id,
        listingId: listingId ?? this.listingId,
        buyerId: buyerId ?? this.buyerId,
        sellerId: sellerId ?? this.sellerId,
        cardId: cardId ?? this.cardId,
        priceIdr: priceIdr ?? this.priceIdr,
        createdAt: createdAt ?? this.createdAt,
        txHash: txHash ?? this.txHash,
        tokenId: tokenId ?? this.tokenId,
        contractAddress: contractAddress ?? this.contractAddress,
        blockchainStatus: blockchainStatus ?? this.blockchainStatus,
        card: card ?? this.card,
        buyerUsername: buyerUsername ?? this.buyerUsername,
        sellerUsername: sellerUsername ?? this.sellerUsername,
        isBuyer: isBuyer ?? this.isBuyer,
      );

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'] as String,
        listingId: json['listing_id'] as String,
        buyerId: json['buyer_id'] as String,
        sellerId: json['seller_id'] as String,
        cardId: json['card_id'] as String,
        priceIdr: (json['price_idr'] as num?)?.toDouble() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        txHash: json['tx_hash'] as String?,
        tokenId: json['token_id'] as String?,
        contractAddress: json['contract_address'] as String?,
        blockchainStatus: json['blockchain_status'] as String? ?? 'confirmed',
        card: json['card'] != null
            ? CardModel.fromJson(Map<String, dynamic>.from(json['card'] as Map))
            : null,
        buyerUsername: json['buyer_username'] as String?,
        sellerUsername: json['seller_username'] as String?,
        isBuyer: json['is_buyer'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'buyer_id': buyerId,
        'seller_id': sellerId,
        'card_id': cardId,
        'price_idr': priceIdr,
        'created_at': createdAt?.toIso8601String(),
        if (txHash != null) 'tx_hash': txHash,
        if (tokenId != null) 'token_id': tokenId,
        if (contractAddress != null) 'contract_address': contractAddress,
        if (blockchainStatus != null) 'blockchain_status': blockchainStatus,
        if (card != null) 'card': card!.toJson(),
        if (buyerUsername != null) 'buyer_username': buyerUsername,
        if (sellerUsername != null) 'seller_username': sellerUsername,
        'is_buyer': isBuyer,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel.fromJson(map);

  Map<String, dynamic> toMap() => toJson();
}
