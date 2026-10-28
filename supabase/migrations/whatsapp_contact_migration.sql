-- ==============================================================================
-- HOLODEX SUPABASE MIGRATION: KONTAK COD VIA WHATSAPP
-- ==============================================================================
-- Fitur: Koordinasi Serah Terima COD via WhatsApp untuk Pesanan Aktif (Reserved)
-- Keamanan: Kolom whatsapp_number pada tabel users TIDAK dibocorkan ke publik/anon.
-- Kontak hanya dapat diakses melalui RPC get_order_contact oleh pihak transaksi aktif.
-- ==============================================================================

-- 1. Tambahkan kolom whatsapp_number pada tabel users jika belum ada
ALTER TABLE users ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;

-- 2. Fungsi pembantu normalisasi nomor telepon format Indonesia
CREATE OR REPLACE FUNCTION normalize_phone_id(p_input TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_clean TEXT;
BEGIN
  IF p_input IS NULL THEN
    RETURN NULL;
  END IF;

  -- Buang semua karakter non-digit
  v_clean := regexp_replace(p_input, '[^0-9]', '', 'g');

  IF v_clean = '' THEN
    RETURN NULL;
  END IF;

  -- Ubah awalan 0 menjadi 62 (misal: 0812 -> 62812)
  IF v_clean LIKE '0%' THEN
    v_clean := '62' || substr(v_clean, 2);
  -- Jika diawali 8 langsung (misal: 812345678), tambahkan 62
  ELSIF v_clean LIKE '8%' THEN
    v_clean := '62' || v_clean;
  END IF;

  -- Validasi panjang: Indonesia nomor seluler normalnya 10-15 digit dengan kode negara 62
  -- (misal: 628123456789 = 13 digit)
  IF length(v_clean) < 10 OR length(v_clean) > 15 THEN
    RETURN NULL;
  END IF;

  -- Wajib diawali 628
  IF NOT v_clean LIKE '62%' THEN
    RETURN NULL;
  END IF;

  RETURN v_clean;
END;
$$;

-- 3. RPC: Simpan atau Hapus Nomor WhatsApp Pengguna Milik Sendiri
CREATE OR REPLACE FUNCTION set_my_whatsapp(
  p_user_id UUID,
  p_number TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_normalized TEXT;
BEGIN
  -- Validasi keberadaan user
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'USER_NOT_FOUND',
      'error', 'Pengguna tidak ditemukan.'
    );
  END IF;

  -- Jika input kosong / spasi: hapus nomor (set NULL)
  IF p_number IS NULL OR trim(p_number) = '' THEN
    UPDATE users 
    SET whatsapp_number = NULL 
    WHERE id = p_user_id;

    RETURN jsonb_build_object(
      'ok', true,
      'whatsapp_number', NULL,
      'message', 'Nomor WhatsApp berhasil dihapus.'
    );
  END IF;

  -- Lakukan normalisasi
  v_normalized := normalize_phone_id(p_number);

  IF v_normalized IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'INVALID_PHONE_NUMBER',
      'error', 'Format nomor WhatsApp tidak valid. Gunakan nomor Indonesia (contoh: 081234567890).'
    );
  END IF;

  -- Simpan nomor ternormalisasi
  UPDATE users 
  SET whatsapp_number = v_normalized 
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'whatsapp_number', v_normalized,
    'message', 'Nomor WhatsApp berhasil disimpan.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'error_code', 'SET_WHATSAPP_FAILED',
    'error', SQLERRM
  );
END;
$$;

GRANT EXECUTE ON FUNCTION set_my_whatsapp(UUID, TEXT) TO anon, authenticated;


