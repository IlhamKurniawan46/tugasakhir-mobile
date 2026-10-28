-- ============================================================
-- Escrow RPC Test Script (HoloDex)
-- Jalankan file ini secara manual di Supabase SQL Editor.
-- Seluruh skrip dibungkus dalam blok transaksi BEGIN ... ROLLBACK
-- sehingga TIDAK ADA perubahan data yang permanen di database Anda.
-- ============================================================

BEGIN;

DO $$
DECLARE
  v_test_card_id TEXT := 'swsh3-19'; -- Charizard V / sembarang kartu ada
  v_buyer_id UUID;
  v_seller_id UUID;
  v_stranger_id UUID;
  v_listing_id UUID;
  v_order_id UUID;
  v_res JSONB;
  
  v_init_total_balance NUMERIC;
  v_curr_total_balance NUMERIC;
  v_curr_reserved_amount NUMERIC;
  v_buyer_bal NUMERIC;
  v_seller_bal NUMERIC;
  v_listing_status TEXT;
  v_order_status TEXT;
  v_in_buyer_collection BOOLEAN;
  v_in_seller_collection BOOLEAN;
BEGIN
  RAISE NOTICE '=== MEMULAI TEST REKBER (ESCROW) HOLODEX ===';

  -- 1. Siapkan Akun Uji Khusus
  INSERT INTO users (username, email, password_hash, salt, balance_idr)
  VALUES ('test_escrow_buyer', 'buyer@test.escrow', 'hash', 'salt', 500000)
  ON CONFLICT (username) DO UPDATE SET balance_idr = 500000
  RETURNING id INTO v_buyer_id;

  INSERT INTO users (username, email, password_hash, salt, balance_idr)
  VALUES ('test_escrow_seller', 'seller@test.escrow', 'hash', 'salt', 100000)
  ON CONFLICT (username) DO UPDATE SET balance_idr = 100000
  RETURNING id INTO v_seller_id;

  INSERT INTO users (username, email, password_hash, salt, balance_idr)
  VALUES ('test_escrow_stranger', 'stranger@test.escrow', 'hash', 'salt', 100000)
  ON CONFLICT (username) DO UPDATE SET balance_idr = 100000
  RETURNING id INTO v_stranger_id;

  -- Taruh kartu di koleksi awal penjual untuk tes pemindahan
  INSERT INTO collections (user_id, card_id, acquired_via, acquired_at)
  VALUES (v_seller_id, v_test_card_id, 'purchase', NOW())
  ON CONFLICT (user_id, card_id) DO NOTHING;

  -- Pastikan pembeli belum punya kartu tersebut
  DELETE FROM collections WHERE user_id = v_buyer_id AND card_id = v_test_card_id;

  -- Buat Listing Aktif seharga 200.000 IDR
  INSERT INTO listings (card_id, seller_id, price_idr, condition, description, status)
  VALUES (v_test_card_id, v_seller_id, 200000, 'mint', 'Uji Escrow Listing', 'active')
  RETURNING id INTO v_listing_id;

  -- Rekam total saldo awal untuk pengecekan invarian
  SELECT COALESCE(SUM(balance_idr), 0) INTO v_init_total_balance FROM users;

  -- -------------------------------------------------------------
  -- TEST 1: Membeli listing sendiri ditolak
  -- -------------------------------------------------------------
  v_res := reserve_listing(v_listing_id, v_seller_id);
  IF (v_res->>'ok')::BOOLEAN = false AND (v_res->>'error_code') = 'CANNOT_BUY_OWN_LISTING' THEN
    RAISE NOTICE '✅ TEST 1 LULUS: Membeli listing sendiri berhasil ditolak.';
  ELSE
    RAISE EXCEPTION '❌ TEST 1 GAGAL: %', v_res;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 2: Saldo tidak cukup ditolak
  -- -------------------------------------------------------------
  -- Kurangi saldo buyer sementara
  UPDATE users SET balance_idr = 50000 WHERE id = v_buyer_id;
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  IF (v_res->>'ok')::BOOLEAN = false AND (v_res->>'error_code') = 'INSUFFICIENT_BALANCE' THEN
    RAISE NOTICE '✅ TEST 2 LULUS: Saldo tidak cukup berhasil ditolak.';
  ELSE
    RAISE EXCEPTION '❌ TEST 2 GAGAL: %', v_res;
  END IF;

  -- Kembalikan saldo buyer
  UPDATE users SET balance_idr = 500000 WHERE id = v_buyer_id;

  -- -------------------------------------------------------------
  -- TEST 3: Reserve berhasil mengurangi saldo pembeli & status listing jadi reserved
  -- -------------------------------------------------------------
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  IF (v_res->>'ok')::BOOLEAN = true THEN
    v_order_id := (v_res->>'order_id')::UUID;
    SELECT balance_idr INTO v_buyer_bal FROM users WHERE id = v_buyer_id;
    SELECT status INTO v_listing_status FROM listings WHERE id = v_listing_id;

    IF v_buyer_bal = 300000 AND v_listing_status = 'reserved' THEN
      RAISE NOTICE '✅ TEST 3 LULUS: Reserve sukses! Saldo pembeli 500rb -> 300rb, listing = reserved.';
    ELSE
      RAISE EXCEPTION '❌ TEST 3 GAGAL: Saldo buyer %, status listing %', v_buyer_bal, v_listing_status;
    END IF;
  ELSE
    RAISE EXCEPTION '❌ TEST 3 GAGAL: %', v_res;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 4: Reservasi kedua pada listing yang sama ditolak
  -- -------------------------------------------------------------
  v_res := reserve_listing(v_listing_id, v_stranger_id);
  IF (v_res->>'ok')::BOOLEAN = false AND (v_res->>'error_code') = 'ALREADY_RESERVED' THEN
    RAISE NOTICE '✅ TEST 4 LULUS: Reservasi ganda pada listing reserved ditolak.';
  ELSE
    RAISE EXCEPTION '❌ TEST 4 GAGAL: %', v_res;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 5: Cancel order mengembalikan saldo penuh dan listing kembali active
  -- -------------------------------------------------------------
  v_res := cancel_order(v_order_id, v_buyer_id, 'Ingin ganti kartu');
  IF (v_res->>'ok')::BOOLEAN = true THEN
    SELECT balance_idr INTO v_buyer_bal FROM users WHERE id = v_buyer_id;
    SELECT status INTO v_listing_status FROM listings WHERE id = v_listing_id;
    SELECT status INTO v_order_status FROM orders WHERE id = v_order_id;

    IF v_buyer_bal = 500000 AND v_listing_status = 'active' AND v_order_status = 'cancelled' THEN
      RAISE NOTICE '✅ TEST 5 LULUS: Cancel sukses! Saldo kembali 500rb, listing kembali active.';
    ELSE
      RAISE EXCEPTION '❌ TEST 5 GAGAL: Saldo buyer %, listing %, order %', v_buyer_bal, v_listing_status, v_order_status;
    END IF;
  ELSE
    RAISE EXCEPTION '❌ TEST 5 GAGAL: %', v_res;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 6: Pesan ulang untuk pengujian kedaluwarsa otomatis (Simulasi memundurkan expires_at)
  -- -------------------------------------------------------------
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  v_order_id := (v_res->>'order_id')::UUID;
  -- Mundurkan waktu kedaluwarsa ke masa lalu
  UPDATE orders SET expires_at = NOW() - INTERVAL '1 hour' WHERE id = v_order_id;

  -- Panggil expire_stale_orders()
  PERFORM expire_stale_orders();

  SELECT balance_idr INTO v_buyer_bal FROM users WHERE id = v_buyer_id;
  SELECT status INTO v_listing_status FROM listings WHERE id = v_listing_id;
  SELECT status INTO v_order_status FROM orders WHERE id = v_order_id;

  IF v_buyer_bal = 500000 AND v_listing_status = 'active' AND v_order_status = 'expired' THEN
    RAISE NOTICE '✅ TEST 6 LULUS: Expire otomatis sukses! Saldo dikembalikan, listing active, order expired.';
  ELSE
    RAISE EXCEPTION '❌ TEST 6 GAGAL: Saldo %, listing %, order %', v_buyer_bal, v_listing_status, v_order_status;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 7: Confirm serah terima COD
  -- -------------------------------------------------------------
  -- Pesan ulang untuk uji confirm
  v_res := reserve_listing(v_listing_id, v_buyer_id);
  v_order_id := (v_res->>'order_id')::UUID;

  -- Uji confirm oleh orang lain (stranger) -> harus ditolak
  v_res := confirm_receipt(v_order_id, v_stranger_id);
  IF (v_res->>'ok')::BOOLEAN = false AND (v_res->>'error_code') = 'UNAUTHORIZED' THEN
    RAISE NOTICE '✅ TEST 7a LULUS: Confirm oleh pihak bukan pembeli ditolak.';
  ELSE
    RAISE EXCEPTION '❌ TEST 7a GAGAL: %', v_res;
  END IF;

  -- Confirm oleh pembeli yang sah
  v_res := confirm_receipt(v_order_id, v_buyer_id);
  IF (v_res->>'ok')::BOOLEAN = true THEN
    SELECT balance_idr INTO v_seller_bal FROM users WHERE id = v_seller_id;
    SELECT status INTO v_listing_status FROM listings WHERE id = v_listing_id;
    SELECT status INTO v_order_status FROM orders WHERE id = v_order_id;
    
    SELECT EXISTS (SELECT 1 FROM collections WHERE user_id = v_buyer_id AND card_id = v_test_card_id) INTO v_in_buyer_collection;
    SELECT EXISTS (SELECT 1 FROM collections WHERE user_id = v_seller_id AND card_id = v_test_card_id) INTO v_in_seller_collection;

    IF v_seller_bal = 300000 AND v_listing_status = 'sold' AND v_order_status = 'completed'
       AND v_in_buyer_collection = true AND v_in_seller_collection = false THEN
      RAISE NOTICE '✅ TEST 7b LULUS: Confirm sukses! Saldo penjual 100rb -> 300rb, listing sold, kartu berpindah ke koleksi pembeli.';
    ELSE
      RAISE EXCEPTION '❌ TEST 7b GAGAL: Saldo seller %, listing %, kartu buyer %, kartu seller %',
        v_seller_bal, v_listing_status, v_in_buyer_collection, v_in_seller_collection;
    END IF;
  ELSE
    RAISE EXCEPTION '❌ TEST 7b GAGAL: %', v_res;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 8: Confirm dua kali IDEMPOTEN (tidak menggandakan saldo)
  -- -------------------------------------------------------------
  v_res := confirm_receipt(v_order_id, v_buyer_id);
  SELECT balance_idr INTO v_seller_bal FROM users WHERE id = v_seller_id;
  IF (v_res->>'ok')::BOOLEAN = true AND (v_res->>'already_completed')::BOOLEAN = true AND v_seller_bal = 300000 THEN
    RAISE NOTICE '✅ TEST 8 LULUS: Confirm dua kali aman dan idempoten (saldo tidak berganda).';
  ELSE
    RAISE EXCEPTION '❌ TEST 8 GAGAL: % (Saldo: %)', v_res, v_seller_bal;
  END IF;

  -- -------------------------------------------------------------
  -- TEST 9: Invarian Keuangan Sistem
  -- Total saldo semua users + total amount_idr order reserved = KONSTAN
  -- -------------------------------------------------------------
  SELECT COALESCE(SUM(balance_idr), 0) INTO v_curr_total_balance FROM users;
  SELECT COALESCE(SUM(amount_idr), 0) INTO v_curr_reserved_amount FROM orders WHERE status = 'reserved';

  IF (v_curr_total_balance + v_curr_reserved_amount) = v_init_total_balance THEN
    RAISE NOTICE '✅ TEST 9 LULUS: INVARIAN TERJAGA! Total uang dalam sistem konstan (% = %)',
      (v_curr_total_balance + v_curr_reserved_amount), v_init_total_balance;
  ELSE
    RAISE EXCEPTION '❌ TEST 9 GAGAL: Invarian rusak! Awal: %, Akhir: %',
      v_init_total_balance, (v_curr_total_balance + v_curr_reserved_amount);
  END IF;

  RAISE NOTICE '==================================================';
  RAISE NOTICE '🎉 SELURUH 9 SKENARIO TEST REKBER BERHASIL 100% 🎉';
  RAISE NOTICE '==================================================';
END;
$$;

ROLLBACK; -- Membatalkan seluruh perubahan uji agar database tetap bersih

