-- ============================================================
-- Koleksi Migration
-- Jalankan di Supabase SQL Editor
-- ============================================================

-- 1. Tambah kolom acquired_via di tabel collections (default: 'purchase')
ALTER TABLE collections 
ADD COLUMN IF NOT EXISTS acquired_via TEXT DEFAULT 'purchase';

-- 2. Index untuk query cepat per user
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON collections(user_id);

-- 3. Grant hak akses baca (SELECT) untuk role anon
GRANT SELECT ON collections TO anon;

-- 4. Fungsi RPC: Ambil Daftar Koleksi User beserta Data Kartu
CREATE OR REPLACE FUNCTION get_user_collection(p_user_id UUID)
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
      'card_id', c.card_id,
      'acquired_via', COALESCE(c.acquired_via, 'purchase'),
      'acquired_at', c.acquired_at,
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
    ) ORDER BY c.acquired_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM collections c
  JOIN cards k ON k.id = c.card_id
  WHERE c.user_id = p_user_id;

  RETURN jsonb_build_object('success', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_collection(UUID) TO anon;

-- ============================================================
-- CONTOH DATA UJI BINDER (Jalankan bila ingin memberi kartu uji)
-- Ganti 'PASTE_USER_ID_DISINI' dengan ID user Anda dari tabel users.
-- ============================================================
/*
DO $$
DECLARE
  v_test_user_id UUID;
BEGIN
  -- Ambil ID user pertama yang ada di database jika belum tahu ID-nya:
  SELECT id INTO v_test_user_id FROM users ORDER BY created_at ASC LIMIT 1;

  IF v_test_user_id IS NOT NULL THEN
    -- Masukkan 3 kartu contoh hasil pembelian simulasi:
    INSERT INTO collections (user_id, card_id, acquired_via, acquired_at)
    VALUES 
      (v_test_user_id, 'swsh3-19', 'purchase', NOW() - INTERVAL '2 days'),
      (v_test_user_id, 'swsh3-20', 'purchase', NOW() - INTERVAL '1 day'),
      (v_test_user_id, 'swsh7-215', 'purchase', NOW())
    ON CONFLICT (user_id, card_id) DO UPDATE
      SET acquired_via = 'purchase';
      
    RAISE NOTICE 'Kartu uji berhasil dimasukkan untuk user %', v_test_user_id;
  ELSE
    RAISE NOTICE 'Belum ada user di tabel users. Silakan register akun terlebih dahulu di app.';
  END IF;
END $$;
*/
