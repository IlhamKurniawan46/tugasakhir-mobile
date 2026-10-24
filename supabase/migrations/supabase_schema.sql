-- ============================================================
-- Supabase Schema
-- Buka Supabase Dashboard -> SQL Editor -> New Query -> Tempel & Run
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- USERS (custom auth PBKDF2, bukan Supabase Auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  photo_url TEXT,
  balance_idr NUMERIC(15,2) DEFAULT 100000.00,
  fingerprint_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- CARDS (katalog di-seed oleh tools/seed_catalog.dart)
CREATE TABLE IF NOT EXISTS cards (
  id TEXT PRIMARY KEY,
  local_id TEXT,
  name TEXT NOT NULL,
  set_id TEXT,
  set_name TEXT,
  rarity TEXT,
  card_type TEXT,
  image_url TEXT,
  price_idr NUMERIC(15,2),
  price_usd NUMERIC(10,4),
  price_eur NUMERIC(10,4),
  price_source TEXT,
  has_price BOOLEAN DEFAULT FALSE,
  seeded_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cards_price_idr ON cards(price_idr DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_cards_set_id ON cards(set_id);
CREATE INDEX IF NOT EXISTS idx_cards_rarity ON cards(rarity);
CREATE INDEX IF NOT EXISTS idx_cards_name ON cards(name);
CREATE INDEX IF NOT EXISTS idx_cards_has_price ON cards(has_price);

-- LISTINGS (marketplace peer-to-peer)
CREATE TABLE IF NOT EXISTS listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id TEXT NOT NULL REFERENCES cards(id),
  seller_id UUID NOT NULL REFERENCES users(id),
  price_idr NUMERIC(15,2) NOT NULL,
  condition TEXT CHECK (condition IN ('mint','near_mint','excellent','good','poor')),
  description TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','sold','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status);
CREATE INDEX IF NOT EXISTS idx_listings_card_id ON listings(card_id);
CREATE INDEX IF NOT EXISTS idx_listings_seller_id ON listings(seller_id);

-- TRANSACTIONS
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES listings(id),
  buyer_id UUID NOT NULL REFERENCES users(id),
  seller_id UUID NOT NULL REFERENCES users(id),
  card_id TEXT NOT NULL REFERENCES cards(id),
  price_idr NUMERIC(15,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- BLOCKCHAIN BLOCKS (riwayat desentralisasi)
CREATE TABLE IF NOT EXISTS blockchain_blocks (
  block_index BIGINT NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id),
  timestamp_utc TIMESTAMPTZ NOT NULL,
  event_type TEXT NOT NULL,
  data_json JSONB NOT NULL,
  previous_hash TEXT NOT NULL,
  block_hash TEXT NOT NULL,
  PRIMARY KEY(user_id, block_index)
);

-- COLLECTIONS (kartu yang dimiliki user)
CREATE TABLE IF NOT EXISTS collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  card_id TEXT NOT NULL REFERENCES cards(id),
  acquired_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT,
  UNIQUE(user_id, card_id)
);

-- GAME SCORES (leaderboard pack opening)
CREATE TABLE IF NOT EXISTS game_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  username TEXT NOT NULL,
  score_idr NUMERIC(15,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_game_scores_score ON game_scores(score_idr DESC);

-- EVENTS KALENDER (rilis & jadwal)
CREATE TABLE IF NOT EXISTS release_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  event_type TEXT CHECK (event_type IN ('set_release','tournament','sale','custom')),
  event_date TIMESTAMPTZ NOT NULL,
  description TEXT,
  set_id TEXT
);

INSERT INTO release_events (title, event_type, event_date, description) VALUES
  ('30th Celebration Battle Deck (Espeon & Umbreon)', 'set_release', '2026-10-30T00:00:00Z', 'Rilis produk resmi. Tanggal dapat berubah, cek sumber resmi.'),
  ('30th Celebration Ultra-Premium Collection', 'set_release', '2026-11-06T00:00:00Z', 'Rilis produk resmi. Tanggal dapat berubah, cek sumber resmi.'),
  ('Turnamen Daring HoloDex Cup', 'tournament', '2026-11-15T08:00:00Z', 'Event fiktif HoloDex.')
ON CONFLICT DO NOTHING;

-- ============================================================
-- FUNGSI ATOMIK: BELI LISTING
-- ============================================================
CREATE OR REPLACE FUNCTION buy_listing(
  p_listing_id UUID,
  p_buyer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_listing listings%ROWTYPE;
  v_buyer users%ROWTYPE;
  v_transaction_id UUID;
BEGIN
  -- Lock listing
  SELECT * INTO v_listing FROM listings WHERE id = p_listing_id FOR UPDATE;

  IF v_listing.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing sudah tidak tersedia');
  END IF;

  IF v_listing.seller_id = p_buyer_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tidak bisa membeli listing sendiri');
  END IF;

  SELECT * INTO v_buyer FROM users WHERE id = p_buyer_id FOR UPDATE;
  IF v_buyer.balance_idr < v_listing.price_idr THEN
    RETURN jsonb_build_object('success', false, 'error', 'Saldo tidak mencukupi');
  END IF;

  UPDATE users SET balance_idr = balance_idr - v_listing.price_idr WHERE id = p_buyer_id;
  UPDATE users SET balance_idr = balance_idr + v_listing.price_idr WHERE id = v_listing.seller_id;
  UPDATE listings SET status = 'sold', updated_at = NOW() WHERE id = p_listing_id;
  INSERT INTO collections (user_id, card_id) VALUES (p_buyer_id, v_listing.card_id)
    ON CONFLICT (user_id, card_id) DO NOTHING;
  DELETE FROM collections WHERE user_id = v_listing.seller_id AND card_id = v_listing.card_id;
  INSERT INTO transactions (listing_id, buyer_id, seller_id, card_id, price_idr)
    VALUES (p_listing_id, p_buyer_id, v_listing.seller_id, v_listing.card_id, v_listing.price_idr)
    RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'card_id', v_listing.card_id,
    'price_idr', v_listing.price_idr
  );
END;
$$;

-- ============================================================
-- ROW LEVEL SECURITY & PERMISSIONS
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Grant akses baca anon untuk tabel publik:
GRANT SELECT ON cards TO anon;
GRANT SELECT ON listings TO anon;
GRANT SELECT ON game_scores TO anon;
GRANT SELECT ON release_events TO anon;
GRANT EXECUTE ON FUNCTION buy_listing TO anon;
