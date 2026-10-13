import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';

class LocalDb {
  static Database? _database;

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, AppConstants.localDbName);

      return await openDatabase(
        path,
        version: AppConstants.localDbVersion,
        onCreate: _onCreate,
      );
    } catch (e) {
      print('[HoloDex Error] Gagal inisialisasi SQLite: $e');
      rethrow;
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Versi skema
    batch.execute('''
      CREATE TABLE schema_version (
        version INTEGER PRIMARY KEY
      )
    ''');
    batch.execute('INSERT INTO schema_version (version) VALUES ($version)');

    // 2. Cache kartu katalog
    batch.execute('''
      CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        local_id TEXT,
        name TEXT NOT NULL,
        set_id TEXT,
        set_name TEXT,
        rarity TEXT,
        type TEXT,
        image_url TEXT,
        price_idr REAL,
        price_usd REAL,
        price_eur REAL,
        last_synced INTEGER
      )
    ''');
    batch.execute('CREATE INDEX idx_cards_price_idr ON cards(price_idr DESC)');
    batch.execute('CREATE INDEX idx_cards_set ON cards(set_id)');

    // 3. Sesi user aktif
    batch.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        token TEXT UNIQUE NOT NULL,
        expires_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 4. Profil user lokal
    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        photo_path TEXT,
        balance_idr REAL DEFAULT 0,
        fingerprint_enabled INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    // 5. Koleksi user
    batch.execute('''
      CREATE TABLE collection (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        card_id TEXT NOT NULL,
        acquired_at INTEGER,
        UNIQUE(user_id, card_id)
      )
    ''');

    // 6. Watchlist harga
    batch.execute('''
      CREATE TABLE watchlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        card_id TEXT NOT NULL,
        alert_price_idr REAL,
        added_at INTEGER,
        UNIQUE(user_id, card_id)
      )
    ''');

    // 7. Blockchain ledger lokal
    batch.execute('''
      CREATE TABLE blockchain (
        block_index INTEGER PRIMARY KEY,
        user_id TEXT NOT NULL,
        timestamp_utc TEXT NOT NULL,
        event_type TEXT NOT NULL,
        data_json TEXT NOT NULL,
        previous_hash TEXT NOT NULL,
        block_hash TEXT NOT NULL
      )
    ''');

    // 8. Cache kurs mata uang (Frankfurter)
    batch.execute('''
      CREATE TABLE currency_cache (
        base TEXT NOT NULL,
        target TEXT NOT NULL,
        rate REAL NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(base, target)
      )
    ''');

    // 9. Riwayat transaksi
    batch.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        listing_id TEXT,
        buyer_id TEXT,
        seller_id TEXT,
        card_id TEXT,
        price_idr REAL,
        event_type TEXT,
        created_at INTEGER
      )
    ''');

    // 10. Skor mini game
    batch.execute('''
      CREATE TABLE game_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        score_idr REAL NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // 11. Cache listing marketplace
    batch.execute('''
      CREATE TABLE listings (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        seller_id TEXT NOT NULL,
        price_idr REAL NOT NULL,
        condition TEXT,
        description TEXT,
        lat REAL,
        lng REAL,
        status TEXT DEFAULT 'active',
        created_at INTEGER,
        last_synced INTEGER
      )
    ''');

    await batch.commit(noResult: true);
    print('[HoloDex] SQLite initialized - semua 11 tabel lokal berhasil dibuat');
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
