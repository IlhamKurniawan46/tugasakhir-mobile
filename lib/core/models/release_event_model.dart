/// Model data jadwal rilis kartu dan turnamen Pokémon TCG untuk HoloDex.
/// Ditulis manual tanpa code generation sesuai konvensi AGENTS.md.
class ReleaseEventModel {
  final String id;
  final String title;
  final String eventType; // 'set_release' | 'tournament'
  final DateTime eventDate; // Timestamp UTC
  final String? description;
  final String? setId;
  final String? location;

  const ReleaseEventModel({
    required this.id,
    required this.title,
    required this.eventType,
    required this.eventDate,
    this.description,
    this.setId,
    this.location,
  });

  bool get isSetRelease => eventType == 'set_release';
  bool get isTournament => eventType == 'tournament';

  /// Dari respons JSON Supabase
  factory ReleaseEventModel.fromJson(Map<String, dynamic> json) {
    return ReleaseEventModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Event Pokémon',
      eventType: json['event_type'] as String? ?? 'set_release',
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      description: json['description'] as String?,
      setId: json['set_id'] as String?,
      location: json['location'] as String?,
    );
  }

  /// Ke JSON Supabase
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'event_type': eventType,
        'event_date': eventDate.toIso8601String(),
        'description': description,
        'set_id': setId,
        'location': location,
      };

  /// Dari SQLite / Local Map
  factory ReleaseEventModel.fromMap(Map<String, dynamic> map) {
    return ReleaseEventModel(
      id: map['id']?.toString() ?? '',
      title: map['title'] as String? ?? 'Event Pokémon',
      eventType: map['event_type'] as String? ?? 'set_release',
      eventDate: map['event_date'] != null
          ? (map['event_date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['event_date'] as int, isUtc: true)
              : DateTime.tryParse(map['event_date'].toString())?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      description: map['description'] as String?,
      setId: map['set_id'] as String?,
      location: map['location'] as String?,
    );
  }

  /// Ke SQLite / Local Map
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'event_type': eventType,
        'event_date': eventDate.millisecondsSinceEpoch,
        'description': description,
        'set_id': setId,
        'location': location,
      };

  /// Daftar contoh event resmi Pokémon TCG (Rilis Set & Turnamen)
  /// Digunakan sebagai seed dan fallback offline
  static List<ReleaseEventModel> get defaultEvents {
    final now = DateTime.now().toUtc();
    return [
      ReleaseEventModel(
        id: 'event-battle-deck-30th',
        title: '30th Celebration Battle Deck (Espeon & Umbreon)',
        eventType: 'set_release',
        eventDate: DateTime.utc(2026, 10, 30, 0, 0, 0),
        description: 'Rilis produk resmi. Tanggal dapat berubah, cek sumber resmi.',
        location: 'Global (Pokémon Center & Toko Hobi)',
      ),
      ReleaseEventModel(
        id: 'event-upc-30th',
        title: '30th Celebration Ultra-Premium Collection',
        eventType: 'set_release',
        eventDate: DateTime.utc(2026, 11, 6, 0, 0, 0),
        description: 'Rilis produk resmi. Tanggal dapat berubah, cek sumber resmi.',
        location: 'Global Launch',
      ),
      ReleaseEventModel(
        id: 'event-holodex-cup',
        title: 'Turnamen Daring HoloDex Cup',
        eventType: 'tournament',
        eventDate: now.add(const Duration(days: 10, hours: 8)),
        description: 'Event fiktif HoloDex.',
        location: 'Online Tournament (Discord & PTGCL)',
      ),
    ];
  }
}
