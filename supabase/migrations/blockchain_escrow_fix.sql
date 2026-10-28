-- ============================================================
-- Migrasi Perbaikan Integrasi Blockchain & Marketplace Escrow
-- Jalankan file ini di Supabase SQL Editor
-- ============================================================

-- 1. Pastikan kolom blockchain ada di transactions dan collections
ALTER TABLE transactions 
  ADD COLUMN IF NOT EXISTS tx_hash TEXT,
  ADD COLUMN IF NOT EXISTS token_id TEXT,
  ADD COLUMN IF NOT EXISTS contract_address TEXT,
  ADD COLUMN IF NOT EXISTS blockchain_status TEXT DEFAULT 'confirmed';

ALTER TABLE collections
  ADD COLUMN IF NOT EXISTS tx_hash TEXT,
  ADD COLUMN IF NOT EXISTS token_id TEXT,
  ADD COLUMN IF NOT EXISTS contract_address TEXT;

-- 2. Perbarui RPC get_user_transactions agar mengembalikan kolom blockchain
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
      'tx_hash', t.tx_hash,
      'token_id', t.token_id,
      'contract_address', t.contract_address,
      'blockchain_status', COALESCE(t.blockchain_status, 'confirmed'),
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

GRANT EXECUTE ON FUNCTION get_user_transactions(UUID) TO anon, authenticated;

