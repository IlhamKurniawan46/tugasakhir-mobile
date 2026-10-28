-- ============================================================
-- Marketplace Rekber Ringan (Escrow) Migration
-- HoloDex P2P Marketplace
-- ============================================================

-- 1. Perbarui Constraint Status pada Tabel LISTINGS
-- Mengizinkan status: 'active', 'reserved', 'sold', 'cancelled'
DO $$
BEGIN
  -- Hapus check constraint lama jika ada
  ALTER TABLE listings DROP CONSTRAINT IF EXISTS listings_status_check;
  -- Tambahkan check constraint baru yang mencakup 'reserved'
  ALTER TABLE listings ADD CONSTRAINT listings_status_check 
    CHECK (status IN ('active', 'reserved', 'sold', 'cancelled'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END;
$$;

-- 2. Buat Tabel ORDERS
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES listings(id),
  buyer_id UUID NOT NULL REFERENCES users(id),
  seller_id UUID NOT NULL REFERENCES users(id),
  card_id TEXT NOT NULL REFERENCES cards(id),
  amount_idr NUMERIC(15,2) NOT NULL CHECK (amount_idr > 0),
  status TEXT NOT NULL DEFAULT 'reserved' 
    CHECK (status IN ('reserved', 'completed', 'cancelled', 'expired')),
  reserved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '72 hours'),
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancelled_by UUID REFERENCES users(id),
  cancel_reason TEXT
);

-- Indeks performa untuk kueri order
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON orders(seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_listing_id ON orders(listing_id);
CREATE INDEX IF NOT EXISTS idx_orders_expires_at ON orders(expires_at) WHERE (status = 'reserved');

-- Parsial UNIQUE Index: Maksimal SATU pesanan aktif ('reserved') per listing
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_unique_active_reservation 
  ON orders (listing_id) 
  WHERE (status = 'reserved');

-- Hak akses tabel orders untuk role anon (PostgREST API)
GRANT SELECT, INSERT, UPDATE ON orders TO anon, authenticated;

-- ============================================================
-- 3. FUNGSI-FUNGSI RPC ATOMIK
-- ============================================================

-- A. EXPIRE STALE ORDERS
-- Memeriksa seluruh order 'reserved' yang sudah melewati expires_at (waktu server NOW()).
-- Mengembalikan saldo yang ditahan ke pembeli dan mengembalikan status listing menjadi 'active'.
CREATE OR REPLACE FUNCTION expire_stale_orders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rec RECORD;
  v_count INT := 0;
BEGIN
  -- Loop semua order reserved yang telah kedaluwarsa dengan penguncian baris FOR UPDATE
  FOR v_rec IN 
    SELECT o.id, o.listing_id, o.buyer_id, o.amount_idr
    FROM orders o
    WHERE o.status = 'reserved' AND o.expires_at <= NOW()
    FOR UPDATE SKIP LOCKED
  LOOP
    -- 1. Kembalikan saldo tertahan ke pembeli
    UPDATE users 
    SET balance_idr = balance_idr + v_rec.amount_idr
    WHERE id = v_rec.buyer_id;

    -- 2. Tandai order sebagai 'expired'
    UPDATE orders 
    SET status = 'expired',
        cancelled_at = NOW(),
        cancel_reason = 'Waktu konfirmasi 72 jam terlampaui (otomatis kedaluwarsa)'
    WHERE id = v_rec.id;

    -- 3. Kembalikan listing menjadi 'active'
    UPDATE listings 
    SET status = 'active', updated_at = NOW()
    WHERE id = v_rec.listing_id AND status = 'reserved';

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'expired_count', v_count);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error_code', 'EXPIRE_ORDERS_FAILED', 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION expire_stale_orders() TO anon, authenticated;


