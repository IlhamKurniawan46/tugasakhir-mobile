-- ==============================================================================
-- HOLODEX SUPABASE TEST SUITE: KONTAK COD VIA WHATSAPP (contact_tests.sql)
-- ==============================================================================
-- Jalankan skrip ini secara manual di SQL Editor Supabase.
-- Seluruh pengujian dibungkus dalam blok transaksi BEGIN ... ROLLBACK sehingga
-- TIDAK MENINGGALKAN data sampah / merusak data produksi.
-- ==============================================================================

BEGIN;

DO $$
DECLARE
  v_test_card_id TEXT;
  v_seller_id UUID := gen_random_uuid();
  v_buyer_id UUID := gen_random_uuid();
  v_stranger_id UUID := gen_random_uuid();
  v_listing_id UUID;
  v_order_id UUID;
  v_res JSONB;
BEGIN
  RAISE NOTICE '=== MEMULAI TEST SUITE KONTAK COD WHATSAPP HOLODEX ===';

  -- ----------------------------------------------------------------------------
  -- PERSIAPAN DATA UJI
  -- ----------------------------------------------------------------------------
  SELECT id INTO v_test_card_id FROM cards WHERE has_price = true LIMIT 1;
  IF v_test_card_id IS NULL THEN
    v_test_card_id := 'test-card-whatsapp-01';
    INSERT INTO cards (id, name, set_id, set_name, has_price, price_idr, price_ref_usd)
    VALUES (v_test_card_id, 'Test Card WhatsApp', 'swsh3', 'Darkness Ablaze', true, 100000, 10.0);
  END IF;

  -- Akun Penjual Uji
  INSERT INTO users (id, username, email, password_hash, salt, balance_idr, whatsapp_number)
  VALUES (v_seller_id, 'test_seller_wa', 'seller_wa@holodex.test', 'hash1', 'salt1', 0, NULL);

  -- Akun Pembeli Uji (Saldo cukup)
  INSERT INTO users (id, username, email, password_hash, salt, balance_idr, whatsapp_number)
  VALUES (v_buyer_id, 'test_buyer_wa', 'buyer_wa@holodex.test', 'hash2', 'salt2', 500000, NULL);

  -- Akun Pihak Ketiga (Orang Luar)
  INSERT INTO users (id, username, email, password_hash, salt, balance_idr, whatsapp_number)
  VALUES (v_stranger_id, 'test_stranger_wa', 'stranger_wa@holodex.test', 'hash3', 'salt3', 100000, '628999999999');

  -- ----------------------------------------------------------------------------
  -- TEST 1: NORMALISASI NOMOR WHATSAPP (Fungsi normalize_phone_id)
  -- ----------------------------------------------------------------------------
  -- Format '081234567890' -> '6281234567890'
  ASSERT normalize_phone_id('081234567890') = '6281234567890', 'Gagal normalisasi format 08...';
  -- Format '+62 812-3456-7890' -> '6281234567890'
  ASSERT normalize_phone_id('+62 812-3456-7890') = '6281234567890', 'Gagal buang spasi dan strip';
  -- Format '628123456789' -> '628123456789'
  ASSERT normalize_phone_id('628123456789') = '628123456789', 'Gagal pertahankan format 62...';
  -- Format '8123456789' -> '628123456789'
  ASSERT normalize_phone_id('8123456789') = '628123456789', 'Gagal normalisasi awalan 8...';
  -- Terlalu pendek (< 10 digit) -> NULL
  ASSERT normalize_phone_id('08123') IS NULL, 'Nomor terlalu pendek harus NULL';
  -- Mengandung huruf tanpa digit yang cukup -> NULL
  ASSERT normalize_phone_id('abcd0812') IS NULL, 'Nomor tidak valid harus NULL';

  RAISE NOTICE '[TEST 1] Normalisasi nomor telepon format Indonesia: OK';

  -- ----------------------------------------------------------------------------
  -- TEST 2: RPC set_my_whatsapp (Simpan & Hapus)
  -- ----------------------------------------------------------------------------
  -- Simpan nomor penjual
  v_res := set_my_whatsapp(v_seller_id, '081298765432');
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'set_my_whatsapp penjual harus berhasil';
  ASSERT (v_res->>'whatsapp_number') = '6281298765432', 'Nomor tersimpan harus ternormalisasi';

  -- Cek nilai di database
  PERFORM 1 FROM users WHERE id = v_seller_id AND whatsapp_number = '6281298765432';
  ASSERT FOUND, 'Nilai whatsapp_number di tabel users harus cocok';

  -- Simpan nomor pembeli
  v_res := set_my_whatsapp(v_buyer_id, '+62 856-1122-3344');
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'set_my_whatsapp pembeli harus berhasil';
  ASSERT (v_res->>'whatsapp_number') = '6285611223344', 'Nomor pembeli harus ternormalisasi';

  -- Hapus nomor dengan string kosong
  v_res := set_my_whatsapp(v_buyer_id, '   ');
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'set_my_whatsapp string kosong harus sukses';
  ASSERT v_res->>'whatsapp_number' IS NULL, 'whatsapp_number harus NULL setelah dihapus';

  RAISE NOTICE '[TEST 2] set_my_whatsapp simpan ternormalisasi dan hapus: OK';

  -- ----------------------------------------------------------------------------
  -- TEST 3: PENEGAKAN WHATSAPP PADA create_listing & reserve_listing
  -- ----------------------------------------------------------------------------
  -- Buat akun penjual tanpa WA
  UPDATE users SET whatsapp_number = NULL WHERE id = v_seller_id;
  v_res := create_listing(v_test_card_id, v_seller_id, 100000, 'near_mint', 'Test listing tanpa WA', -6.2, 106.8);
  ASSERT (v_res->>'success')::BOOLEAN = false, 'Penjual tanpa nomor WA harus ditolak membuat listing';
  ASSERT v_res->>'error_code' = 'whatsapp_required', 'Error code harus whatsapp_required';

  -- Beri nomor WA untuk penjual, sekarang harus bisa membuat listing
  PERFORM set_my_whatsapp(v_seller_id, '081298765432');
  v_res := create_listing(v_test_card_id, v_seller_id, 100000, 'near_mint', 'Test listing dengan WA', -6.2, 106.8);
  ASSERT (v_res->>'success')::BOOLEAN = true, 'Penjual ber-WA harus sukses membuat listing';
  v_listing_id := (v_res->>'id')::UUID;

  -- Pembeli belum punya nomor WA (dihapus di Test 2) -> coba memesan
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  ASSERT (v_res->>'ok')::BOOLEAN = false, 'Pembeli tanpa nomor WA harus ditolak memesan listing';
  ASSERT v_res->>'error_code' = 'whatsapp_required', 'Error code harus whatsapp_required';

  -- Beri nomor WA untuk pembeli -> coba memesan lagi
  PERFORM set_my_whatsapp(v_buyer_id, '085611223344');
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'Pembeli ber-WA harus sukses memesan listing';
  v_order_id := (v_res->>'order_id')::UUID;

  RAISE NOTICE '[TEST 3] Penegakan whatsapp_required pada create_listing & reserve_listing: OK';

  -- ----------------------------------------------------------------------------
  -- TEST 4: get_order_contact HANYA UNTUK PESERTA ORDER (STATUS RESERVED)
  -- ----------------------------------------------------------------------------
  -- Pembeli meminta kontak penjual
  v_res := get_order_contact(v_order_id, v_buyer_id);
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'Pembeli harus bisa meminta kontak pesanan aktif';
  ASSERT v_res->>'role' = 'seller', 'Role kontak yang dikembalikan harus seller';
  ASSERT v_res->>'whatsapp_number' = '6281298765432', 'Nomor WhatsApp penjual harus sesuai';
  ASSERT v_res->>'display_name' = 'test_seller_wa', 'Username penjual harus sesuai';

  -- Penjual meminta kontak pembeli
  v_res := get_order_contact(v_order_id, v_seller_id);
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'Penjual harus bisa meminta kontak pesanan aktif';
  ASSERT v_res->>'role' = 'buyer', 'Role kontak yang dikembalikan harus buyer';
  ASSERT v_res->>'whatsapp_number' = '6285611223344', 'Nomor WhatsApp pembeli harus sesuai';
  ASSERT v_res->>'display_name' = 'test_buyer_wa', 'Username pembeli harus sesuai';

  -- Orang luar (stranger) mencoba meminta kontak
  v_res := get_order_contact(v_order_id, v_stranger_id);
  ASSERT (v_res->>'ok')::BOOLEAN = false, 'Orang luar harus ditolak meminta kontak';
  ASSERT v_res->>'error_code' = 'not_allowed', 'Error code harus not_allowed';

  RAISE NOTICE '[TEST 4] get_order_contact berhasil untuk peserta dan menolak orang luar: OK';

  -- ----------------------------------------------------------------------------
  -- TEST 5: get_order_contact DITOLAK SAAT STATUS BUKAN RESERVED
  -- ----------------------------------------------------------------------------
  -- Batalkan order
  v_res := cancel_order(v_order_id, v_buyer_id, 'Tes kontak ditolak saat batal');
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'Pembatalan order harus berhasil';

  -- Coba minta kontak setelah order cancelled
  v_res := get_order_contact(v_order_id, v_buyer_id);
  ASSERT (v_res->>'ok')::BOOLEAN = false, 'Kontak tidak boleh diambil setelah order dibatalkan';
  ASSERT v_res->>'error_code' = 'not_allowed', 'Error code harus not_allowed';

  v_res := get_order_contact(v_order_id, v_seller_id);
  ASSERT (v_res->>'ok')::BOOLEAN = false, 'Kontak tidak boleh diambil penjual setelah order dibatalkan';
  ASSERT v_res->>'error_code' = 'not_allowed', 'Error code harus not_allowed';

  RAISE NOTICE '[TEST 5] get_order_contact ditolak saat status order bukan reserved: OK';

  -- ----------------------------------------------------------------------------
  -- TEST 6: get_order_contact MENGEMBALIKAN no_contact BILA LAWAN BELUM ADA NOMOR
  -- ----------------------------------------------------------------------------
  -- Pesan ulang listing (listing aktif kembali setelah order cancel)
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  ASSERT (v_res->>'ok')::BOOLEAN = true, 'Reservasi kedua harus sukses';
  v_order_id := (v_res->>'order_id')::UUID;

  -- Hapus nomor WA penjual
  UPDATE users SET whatsapp_number = NULL WHERE id = v_seller_id;

  -- Pembeli meminta kontak penjual yang kosong
  v_res := get_order_contact(v_order_id, v_buyer_id);
  ASSERT (v_res->>'ok')::BOOLEAN = false, 'Permintaan kontak harus mengembalikan false bila kosong';
  ASSERT v_res->>'error_code' = 'no_contact', 'Error code harus no_contact bila lawan belum punya nomor';

  RAISE NOTICE '[TEST 6] get_order_contact mengembalikan error_code no_contact bila kosong: OK';

  -- ----------------------------------------------------------------------------
  -- TEST 7: PRIVASI DATA PROFIL (get_user_profile)
  -- ----------------------------------------------------------------------------
  -- Kembalikan nomor pembeli
  PERFORM set_my_whatsapp(v_buyer_id, '085611223344');
  v_res := get_user_profile(v_buyer_id);
  ASSERT (v_res->>'success')::BOOLEAN = true, 'get_user_profile harus sukses';
  ASSERT (v_res->'user'->>'whatsapp_number') = '6285611223344', 'Profil diri sendiri menampilkan nomor WhatsApp';

  RAISE NOTICE '[TEST 7] get_user_profile menyertakan whatsapp_number pemilik akun: OK';

  RAISE NOTICE '=== SEMUA 7 PENGUJIAN KONTAK COD WHATSAPP LULUS 100% ===';
END $$;

ROLLBACK;

