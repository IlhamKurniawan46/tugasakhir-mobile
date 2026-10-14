/// Model data kartu Pokémon TCG untuk katalog HoloDex.
/// Ditulis manual tanpa code generation sesuai konvensi AGENTS.md.
class CardModel {
  final String id;
  final String? localId;
  final String name;
  final String? setId;
  final String? setName;
  final String? rarity;
  final String? cardType;
  final String? imageUrl;
  final double? priceIdr;
  final double? priceUsd;
  final double? priceEur;
  final double? priceRefUsd;
  final String? priceSource;
  final bool hasPrice;
  final DateTime? seededAt;

  const CardModel({
    required this.id,
    this.localId,
    required this.name,
    this.setId,
    this.setName,
    this.rarity,
    this.cardType,
    this.imageUrl,
    this.priceIdr,
    this.priceUsd,
    this.priceEur,
    this.priceRefUsd,
    this.priceSource,
    this.hasPrice = false,
    this.seededAt,
  });

  /// URL gambar resolusi rendah untuk thumbnail grid / list (low.webp)
  String? get lowResImageUrl =>
      imageUrl != null && imageUrl!.isNotEmpty ? '$imageUrl/low.webp' : null;

  /// URL gambar resolusi tinggi untuk detail / efek holo (high.webp)
  String? get highResImageUrl =>
      imageUrl != null && imageUrl!.isNotEmpty ? '$imageUrl/high.webp' : null;

  /// Dari respons JSON Supabase (PostgREST)
  factory CardModel.fromJson(Map<String, dynamic> json) => CardModel(
        id: json['id'] as String,
        localId: json['local_id']?.toString(),
        name: json['name'] as String? ?? 'Unknown Card',
        setId: json['set_id'] as String?,
        setName: json['set_name'] as String?,
        rarity: json['rarity'] as String?,
        cardType: json['card_type'] as String?,
        imageUrl: json['image_url'] as String?,
        priceIdr: (json['price_idr'] as num?)?.toDouble(),
        priceUsd: (json['price_usd'] as num?)?.toDouble(),
        priceEur: (json['price_eur'] as num?)?.toDouble(),
        priceRefUsd: (json['price_ref_usd'] as num?)?.toDouble(),
        priceSource: json['price_source'] as String?,
        hasPrice: json['has_price'] as bool? ?? false,
        seededAt: json['seeded_at'] != null
            ? DateTime.tryParse(json['seeded_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'local_id': localId,
        'name': name,
        'set_id': setId,
        'set_name': setName,
        'rarity': rarity,
        'card_type': cardType,
        'image_url': imageUrl,
        'price_idr': priceIdr,
        'price_usd': priceUsd,
        'price_eur': priceEur,
        'price_ref_usd': priceRefUsd,
        'price_source': priceSource,
        'has_price': hasPrice,
        'seeded_at': seededAt?.toIso8601String(),
      };

  /// Dari baris SQLite lokal (sqflite)
  factory CardModel.fromMap(Map<String, dynamic> map) => CardModel(
        id: map['id'] as String,
        localId: map['local_id']?.toString(),
        name: map['name'] as String? ?? 'Unknown Card',
        setId: map['set_id'] as String?,
        setName: map['set_name'] as String?,
        rarity: map['rarity'] as String?,
        cardType: map['type'] as String? ?? map['card_type'] as String?,
        imageUrl: map['image_url'] as String?,
        priceIdr: (map['price_idr'] as num?)?.toDouble(),
        priceUsd: (map['price_usd'] as num?)?.toDouble(),
        priceEur: (map['price_eur'] as num?)?.toDouble(),
        priceRefUsd: (map['price_ref_usd'] as num?)?.toDouble(),
        priceSource: map['price_source'] as String?,
        hasPrice: (map['has_price'] as int? ?? 0) == 1,
        seededAt: map['last_synced'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_synced'] as int)
            : null,
      );

  /// Untuk disimpan ke SQLite lokal (tabel `cards`)
  Map<String, dynamic> toMap() => {
        'id': id,
        'local_id': localId,
        'name': name,
        'set_id': setId,
        'set_name': setName,
        'rarity': rarity,
        'type': cardType,
        'image_url': imageUrl,
        'price_idr': priceIdr,
        'price_usd': priceUsd,
        'price_eur': priceEur,
        'price_ref_usd': priceRefUsd,
        'price_source': priceSource,
        'has_price': hasPrice ? 1 : 0,
        'last_synced': DateTime.now().millisecondsSinceEpoch,
      };

  CardModel copyWith({
    String? id,
    String? localId,
    String? name,
    String? setId,
    String? setName,
    String? rarity,
    String? cardType,
    String? imageUrl,
    double? priceIdr,
    double? priceUsd,
    double? priceEur,
    double? priceRefUsd,
    String? priceSource,
    bool? hasPrice,
    DateTime? seededAt,
  }) =>
      CardModel(
        id: id ?? this.id,
        localId: localId ?? this.localId,
        name: name ?? this.name,
        setId: setId ?? this.setId,
        setName: setName ?? this.setName,
        rarity: rarity ?? this.rarity,
        cardType: cardType ?? this.cardType,
        imageUrl: imageUrl ?? this.imageUrl,
        priceIdr: priceIdr ?? this.priceIdr,
        priceUsd: priceUsd ?? this.priceUsd,
        priceEur: priceEur ?? this.priceEur,
        priceRefUsd: priceRefUsd ?? this.priceRefUsd,
        priceSource: priceSource ?? this.priceSource,
        hasPrice: hasPrice ?? this.hasPrice,
        seededAt: seededAt ?? this.seededAt,
      );
}
