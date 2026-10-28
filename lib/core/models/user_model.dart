class UserModel {
  final String id;
  final String username;
  final String? email;
  final String? photoUrl;
  final double balanceIdr;
  final bool fingerprintEnabled;
  final String? whatsappNumber;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    this.photoUrl,
    this.balanceIdr = 0,
    this.fingerprintEnabled = false,
    this.whatsappNumber,
    this.createdAt,
  });

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? photoUrl,
    double? balanceIdr,
    bool? fingerprintEnabled,
    String? whatsappNumber,
    bool resetWhatsappNumber = false,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        photoUrl: photoUrl ?? this.photoUrl,
        balanceIdr: balanceIdr ?? this.balanceIdr,
        fingerprintEnabled: fingerprintEnabled ?? this.fingerprintEnabled,
        whatsappNumber: resetWhatsappNumber
            ? null
            : (whatsappNumber ?? this.whatsappNumber),
        createdAt: createdAt ?? this.createdAt,
      );

  /// Dari respons Supabase (RPC register_user / get_login_credentials / get_user_profile).
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String?,
        photoUrl: json['photo_url'] as String?,
        balanceIdr: (json['balance_idr'] as num?)?.toDouble() ?? 0,
        fingerprintEnabled: json['fingerprint_enabled'] as bool? ?? false,
        whatsappNumber: json['whatsapp_number'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'photo_url': photoUrl,
        'balance_idr': balanceIdr,
        'fingerprint_enabled': fingerprintEnabled,
        'whatsapp_number': whatsappNumber,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Dari baris SQLite lokal. Bool disimpan sebagai 0/1, waktu sebagai epoch ms.
  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as String,
        username: map['username'] as String,
        email: map['email'] as String?,
        photoUrl: map['photo_path'] as String?,
        balanceIdr: (map['balance_idr'] as num?)?.toDouble() ?? 0,
        fingerprintEnabled: (map['fingerprint_enabled'] as int? ?? 0) == 1,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  /// Untuk tabel users SQLite. password_hash & salt tidak disimpan lokal:
  /// kolomnya NOT NULL, jadi diisi string kosong.
  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'email': email,
        'password_hash': '',
        'salt': '',
        'photo_path': photoUrl,
        'balance_idr': balanceIdr,
        'fingerprint_enabled': fingerprintEnabled ? 1 : 0,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };
}
