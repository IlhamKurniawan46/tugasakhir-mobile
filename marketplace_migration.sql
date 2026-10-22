-- ============================================================
-- HOLODEX — Sesi 10: Marketplace Peer-to-Peer (P2P) Migration
-- (Tanpa Ledger Blockchain sesuai arahan pengguna)
-- Jalankan file ini di Supabase SQL Editor
-- ============================================================

-- 1. TABEL LISTINGS (jika belum ada)
CREATE TABLE IF NOT EXISTS listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id TEXT NOT NULL REFERENCES cards(id),
  seller_id UUID NOT NULL REFERENCES users(id),
  price_idr NUMERIC(15,2) NOT NULL CHECK (price_idr > 0),
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
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at DESC);

-- 2. TABEL TRANSACTIONS (jika belum ada)
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES listings(id),
  buyer_id UUID NOT NULL REFERENCES users(id),
  seller_id UUID NOT NULL REFERENCES users(id),
  card_id TEXT NOT NULL REFERENCES cards(id),
  price_idr NUMERIC(15,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);

-- 3. GRANT AKSES TABEL KE ROLE anon
GRANT SELECT, INSERT, UPDATE ON listings TO anon;
GRANT SELECT, INSERT ON transactions TO anon;

-- 4. RPC: Ambil Daftar Listing Aktif (lengkap info kartu & penjual)
CREATE OR REPLACE FUNCTION get_active_listings(
  p_card_id TEXT DEFAULT NULL,
  p_seller_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', l.id,
      'card_id', l.card_id,
      'seller_id', l.seller_id,
      'seller_username', u.username,
      'seller_photo_url', u.photo_url,
      'price_idr', l.price_idr,
      'condition', l.condition,
      'description', l.description,
      'lat', l.lat,
      'lng', l.lng,
      'status', l.status,
      'created_at', l.created_at,
      'updated_at', l.updated_at,
      'card', jsonb_build_object(
        'id', k.id,
        'local_id', k.local_id,
        'name', k.name,
        'set_id', k.set_id,
        'set_name', k.set_name,
        'rarity', k.rarity,
        'card_type', k.card_type,
        'image_url', k.image_url,
        'price_idr', k.price_idr,
        'price_usd', k.price_usd,
        'price_eur', k.price_eur,
        'price_ref_usd', k.price_ref_usd,
        'price_source', k.price_source,
        'has_price', k.has_price
      )
    ) ORDER BY l.created_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM listings l
  JOIN cards k ON k.id = l.card_id
  JOIN users u ON u.id = l.seller_id
  WHERE l.status = 'active'
    AND (p_card_id IS NULL OR l.card_id = p_card_id)
    AND (p_seller_id IS NULL OR l.seller_id = p_seller_id);

  RETURN jsonb_build_object('success', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_active_listings(TEXT, UUID) TO anon;

-- 5. RPC: Ambil Detail Listing Tunggal
CREATE OR REPLACE FUNCTION get_listing_detail(p_listing_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'id', l.id,
    'card_id', l.card_id,
    'seller_id', l.seller_id,
    'seller_username', u.username,
    'seller_photo_url', u.photo_url,
    'price_idr', l.price_idr,
    'condition', l.condition,
    'description', l.description,
    'lat', l.lat,
    'lng', l.lng,
    'status', l.status,
    'created_at', l.created_at,
    'updated_at', l.updated_at,
    'card', jsonb_build_object(
      'id', k.id,
      'local_id', k.local_id,
      'name', k.name,
      'set_id', k.set_id,
      'set_name', k.set_name,
      'rarity', k.rarity,
      'card_type', k.card_type,
      'image_url', k.image_url,
      'price_idr', k.price_idr,
      'price_usd', k.price_usd,
      'price_eur', k.price_eur,
      'price_ref_usd', k.price_ref_usd,
      'price_source', k.price_source,
      'has_price', k.has_price
    )
  )
  INTO v_result
  FROM listings l
  JOIN cards k ON k.id = l.card_id
  JOIN users u ON u.id = l.seller_id
  WHERE l.id = p_listing_id;

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing tidak ditemukan');
  END IF;

  RETURN jsonb_build_object('success', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_listing_detail(UUID) TO anon;

-- 6. RPC: Pasang Listing Baru (Create Listing)
CREATE OR REPLACE FUNCTION create_listing(
  p_card_id TEXT,
  p_seller_id UUID,
  p_price_idr NUMERIC,
  p_condition TEXT,
  p_description TEXT DEFAULT NULL,
  p_lat DOUBLE PRECISION DEFAULT NULL,
  p_lng DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_id UUID;
BEGIN
  IF p_price_idr <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Harga harus lebih besar dari 0');
  END IF;

  IF p_condition NOT IN ('mint','near_mint','excellent','good','poor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kondisi kartu tidak valid');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cards WHERE id = p_card_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kartu tidak terdaftar di katalog');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_seller_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pengguna penjual tidak valid');
  END IF;

  INSERT INTO listings (
    card_id, seller_id, price_idr, condition, description, lat, lng, status
  ) VALUES (
    p_card_id, p_seller_id, p_price_idr, p_condition, p_description, p_lat, p_lng, 'active'
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('success', true, 'listing_id', v_new_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION create_listing(TEXT, UUID, NUMERIC, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO anon;

-- 7. RPC ATOMIK: Beli Listing (Transfer Saldo, Pindah Koleksi, Catat Transaksi)
CREATE OR REPLACE FUNCTION buy_listing(
  p_listing_id UUID,
  p_buyer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_listing listings%ROWTYPE;
  v_buyer users%ROWTYPE;
  v_seller users%ROWTYPE;
  v_transaction_id UUID;
  v_new_buyer_balance NUMERIC(15,2);
BEGIN
  -- 1. Lock listing row
  SELECT * INTO v_listing FROM listings WHERE id = p_listing_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing tidak ditemukan');
  END IF;

  IF v_listing.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing sudah tidak tersedia atau sudah terjual');
  END IF;

  IF v_listing.seller_id = p_buyer_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tidak bisa membeli listing milik sendiri');
  END IF;

  -- 2. Lock buyer
  SELECT * INTO v_buyer FROM users WHERE id = p_buyer_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Akun pembeli tidak ditemukan');
  END IF;

  -- 3. Lock seller
  SELECT * INTO v_seller FROM users WHERE id = v_listing.seller_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Akun penjual tidak ditemukan');
  END IF;

  -- 4. Cek saldo pembeli
  IF v_buyer.balance_idr < v_listing.price_idr THEN
    RETURN jsonb_build_object('success', false, 'error', 'Saldo tidak mencukupi untuk membeli kartu ini');
  END IF;

  -- 5. Mutasi saldo atomik
  UPDATE users 
  SET balance_idr = balance_idr - v_listing.price_idr 
  WHERE id = p_buyer_id
  RETURNING balance_idr INTO v_new_buyer_balance;

  UPDATE users 
  SET balance_idr = balance_idr + v_listing.price_idr 
  WHERE id = v_listing.seller_id;

  -- 6. Update status listing jadi 'sold'
  UPDATE listings 
  SET status = 'sold', updated_at = NOW() 
  WHERE id = p_listing_id;

  -- 7. Pindahkan / masukkan kartu ke koleksi pembeli (acquired_via = 'purchase')
  INSERT INTO collections (user_id, card_id, acquired_via, acquired_at) 
  VALUES (p_buyer_id, v_listing.card_id, 'purchase', NOW())
  ON CONFLICT (user_id, card_id) DO UPDATE 
    SET acquired_via = 'purchase', acquired_at = NOW();

  -- 8. Hapus dari koleksi penjual (jika penjual menjual kartu dari koleksinya)
  DELETE FROM collections 
  WHERE user_id = v_listing.seller_id AND card_id = v_listing.card_id;

  -- 9. Catat transaksi
  INSERT INTO transactions (listing_id, buyer_id, seller_id, card_id, price_idr)
  VALUES (p_listing_id, p_buyer_id, v_listing.seller_id, v_listing.card_id, v_listing.price_idr)
  RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'card_id', v_listing.card_id,
    'price_idr', v_listing.price_idr,
    'new_balance_idr', v_new_buyer_balance
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION buy_listing(UUID, UUID) TO anon;

-- 8. RPC: Batalkan Listing (Cancel Listing milik sendiri)
CREATE OR REPLACE FUNCTION cancel_listing(
  p_listing_id UUID,
  p_seller_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE listings 
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_listing_id 
    AND seller_id = p_seller_id 
    AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gagal membatalkan. Listing tidak ditemukan atau bukan milik Anda.');
  END IF;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_listing(UUID, UUID) TO anon;

-- 9. RPC: Ambil Riwayat Transaksi Pengguna
CREATE OR REPLACE FUNCTION get_user_transactions(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'listing_id', t.listing_id,
      'buyer_id', t.buyer_id,
      'seller_id', t.seller_id,
      'card_id', t.card_id,
      'price_idr', t.price_idr,
      'created_at', t.created_at,
      'is_buyer', (t.buyer_id = p_user_id),
      'buyer_username', ub.username,
      'seller_username', us.username,
      'card', jsonb_build_object(
        'id', k.id,
        'local_id', k.local_id,
        'name', k.name,
        'set_id', k.set_id,
        'set_name', k.set_name,
        'rarity', k.rarity,
        'card_type', k.card_type,
        'image_url', k.image_url
      )
    ) ORDER BY t.created_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM transactions t
  JOIN cards k ON k.id = t.card_id
  JOIN users ub ON ub.id = t.buyer_id
  JOIN users us ON us.id = t.seller_id
  WHERE t.buyer_id = p_user_id OR t.seller_id = p_user_id;

  RETURN jsonb_build_object('success', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_transactions(UUID) TO anon;

-- 10. RPC: Ambil Profil Pengguna Terkini (Refresh Saldo)
CREATE OR REPLACE FUNCTION get_user_profile(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user users%ROWTYPE;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pengguna tidak ditemukan');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user', jsonb_build_object(
      'id', v_user.id,
      'username', v_user.username,
      'email', v_user.email,
      'photo_url', v_user.photo_url,
      'balance_idr', v_user.balance_idr,
      'fingerprint_enabled', v_user.fingerprint_enabled,
      'created_at', v_user.created_at
    )
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_profile(UUID) TO anon;

-- 11. RPC: Top Up Saldo Simulasi (Demo Tugas Akhir)
CREATE OR REPLACE FUNCTION top_up_balance(p_user_id UUID, p_amount NUMERIC)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance NUMERIC(15,2);
BEGIN
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Jumlah top up harus lebih besar dari 0');
  END IF;

  UPDATE users 
  SET balance_idr = balance_idr + p_amount 
  WHERE id = p_user_id
  RETURNING balance_idr INTO v_new_balance;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pengguna tidak ditemukan');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'new_balance_idr', v_new_balance
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION top_up_balance(UUID, NUMERIC) TO anon;

-- ============================================================
-- 12. DATA SEED DEMO: 2 AKUN PENJUAL & LISTING CONTOH
-- (Jalankan blok ini di Supabase agar ada barang dagangan langsung)
-- ============================================================
DO $$
DECLARE
  v_seller1_id UUID;
  v_seller2_id UUID;
  v_card1 TEXT;
  v_card2 TEXT;
  v_card3 TEXT;
  v_card4 TEXT;
BEGIN
  -- Buat Akun Demo Seller 1 jika belum ada
  INSERT INTO users (username, email, password_hash, salt, balance_idr)
  VALUES ('Kolektor_Jakarta', 'seller_jkt@holodex.demo', 'dummy_hash_1', 'dummy_salt_1', 2500000)
  ON CONFLICT (username) DO UPDATE SET balance_idr = users.balance_idr
  RETURNING id INTO v_seller1_id;

  -- Buat Akun Demo Seller 2 jika belum ada
  INSERT INTO users (username, email, password_hash, salt, balance_idr)
  VALUES ('Bandung_TCG_Shop', 'seller_bdg@holodex.demo', 'dummy_hash_2', 'dummy_salt_2', 1800000)
  ON CONFLICT (username) DO UPDATE SET balance_idr = users.balance_idr
  RETURNING id INTO v_seller2_id;

  -- Ambil 4 ID kartu nyata yang ada di tabel cards
  SELECT id INTO v_card1 FROM cards WHERE has_price = true ORDER BY price_idr DESC NULLS LAST LIMIT 1;
  SELECT id INTO v_card2 FROM cards WHERE has_price = true AND id != v_card1 ORDER BY price_idr DESC NULLS LAST LIMIT 1 OFFSET 3;
  SELECT id INTO v_card3 FROM cards WHERE has_price = true AND id NOT IN (v_card1, v_card2) ORDER BY price_idr ASC NULLS LAST LIMIT 1 OFFSET 10;
  SELECT id INTO v_card4 FROM cards WHERE has_price = true AND id NOT IN (v_card1, v_card2, v_card3) ORDER BY price_idr ASC NULLS LAST LIMIT 1 OFFSET 20;

  -- Buat listing contoh jika kartu ditemukan
  IF v_card1 IS NOT NULL AND v_seller1_id IS NOT NULL THEN
    INSERT INTO listings (card_id, seller_id, price_idr, condition, description, lat, lng, status)
    VALUES 
      (v_card1, v_seller1_id, 450000, 'mint', 'Koleksi pribadi mulus no scratch, sudah double sleeve + toploader.', -6.2088, 106.8456, 'active'),
      (v_card2, v_seller1_id, 250000, 'near_mint', 'Holo foil bersinar terang, edisi koleksi terbatas.', -6.1751, 106.8650, 'active')
    ON CONFLICT DO NOTHING;
  END IF;

  IF v_card3 IS NOT NULL AND v_seller2_id IS NOT NULL THEN
    INSERT INTO listings (card_id, seller_id, price_idr, condition, description, lat, lng, status)
    VALUES 
      (v_card3, v_seller2_id, 75000, 'excellent', 'Kartu turnamen terawat, siap pakai deck standar.', -6.9175, 107.6191, 'active'),
      (v_card4, v_seller2_id, 35000, 'near_mint', 'Kondisi mulus simpanan binder album.', -6.9039, 107.6186, 'active')
    ON CONFLICT DO NOTHING;
  END IF;

  RAISE NOTICE 'Seed Demo Marketplace berhasil disiapkan!';
END $$;
