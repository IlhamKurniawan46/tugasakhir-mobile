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
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('[HoloDex Error] Gagal inisialisasi SQLite: $e');
      rethrow;
    }
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE cards ADD COLUMN price_ref_usd REAL');
        await db.execute('ALTER TABLE cards ADD COLUMN price_source TEXT');
        await db.execute('ALTER TABLE cards ADD COLUMN has_price INTEGER DEFAULT 0');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cards_price_ref_usd ON cards(price_ref_usd DESC)',
        );
      } catch (e) {
        print('[HoloDex Error] Gagal migrasi SQLite v2: $e');
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE currency_cache ADD COLUMN ecb_date TEXT');
      } catch (e) {
        print('[HoloDex Error] Gagal migrasi SQLite v3: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
          "ALTER TABLE collection ADD COLUMN acquired_via TEXT DEFAULT 'purchase'",
        );
      } catch (e) {
        print('[HoloDex Error] Gagal migrasi SQLite v4: $e');
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN tx_hash TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN token_id TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN contract_address TEXT');
        await db.execute("ALTER TABLE transactions ADD COLUMN blockchain_status TEXT DEFAULT 'confirmed'");

        await db.execute('ALTER TABLE collection ADD COLUMN tx_hash TEXT');
        await db.execute('ALTER TABLE collection ADD COLUMN token_id TEXT');
        await db.execute('ALTER TABLE collection ADD COLUMN contract_address TEXT');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS card_certificates (
            id TEXT PRIMARY KEY,
            card_id TEXT NOT NULL,
            token_id TEXT NOT NULL,
            contract_address TEXT NOT NULL,
            tx_hash TEXT NOT NULL,
            from_address TEXT,
            to_address TEXT NOT NULL,
            owner_username TEXT,
            action TEXT DEFAULT 'minted',
            price_idr REAL DEFAULT 0,
            notes TEXT,
            block_number INTEGER,
            created_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_cert_card_id ON card_certificates(card_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_cert_token_id ON card_certificates(token_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_cert_tx_hash ON card_certificates(tx_hash)');
      } catch (e) {
        print('[HoloDex Error] Gagal migrasi SQLite v5: $e');
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_interactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            event_type TEXT NOT NULL,
            card_id TEXT,
            query_text TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_interactions_user_id ON user_interactions(user_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_interactions_created_at ON user_interactions(created_at)',
        );
      } catch (e) {
        print('[HoloDex Error] Gagal migrasi SQLite v6: $e');
      }
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
        price_ref_usd REAL,
        price_source TEXT,
        has_price INTEGER DEFAULT 0,
        last_synced INTEGER
      )
    ''');
    batch.execute('CREATE INDEX idx_cards_price_idr ON cards(price_idr DESC)');
    batch.execute('CREATE INDEX idx_cards_price_ref_usd ON cards(price_ref_usd DESC)');
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

    // 5. Koleksi user (Koleksi Saya)
    batch.execute('''
      CREATE TABLE collection (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        card_id TEXT NOT NULL,
        acquired_via TEXT DEFAULT 'purchase',
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
        ecb_date TEXT,
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

    // 12. Sertifikat blockchain & riwayat kepemilikan lokal
    batch.execute('''
      CREATE TABLE card_certificates (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        token_id TEXT NOT NULL,
        contract_address TEXT NOT NULL,
        tx_hash TEXT NOT NULL,
        from_address TEXT,
        to_address TEXT NOT NULL,
        owner_username TEXT,
        action TEXT DEFAULT 'minted',
        price_idr REAL DEFAULT 0,
        notes TEXT,
        block_number INTEGER,
        created_at INTEGER
      )
    ''');
    batch.execute('CREATE INDEX idx_cert_card_id ON card_certificates(card_id)');
    batch.execute('CREATE INDEX idx_cert_token_id ON card_certificates(token_id)');
    batch.execute('CREATE INDEX idx_cert_tx_hash ON card_certificates(tx_hash)');

    // 13. Interaksi pengguna lokal untuk mesin rekomendasi (Sesi Tambahan AI)
    batch.execute('''
      CREATE TABLE user_interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        card_id TEXT,
        query_text TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_interactions_user_id ON user_interactions(user_id)');
    batch.execute('CREATE INDEX idx_interactions_created_at ON user_interactions(created_at)');

    await batch.commit(noResult: true);
    print('[HoloDex] SQLite initialized - semua 13 tabel lokal berhasil dibuat');
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
