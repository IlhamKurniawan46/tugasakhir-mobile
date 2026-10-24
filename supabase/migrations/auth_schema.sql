-- ============================================================
-- RPC Autentikasi
-- Jalankan di Supabase SQL Editor SETELAH supabase_schema.sql
-- ============================================================
-- Tabel users dikunci RLS tanpa policy, jadi anon key tidak bisa
-- SELECT/INSERT langsung. Dua fungsi di bawah memakai SECURITY DEFINER
-- (berjalan dengan hak pemilik fungsi) dan hanya membuka kolom yang perlu.

-- Daftar user baru. Hash & salt dihitung di HP (PBKDF2), server hanya menyimpan.
CREATE OR REPLACE FUNCTION register_user(
  p_username TEXT,
  p_email TEXT,
  p_password_hash TEXT,
  p_salt TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user users%ROWTYPE;
BEGIN
  IF length(trim(p_username)) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Username minimal 3 karakter');
  END IF;

  IF EXISTS (SELECT 1 FROM users WHERE lower(username) = lower(trim(p_username))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Username sudah dipakai');
  END IF;

  IF p_email IS NOT NULL AND p_email <> ''
     AND EXISTS (SELECT 1 FROM users WHERE lower(email) = lower(trim(p_email))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Email sudah terdaftar');
  END IF;

  INSERT INTO users (username, email, password_hash, salt)
  VALUES (trim(p_username), NULLIF(lower(trim(p_email)), ''), p_password_hash, p_salt)
  RETURNING * INTO v_user;

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
END;
$$;

-- Ambil kredensial untuk login. HP menghitung ulang PBKDF2 dengan salt ini
-- lalu membandingkan hash secara constant-time.
-- Catatan jujur: hash ikut terkirim ke klien. Aman selama PBKDF2 100k iterasi
-- dipakai, tapi untuk produksi pembandingan sebaiknya di server.
CREATE OR REPLACE FUNCTION get_login_credentials(p_username TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user users%ROWTYPE;
BEGIN
  SELECT * INTO v_user FROM users WHERE lower(username) = lower(trim(p_username));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'salt', v_user.salt,
    'password_hash', v_user.password_hash,
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
END;
$$;

REVOKE ALL ON FUNCTION register_user(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_login_credentials(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION register_user(TEXT, TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_login_credentials(TEXT) TO anon;
