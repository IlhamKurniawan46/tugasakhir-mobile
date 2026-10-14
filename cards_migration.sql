-- ============================================================
-- HOLODEX — Migrasi Sesi 4: Tambah Kolom price_ref_usd ke Tabel cards
-- Buka Supabase Dashboard -> SQL Editor -> New Query -> Tempel & Run
-- ============================================================

-- 1. Tambah kolom price_ref_usd (jika belum ada)
ALTER TABLE cards ADD COLUMN IF NOT EXISTS price_ref_usd NUMERIC(10,4);

-- 2. Buat indeks untuk pengurutan harga termahal -> termurah
CREATE INDEX IF NOT EXISTS idx_cards_price_ref_usd ON cards(price_ref_usd DESC NULLS LAST);