-- 4. RPC: Ambil Kontak Pihak Lawan untuk Pesanan Aktif (Reserved)
CREATE OR REPLACE FUNCTION get_order_contact(
  p_order_id UUID,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_other_party_id UUID;
  v_other_party_username TEXT;
  v_other_party_whatsapp TEXT;
  v_other_role TEXT;
BEGIN
  -- Jalankan pembersihan order kedaluwarsa terlebih dahulu
  PERFORM expire_stale_orders();

  -- Ambil data order
  SELECT * INTO v_order 
  FROM orders 
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'ORDER_NOT_FOUND',
      'error', 'Pesanan tidak ditemukan.'
    );
  END IF;

  -- Validasi: Pemanggil HARUS pembeli atau penjual order ini
  IF p_user_id != v_order.buyer_id AND p_user_id != v_order.seller_id THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'not_allowed',
      'error', 'Anda tidak memiliki akses ke kontak pesanan ini.'
    );
  END IF;

  -- Validasi: Status order HARUS 'reserved' (aktif)
  -- Jika pesanan sudah completed, cancelled, atau expired, kontak ditutup
  IF v_order.status != 'reserved' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'not_allowed',
      'error', 'Kontak hanya dapat diakses saat status pesanan masih aktif (Dipesan).'
    );
  END IF;

  -- Tentukan pihak lawan transaksi
  IF p_user_id = v_order.buyer_id THEN
    v_other_party_id := v_order.seller_id;
    v_other_role := 'seller';
  ELSE
    v_other_party_id := v_order.buyer_id;
    v_other_role := 'buyer';
  END IF;

  -- Ambil data profil pihak lawan
  SELECT username, whatsapp_number 
  INTO v_other_party_username, v_other_party_whatsapp
  FROM users 
  WHERE id = v_other_party_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'USER_NOT_FOUND',
      'error', 'Data profil pihak lawan tidak ditemukan.'
    );
  END IF;

  -- Periksa ketersediaan nomor WhatsApp pihak lawan
  IF v_other_party_whatsapp IS NULL OR trim(v_other_party_whatsapp) = '' THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error_code', 'no_contact',
      'display_name', v_other_party_username,
      'error', 'Pihak lawan belum mengisi nomor WhatsApp.'
    );
  END IF;

  -- Berhasil mengembalikan kontak
  RETURN jsonb_build_object(
    'ok', true,
    'order_id', v_order.id,
    'role', v_other_role,
    'display_name', v_other_party_username,
    'whatsapp_number', v_other_party_whatsapp
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'ok', false,
    'error_code', 'GET_CONTACT_FAILED',
    'error', SQLERRM
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_order_contact(UUID, UUID) TO anon, authenticated;


-- 5. Perbarui RPC reserve_listing: Tegakkan kewajiban WhatsApp untuk pembeli
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

  -- 4. Kunci baris pembeli dan periksa saldo & nomor WhatsApp
  SELECT * INTO v_buyer 
  FROM users 
  WHERE id = p_buyer_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error_code', 'BUYER_NOT_FOUND', 'error', 'Akun pembeli tidak ditemukan.');
  END IF;

  -- [PENEGAKAN BARU] Pembeli wajib punya nomor WhatsApp aktif sebelum memesan
  IF v_buyer.whatsapp_number IS NULL OR trim(v_buyer.whatsapp_number) = '' THEN
    RETURN jsonb_build_object(
      'ok', false, 
      'error_code', 'whatsapp_required', 
      'error', 'Nomor WhatsApp wajib diisi sebelum memesan kartu agar penjual dapat berkoordinasi COD.'
    );
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

  -- 7. Tentukan waktu kedaluwarsa (72 jam dari sekarang)
  v_expires_at := NOW() + INTERVAL '72 hours';

  -- 8. Buat baris order baru berstatus 'reserved'
  INSERT INTO orders (
    listing_id,
    buyer_id,
    seller_id,
    card_id,
    amount_idr,
    status,
    reserved_at,
    expires_at
  ) VALUES (
    p_listing_id,
    p_buyer_id,
    v_listing.seller_id,
    v_listing.card_id,
    v_listing.price_idr,
    'reserved',
    NOW(),
    v_expires_at
  )
  RETURNING id INTO v_new_order_id;

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', v_new_order_id,
    'status', 'reserved',
    'amount_idr', v_listing.price_idr,
    'new_balance_idr', v_new_balance,
    'expires_at', v_expires_at
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'error_code', 'RESERVE_FAILED', 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION reserve_listing(UUID, UUID) TO anon, authenticated;


-- 6. Perbarui RPC create_listing: Tegakkan kewajiban WhatsApp untuk penjual
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
  v_seller users%ROWTYPE;
BEGIN
  IF p_price_idr <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PRICE', 'error', 'Harga harus lebih besar dari 0');
  END IF;

  IF p_condition NOT IN ('mint','near_mint','excellent','good','poor') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CONDITION', 'error', 'Kondisi kartu tidak valid');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cards WHERE id = p_card_id) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'CARD_NOT_FOUND', 'error', 'Kartu tidak terdaftar di katalog');
  END IF;

  -- [PENEGAKAN BARU] Penjual wajib punya nomor WhatsApp aktif sebelum memasang listing
  SELECT * INTO v_seller FROM users WHERE id = p_seller_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SELLER_NOT_FOUND', 'error', 'Akun penjual tidak ditemukan');
  END IF;

  IF v_seller.whatsapp_number IS NULL OR trim(v_seller.whatsapp_number) = '' THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error_code', 'whatsapp_required', 
      'error', 'Nomor WhatsApp wajib diisi sebelum memasang listing agar pembeli dapat berkoordinasi COD.'
    );
  END IF;

  INSERT INTO listings (
    card_id,
    seller_id,
    price_idr,
    condition,
    description,
    lat,
    lng,
    status
  ) VALUES (
    p_card_id,
    p_seller_id,
    p_price_idr,
    p_condition,
    p_description,
    p_lat,
    p_lng,
    'active'
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_new_id,
    'message', 'Listing berhasil dipasang di pasar'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION create_listing(TEXT, UUID, NUMERIC, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;


-- 7. Perbarui RPC get_user_profile: Sertakan nomor WhatsApp pemilik akun
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
      'whatsapp_number', v_user.whatsapp_number,
      'created_at', v_user.created_at
    )
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_profile(UUID) TO anon, authenticated;

