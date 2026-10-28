-- ==============================================================================
-- HOLODEX: SEED NOMOR WHATSAPP PENJUAL DEMO
-- ==============================================================================
-- PANDUAN PENTING:
-- Ganti [ISI_NOMOR_SAYA] di bawah ini dengan nomor WhatsApp AKTIF yang Anda
-- kendalikan sendiri (misal: '081234567890' atau '6281234567890').
--
-- JANGAN menggunakan nomor acak atau nomor milik orang lain agar pengujian
-- tombol WhatsApp membuka percakapan yang aman dan nyata di ponsel Anda.
-- ==============================================================================

-- 1. Nomor WhatsApp untuk Penjual Demo 1 (Kolektor_Jakarta)
UPDATE users 
SET whatsapp_number = normalize_phone_id('[ISI_NOMOR_SAYA]')
WHERE username = 'Kolektor_Jakarta';

-- 2. Nomor WhatsApp untuk Penjual Demo 2 (Bandung_TCG_Shop)
UPDATE users 
SET whatsapp_number = normalize_phone_id('[ISI_NOMOR_SAYA]')
WHERE username = 'Bandung_TCG_Shop';

-- Verifikasi hasil pembaruan:
SELECT username, email, whatsapp_number 
FROM users 
WHERE username IN ('Kolektor_Jakarta', 'Bandung_TCG_Shop');