-- B. RESERVE LISTING (Pesan Listing & Tahan Saldo)
CREATE OR REPLACE FUNCTION reserve_listing(
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
  v_new_order_id UUID;
  v_new_balance NUMERIC(15,2);
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- 1. Jalankan pembersihan order kedaluwarsa terlebih dahulu
  PERFORM expire_stale_orders();

  -- 2. Kunci baris listing
  SELECT * INTO v_listing 
  FROM listings 
  WHERE id = p_listing_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'LISTING_NOT_FOUND', 'error', 'Listing kartu tidak ditemukan.');
  END IF;

  IF v_listing.status = 'reserved' THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'ALREADY_RESERVED', 'error', 'Kartu ini sedang dipesan oleh kolektor lain.');
  END IF;

  IF v_listing.status != 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'LISTING_NOT_ACTIVE', 'error', 'Listing sudah tidak tersedia atau sudah terjual.');
  END IF;

  -- 3. Tolak jika pembeli adalah penjual itu sendiri
  IF v_listing.seller_id = p_buyer_id THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'CANNOT_BUY_OWN_LISTING', 'error', 'Anda tidak dapat memesan kartu milik sendiri.');
  END IF;

  -- 4. Kunci baris pembeli dan periksa saldo
  SELECT * INTO v_buyer 
  FROM users 
  WHERE id = p_buyer_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'BUYER_NOT_FOUND', 'error', 'Akun pembeli tidak ditemukan.');
  END IF;

  IF v_buyer.balance_idr < v_listing.price_idr THEN
    RETURN jsonb_build_object(
      'ok', false, 
      'error_code', 'INSUFFICIENT_BALANCE', 
      'error', 'Saldo tidak mencukupi untuk memesan kartu ini. Silakan top up terlebih dahulu.',
      'current_balance', v_buyer.balance_idr,
      'required_amount', v_listing.price_idr
    );
  END IF;

  -- 5. Potong saldo pembeli (tahan saldo di sistem rekber)
  UPDATE users 
  SET balance_idr = balance_idr - v_listing.price_idr
  WHERE id = p_buyer_id
  RETURNING balance_idr INTO v_new_balance;

  -- 6. Ubah status listing menjadi 'reserved'
  UPDATE listings 
  SET status = 'reserved', updated_at = NOW() 
  WHERE id = p_listing_id;

  -- 7. Buat order rekber baru dengan masa aktif 72 jam
  v_expires_at := NOW() + INTERVAL '72 hours';

  INSERT INTO orders (
    listing_id, buyer_id, seller_id, card_id, amount_idr,
    status, reserved_at, expires_at
  ) VALUES (
    v_listing.id, p_buyer_id, v_listing.seller_id, v_listing.card_id, v_listing.price_idr,
    'reserved', NOW(), v_expires_at
  )
  RETURNING id INTO v_new_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', v_new_order_id,
    'listing_id', v_listing.id,
    'card_id', v_listing.card_id,
    'amount_idr', v_listing.price_idr,
    'expires_at', v_expires_at,
    'remaining_balance', v_new_balance
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error_code', 'RESERVE_FAILED', 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION reserve_listing(UUID, UUID) TO anon, authenticated;


