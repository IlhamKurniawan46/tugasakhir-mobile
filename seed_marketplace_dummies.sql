-- ============================================================
-- HOLODEX — Seed 10 Akun Penjual Dummy & Listing Marketplace
-- Jalankan file ini di Supabase SQL Editor
-- Mengisi Marketplace & Peta LBS dengan beragam kartu & lokasi kota di Indonesia
-- ============================================================

DO $$
DECLARE
  v_users UUID[] := ARRAY[]::UUID[];
  v_uid UUID;
  v_cards RECORD;
  v_i INT := 1;

  -- Profil 10 Penjual Dummy di Berbagai Kota Besar Indonesia (LBS Geolocation)
  v_sellers JSONB := '[
    {"username": "Surabaya_Card_Vault", "email": "seller_sby@holodex.demo", "city": "Surabaya", "lat": -7.2575, "lng": 112.7521},
    {"username": "Jogja_Holo_Center", "email": "seller_jogja@holodex.demo", "city": "Yogyakarta", "lat": -7.7956, "lng": 110.3695},
    {"username": "Semarang_TCG_Hub", "email": "seller_smg@holodex.demo", "city": "Semarang", "lat": -6.9667, "lng": 110.4167},
    {"username": "Malang_Pokestore", "email": "seller_mlg@holodex.demo", "city": "Malang", "lat": -7.9666, "lng": 112.6326},
    {"username": "Bali_Trainer_Corner", "email": "seller_dps@holodex.demo", "city": "Denpasar", "lat": -8.6705, "lng": 115.2126},
    {"username": "Medan_Card_Empire", "email": "seller_mdn@holodex.demo", "city": "Medan", "lat": 3.5952, "lng": 98.6722},
    {"username": "Makassar_PokeClub", "email": "seller_mks@holodex.demo", "city": "Makassar", "lat": -5.1477, "lng": 119.4327},
    {"username": "Tangerang_TCG_Base", "email": "seller_tng@holodex.demo", "city": "Tangerang", "lat": -6.1783, "lng": 106.6319},
    {"username": "Bekasi_Card_Kingdom", "email": "seller_bks@holodex.demo", "city": "Bekasi", "lat": -6.2383, "lng": 106.9756},
    {"username": "Solo_Collector_Point", "email": "seller_slo@holodex.demo", "city": "Surakarta", "lat": -7.5755, "lng": 110.8243}
  ]'::JSONB;

  v_s JSONB;
  v_conditions TEXT[] := ARRAY['mint', 'near_mint', 'excellent', 'near_mint', 'mint', 'excellent', 'near_mint', 'mint', 'good', 'mint'];
  v_descriptions TEXT[] := ARRAY[
    'Koleksi pribadi super mulus, langsung masuk sleeve + magnetic case sejak unboxing.',
    'Near mint condition, holo foil bersinar tanpa whitening di tepi kartu.',
    'Kartu simpanan binder album turnamen, sangat terawat dan siap play.',
    'Pull segar dari booster pack, centering sempurna no scratch.',
    'Kartu langka edisi kolektor, bonus hard toploader + bubble wrap tebal.',
    'Kondisi excellent, sangat layak untuk melengkapi binder master set.',
    'Holofoil mulus 99%, disimpan di ruangan ber-AC bebas lembab.',
    'Kondisi mint sempurna, sangat berpotensi grading PSA 9-10.',
    'Kartu staple turnamen, ada sedikit jejak shuffle tapi overall sangat bagus.',
    'Special Illustration / Ultra Rare istimewa, mulus 100% no minus.'
  ];
  v_prices NUMERIC[] := ARRAY[
    850000, 320000, 145000, 480000, 210000,
    95000, 650000, 1200000, 85000, 390000
  ];

BEGIN
  -- 1. Buat / Update 10 Pengguna Penjual Dummy
  FOR v_i IN 0..9 LOOP
    v_s := v_sellers->v_i;

    INSERT INTO users (username, email, password_hash, salt, balance_idr)
    VALUES (
      v_s->>'username',
      v_s->>'email',
      'dummy_pbkdf2_hash_' || (v_i + 10),
      'dummy_salt_' || (v_i + 10),
      1500000 + (v_i * 100000)
    )
    ON CONFLICT (username) DO UPDATE 
      SET balance_idr = users.balance_idr
    RETURNING id INTO v_uid;

    v_users := array_append(v_users, v_uid);
  END LOOP;

  RAISE NOTICE '10 Akun Penjual Dummy siap. ID: %', v_users;

  -- 2. Ambil 10 Kartu Nyata dari Katalog (beragam harga) dan pasang listing
  v_i := 1;
  FOR v_cards IN (
    SELECT id, name, price_idr 
    FROM cards 
    WHERE has_price = true 
    ORDER BY price_idr DESC NULLS LAST 
    LIMIT 10 OFFSET 5
  ) LOOP
    v_s := v_sellers->(v_i - 1);
    v_uid := v_users[v_i];

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
      v_cards.id,
      v_uid,
      COALESCE(v_cards.price_idr, v_prices[v_i]),
      v_conditions[v_i],
      v_descriptions[v_i],
      (v_s->>'lat')::DOUBLE PRECISION,
      (v_s->>'lng')::DOUBLE PRECISION,
      'active'
    );

    v_i := v_i + 1;
    IF v_i > 10 THEN EXIT; END IF;
  END LOOP;

  -- Tambahan 5 listing pelengkap dengan harga ramah pemula (Budget Friendly)
  v_i := 1;
  FOR v_cards IN (
    SELECT id, name, price_idr 
    FROM cards 
    WHERE has_price = true 
    ORDER BY price_idr ASC NULLS LAST 
    LIMIT 5 OFFSET 15
  ) LOOP
    v_s := v_sellers->(v_i - 1);
    v_uid := v_users[v_i];

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
      v_cards.id,
      v_uid,
      GREATEST(COALESCE(v_cards.price_idr, 35000), 25000),
      'near_mint',
      'Harga bersahabat untuk pemain baru! Kondisi bagus mulus terawat.',
      (v_s->>'lat')::DOUBLE PRECISION + 0.015,
      (v_s->>'lng')::DOUBLE PRECISION + 0.015,
      'active'
    );

    v_i := v_i + 1;
  END LOOP;

  RAISE NOTICE 'Seed selesai: Total 15 listing marketplace aktif di 10 kota berhasil dibuat!';
END $$;
