-- ============================================================
-- Blockchain Provenance & Certificate Migration
-- Jalankan file ini di Supabase SQL Editor
-- ============================================================

-- 1. Tambahkan kolom blockchain ke tabel TRANSACTIONS
ALTER TABLE transactions 
  ADD COLUMN IF NOT EXISTS tx_hash TEXT,
  ADD COLUMN IF NOT EXISTS token_id TEXT,
  ADD COLUMN IF NOT EXISTS contract_address TEXT,
  ADD COLUMN IF NOT EXISTS blockchain_status TEXT DEFAULT 'confirmed';

CREATE INDEX IF NOT EXISTS idx_transactions_tx_hash ON transactions(tx_hash);

-- 2. Tambahkan kolom blockchain ke tabel COLLECTIONS
ALTER TABLE collections
  ADD COLUMN IF NOT EXISTS tx_hash TEXT,
  ADD COLUMN IF NOT EXISTS token_id TEXT,
  ADD COLUMN IF NOT EXISTS contract_address TEXT;

CREATE INDEX IF NOT EXISTS idx_collections_token_id ON collections(token_id);

-- 3. Tabel CARD_CERTIFICATES (Riwayat Provenance On-Chain untuk Verifikasi Publik)
CREATE TABLE IF NOT EXISTS card_certificates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id TEXT NOT NULL REFERENCES cards(id),
  token_id TEXT NOT NULL,
  contract_address TEXT NOT NULL,
  tx_hash TEXT NOT NULL,
  from_address TEXT,
  to_address TEXT NOT NULL,
  owner_username TEXT,
  action TEXT NOT NULL DEFAULT 'minted' CHECK (action IN ('minted', 'transferred')),
  price_idr NUMERIC(15,2) DEFAULT 0,
  notes TEXT,
  block_number BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_card_certificates_card_id ON card_certificates(card_id);
CREATE INDEX IF NOT EXISTS idx_card_certificates_token_id ON card_certificates(token_id);
CREATE INDEX IF NOT EXISTS idx_card_certificates_tx_hash ON card_certificates(tx_hash);
CREATE INDEX IF NOT EXISTS idx_card_certificates_created_at ON card_certificates(created_at DESC);

-- 4. Hak Akses (RLS & Grant)
ALTER TABLE card_certificates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Akses publik baca sertifikat kartu"
  ON card_certificates FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Akses tulis sertifikat kartu"
  ON card_certificates FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

GRANT SELECT, INSERT ON card_certificates TO anon, authenticated;

-- 5. RPC: Ambil Riwayat Provenance Kartu Lengkap
CREATE OR REPLACE FUNCTION get_card_provenance(p_card_id TEXT)
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
      'id', c.id,
      'card_id', c.card_id,
      'token_id', c.token_id,
      'contract_address', c.contract_address,
      'tx_hash', c.tx_hash,
      'from_address', c.from_address,
      'to_address', c.to_address,
      'owner_username', c.owner_username,
      'action', c.action,
      'price_idr', c.price_idr,
      'notes', c.notes,
      'block_number', c.block_number,
      'created_at', c.created_at
    ) ORDER BY c.created_at ASC
  ), '[]'::jsonb)
  INTO v_result
  FROM card_certificates c
  WHERE c.card_id = p_card_id;

  RETURN jsonb_build_object('success', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION get_card_provenance(TEXT) TO anon, authenticated;