-- C. CONFIRM RECEIPT (Konfirmasi Serah Terima oleh Pembeli)
-- IDEMPOTEN: jika sudah completed, kembalikan ok: true tanpa menggandakan saldo.
CREATE OR REPLACE FUNCTION confirm_receipt(
  p_order_id UUID,
  p_buyer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_listing listings%ROWTYPE;
  v_first_user UUID;
  v_second_user UUID;
  v_seller_balance NUMERIC(15,2);
  v_transaction_id UUID;
BEGIN
  -- 1. Jalankan expire check
  PERFORM expire_stale_orders();

  -- 2. Kunci baris order
  SELECT * INTO v_order 
  FROM orders 
  WHERE id = p_order_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'ORDER_NOT_FOUND', 'error', 'Pesanan tidak ditemukan.');
  END IF;

  -- Idempotensi: jika pesanan sudah completed sebelumnya, kembalikan respon sukses tanpa mutasi ganda
  IF v_order.status = 'completed' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'order_id', v_order.id,
      'listing_id', v_order.listing_id,
      'card_id', v_order.card_id,
      'amount_idr', v_order.amount_idr,
      'already_completed', true
    );
  END IF;

  IF v_order.buyer_id != p_buyer_id THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'UNAUTHORIZED', 'error', 'Hanya pembeli yang sah yang berhak mengonfirmasi serah terima.');
  END IF;

  IF v_order.status != 'reserved' THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'INVALID_ORDER_STATUS', 'error', 'Pesanan tidak dalam status dipesan (mungkin sudah dibatalkan atau kedaluwarsa).');
  END IF;

  IF v_order.expires_at <= NOW() THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'ORDER_EXPIRED', 'error', 'Pesanan telah kedaluwarsa.');
  END IF;

  -- 3. Kunci listing terkait
  SELECT * INTO v_listing 
  FROM listings 
  WHERE id = v_order.listing_id 
  FOR UPDATE;

  -- 4. Kunci baris user secara konsisten (ID terkecil dulu untuk anti-deadlock)
  IF v_order.buyer_id < v_order.seller_id THEN
    v_first_user := v_order.buyer_id;
    v_second_user := v_order.seller_id;
  ELSE
    v_first_user := v_order.seller_id;
    v_second_user := v_order.buyer_id;
  END IF;

  PERFORM 1 FROM users WHERE id = v_first_user FOR UPDATE;
  PERFORM 1 FROM users WHERE id = v_second_user FOR UPDATE;

  -- 5. Tambah saldo penjual sebesar amount_idr
  UPDATE users 
  SET balance_idr = balance_idr + v_order.amount_idr 
  WHERE id = v_order.seller_id
  RETURNING balance_idr INTO v_seller_balance;

  -- 6. Update order menjadi 'completed'
  UPDATE orders 
  SET status = 'completed',
      completed_at = NOW() 
  WHERE id = v_order.id;

  -- 7. Update status listing menjadi 'sold'
  UPDATE listings 
  SET status = 'sold', updated_at = NOW() 
  WHERE id = v_order.listing_id;

  -- 8. Pindahkan kartu ke koleksi pembeli (acquired_via = 'purchase')
  INSERT INTO collections (user_id, card_id, acquired_via, acquired_at) 
  VALUES (v_order.buyer_id, v_order.card_id, 'purchase', NOW())
  ON CONFLICT (user_id, card_id) DO UPDATE 
    SET acquired_via = 'purchase', acquired_at = NOW();

  -- 9. Hapus dari koleksi penjual bila ada (penjual menjual kartu dari koleksinya)
  DELETE FROM collections 
  WHERE user_id = v_order.seller_id AND card_id = v_order.card_id;

  -- 10. Catat riwayat resmi ke tabel transactions
  INSERT INTO transactions (
    listing_id, buyer_id, seller_id, card_id, price_idr
  ) VALUES (
    v_order.listing_id, v_order.buyer_id, v_order.seller_id, v_order.card_id, v_order.amount_idr
  )
  RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', v_order.id,
    'listing_id', v_order.listing_id,
    'card_id', v_order.card_id,
    'amount_idr', v_order.amount_idr,
    'transaction_id', v_transaction_id,
    'already_completed', false
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error_code', 'CONFIRM_FAILED', 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION confirm_receipt(UUID, UUID) TO anon, authenticated;


-- D. CANCEL ORDER (Batalkan Pesanan oleh Pembeli atau Penjual)
CREATE OR REPLACE FUNCTION cancel_order(
  p_order_id UUID,
  p_user_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_listing listings%ROWTYPE;
BEGIN
  -- 1. Jalankan expire check
  PERFORM expire_stale_orders();

  -- 2. Kunci baris order
  SELECT * INTO v_order 
  FROM orders 
  WHERE id = p_order_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'ORDER_NOT_FOUND', 'error', 'Pesanan tidak ditemukan.');
  END IF;

  -- Hanya pembeli atau penjual terkait yang boleh membatalkan
  IF p_user_id != v_order.buyer_id AND p_user_id != v_order.seller_id THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'UNAUTHORIZED', 'error', 'Anda tidak memiliki hak untuk membatalkan pesanan ini.');
  END IF;

  IF v_order.status != 'reserved' THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'INVALID_ORDER_STATUS', 'error', 'Pesanan tidak dapat dibatalkan karena sudah selesai atau telah dibatalkan.');
  END IF;

  -- 3. Kunci baris listing
  SELECT * INTO v_listing 
  FROM listings 
  WHERE id = v_order.listing_id 
  FOR UPDATE;

  -- 4. Kunci pembeli untuk pengembalian dana
  PERFORM 1 FROM users WHERE id = v_order.buyer_id FOR UPDATE;

  -- 5. Kembalikan saldo penuh ke pembeli
  UPDATE users 
  SET balance_idr = balance_idr + v_order.amount_idr 
  WHERE id = v_order.buyer_id;

  -- 6. Update order menjadi 'cancelled'
  UPDATE orders 
  SET status = 'cancelled',
      cancelled_at = NOW(),
      cancelled_by = p_user_id,
      cancel_reason = COALESCE(p_reason, 'Dibatalkan atas kesepakatan pengguna')
  WHERE id = v_order.id;

  -- 7. Kembalikan listing menjadi 'active'
  UPDATE listings 
  SET status = 'active', updated_at = NOW() 
  WHERE id = v_order.listing_id;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', v_order.id,
    'listing_id', v_order.listing_id,
    'refund_amount', v_order.amount_idr,
    'cancelled_by', p_user_id
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error_code', 'CANCEL_FAILED', 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_order(UUID, UUID, TEXT) TO anon, authenticated;


-- E. GET MY ORDERS (Daftar Pesanan Saya: Pembelian & Penjualan)
CREATE OR REPLACE FUNCTION get_my_orders(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Selalu bersihkan pesanan basi terlebih dahulu
  PERFORM expire_stale_orders();

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', o.id,
      'listing_id', o.listing_id,
      'buyer_id', o.buyer_id,
      'seller_id', o.seller_id,
      'card_id', o.card_id,
      'amount_idr', o.amount_idr,
      'status', o.status,
      'reserved_at', o.reserved_at,
      'expires_at', o.expires_at,
      'completed_at', o.completed_at,
      'cancelled_at', o.cancelled_at,
      'cancelled_by', o.cancelled_by,
      'cancel_reason', o.cancel_reason,
      'is_buyer', (o.buyer_id = p_user_id),
      'other_party_username', CASE 
        WHEN o.buyer_id = p_user_id THEN s.username 
        ELSE b.username 
      END,
      'other_party_photo_url', CASE 
        WHEN o.buyer_id = p_user_id THEN s.photo_url 
        ELSE b.photo_url 
      END,
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
      ),
      'listing', jsonb_build_object(
        'id', l.id,
        'condition', l.condition,
        'description', l.description,
        'lat', l.lat,
        'lng', l.lng,
        'status', l.status
      )
    ) ORDER BY o.reserved_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM orders o
  JOIN cards k ON k.id = o.card_id
  JOIN listings l ON l.id = o.listing_id
  JOIN users b ON b.id = o.buyer_id
  JOIN users s ON s.id = o.seller_id
  WHERE o.buyer_id = p_user_id OR o.seller_id = p_user_id;

  RETURN jsonb_build_object('ok', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error_code', 'GET_ORDERS_FAILED', 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_orders(UUID) TO anon, authenticated;


-- F. UPDATE/REPLACE CANCEL_LISTING (Cegah Penjual Membatalkan Listing saat 'reserved')
CREATE OR REPLACE FUNCTION cancel_listing(
  p_listing_id UUID,
  p_seller_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_listing listings%ROWTYPE;
BEGIN
  SELECT * INTO v_listing 
  FROM listings 
  WHERE id = p_listing_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing tidak ditemukan.');
  END IF;

  IF v_listing.seller_id != p_seller_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anda bukan pemilik listing ini.');
  END IF;

  IF v_listing.status = 'reserved' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing sedang dalam status Dipesan. Batalkan pesanan terkait terlebih dahulu sebelum membatalkan listing.');
  END IF;

  IF v_listing.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Listing tidak dapat dibatalkan karena sudah tidak aktif.');
  END IF;

  UPDATE listings 
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_listing_id;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_listing(UUID, UUID) TO anon, authenticated;


-- G. BLOKIR BUY_LISTING LAMA
-- Menghentikan bypass alur escrow jika ada klien yang mencoba memanggil RPC lama
CREATE OR REPLACE FUNCTION buy_listing(
  p_listing_id UUID,
  p_buyer_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Fungsi buy_listing lama telah dinonaktifkan demi keamanan serah terima COD. Gunakan alur rekber reserve_listing.';
END;
$$;

GRANT EXECUTE ON FUNCTION buy_listing(UUID, UUID) TO anon, authenticated;

