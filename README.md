# HoloDex — Pokémon TCG Catalog & Collector Marketplace

> **Tugas Akhir Mata Kuliah Pemrograman Aplikasi Mobile**  
> Aplikasi mobile katalog kartu Pokémon TCG interaktif dan pasar kolektor *peer-to-peer* (P2P) berbasis Flutter, mengintegrasikan sensor perangkat, kecerdasan buatan, keamanan kriptografis, multi-database, serta verifikasi kepemilikan terdesentralisasi (blockchain).

---

## 📱 Daftar Isi
1. [Tentang HoloDex](#-tentang-holodex)
2. [Tabel Pemetaan 13 Ketentuan Dosen + Fitur Tambahan](#-tabel-pemetaan-13-ketentuan-dosen--fitur-tambahan)
3. [Arsitektur & Tech Stack](#-arsitektur--tech-stack)
4. [Struktur Direktori Proyek](#-struktur-direktori-proyek)
5. [Cara Instalasi & Menjalankan Aplikasi](#-cara-instalasi--menjalankan-aplikasi)
6. [Skenario Pengujian & Panduan Demo Dosen](#-skenario-pengujian--panduan-demo-dosen)
7. [Hasil Pengujian Otomatis (Unit & Widget Tests)](#-hasil-pengujian-otomatis)

---

## 🌟 Tentang HoloDex

**HoloDex** dirancang khusus untuk memecahkan tantangan kolektor Pokémon TCG di Indonesia:
- **Katalog Terkurasi:** Menampilkan ratusan kartu dari 4 set populer (`swsh3`, `swsh7`, `sv01`, `sv05`, `sv03.5`, `me02.5`, `sv08.5`, `me02`) dengan data harga acuan internasional (TCGPlayer & Cardmarket).
- **Konversi Multi-Mata Uang Terpusat:** Menampilkan harga real-time dalam Rupiah (IDR), Dolar AS (USD), Euro (EUR), dan Yen Jepang (JPY) melalui integrasi resmi European Central Bank (ECB / Frankfurter API).
- **Efek Holografik Sensorik:** Kartu foil/holofoil bereaksi terhadap kemiringan fisik ponsel pengguna menggunakan sensor *gyroscope*, menciptakan pantulan cahaya holografik 3D yang dinamis.
- **Pasar Peer-to-Peer & LBS:** Kolektor dapat memperjualbelikan kartu fisik, menentukan titik temu COD (*Cash on Delivery*) berbasis GPS/peta interaktif, serta melakukan transaksi atomik aman.
- **Sertifikasi Blockchain & AI Advisor:** Verifikasi riwayat kepemilikan kartu tercatat pada Polygon Testnet (ERC-721) dan hash-chain lokal, didukung oleh asisten AI Gemini (HoloBot) serta mesin rekomendasi personal *on-device*.

---

## 📋 Tabel Pemetaan 13 Ketentuan Dosen + Fitur Tambahan

Semua 13 poin ketentuan tugas akhir telah diimplementasikan secara tuntas tanpa menggunakan Firebase:

| # | Ketentuan Dosen | Implementasi Fitur di HoloDex | Komponen / Layar Utama | Package & Teknologi |
|---|----------------|-------------------------------|------------------------|---------------------|
| **1** | **Konsep Proyek Jelas** | Ekosistem kolektor Pokémon TCG Indonesia: Katalog, Simulasi Pack Opening, Pasar P2P COD, dan Binder Koleksi Fisik. | Seluruh aplikasi | Flutter, Material Design 3 |
| **2** | **Login Terenkripsi (TANPA Firebase) + Session** | Autentikasi mandiri menggunakan salt random 16-byte dan hashing PBKDF2-HMAC-SHA256 (100.000 iterasi). Token sesi UUID persisten di enkripsi hardware. | `lib/features/auth/screens/login_screen.dart`<br>`lib/core/services/auth_service.dart` | `pointycastle`,<br>`flutter_secure_storage` (Android Keystore) |
| **3** | **Biometric Fingerprint + Fallback Password** | Login instan dengan sidik jari pada perangkat Android dengan fallback autentikasi kata sandi manual. Pengaturan toggle diaktifkan di Profil. | `lib/features/auth/screens/login_screen.dart`<br>`lib/core/services/biometric_service.dart` | `local_auth` |
| **4** | **Database Lokal DAN Online** | **Online:** Supabase PostgreSQL untuk data pengguna, katalog kartu, listing pasar, dan RPC transaksi atomik.<br>**Lokal:** SQLite (6 migrasi skema) untuk offline cache, watchlist, riwayat minat, dan sertifikat kartu. | `lib/core/database/local_db.dart`<br>`lib/core/database/supabase_client.dart` | `sqflite`,<br>`supabase_flutter` |
| **5** | **Web Service / REST API + LBS** | Integrasi API publik TCGdex & Frankfurter API, serta fitur LBS pemilihan koordinat COD dan pencarian penjual terdekat dengan kalkulasi Haversine. | `lib/features/marketplace/screens/map_screen.dart`<br>`lib/core/services/location_service.dart` | `http`,<br>`flutter_map`,<br>`geolocator` |
| **6** | **Bottom Nav, Profil (Foto), Saran & Kesan, Logout** | 4 tab utama + 1 tab Saran & Kesan. Profil mendukung penggantian foto diri via Kamera/Galeri atau hapus foto, serta tombol keluar akun aman. | `lib/features/profile/screens/profile_screen.dart`<br>`lib/features/saran_kesan/screens/saran_kesan_screen.dart` | `go_router`,<br>`image_picker`,<br>`path_provider` |
| **7** | **Konversi Mata Uang (min. 3) + 4 Zona Waktu** | Konversi 4 mata uang (IDR, USD, EUR, JPY) dengan cache kurs ECB 24 jam. Kalender jadwal rilis set kartu dengan jam digital tabular dan countdown di 4 zona waktu (WIB, WITA, WIT, London GMT/BST). | `lib/features/converter/screens/converter_screen.dart`<br>`lib/features/converter/screens/calendar_screen.dart` | `http` (Frankfurter),<br>`timezone`,<br>`intl` |
| **8** | **Minimal 2 Sensor Perangkat** | **Sensor 1 (Gyroscope):** Efek tilt holografik 3D & kemilau cahaya pada kartu foil.<br>**Sensor 2 (Accelerometer):** Deteksi guncangan ponsel (*shake*) untuk membuka booster pack kartu. | `lib/features/dex/widgets/holo_card_widget.dart`<br>`lib/features/pack_opening/screens/pack_opening_screen.dart` | `sensors_plus` |
| **9** | **AI / LLM Terintegrasi** | **HoloBot:** Penasihat kartu cerdas menggunakan Gemini REST API murni (rekomendasi investasi & analisis kartu).<br>**Auto-listing Generator:** Pembuat deskripsi listing otomatis berdasarkan kondisi dan nama kartu. | `lib/features/ai/services/gemini_service.dart`<br>`lib/features/ai/widgets/ai_advisor_sheet.dart` | `http` (Direct Gemini REST endpoint) |
| **10** | **Mini Game Sederhana** | Simulasi Buka Booster Pack: guncang ponsel atau ketuk buka pack, animasi buka kartu per kartu, efek haptic, perhitungan total nilai IDR pack, dan papan skor koleksi. | `lib/features/pack_opening/screens/pack_opening_screen.dart` | `sensors_plus`,<br>`flutter_riverpod` |
| **11** | **Pencarian & Pemilihan Data** | Pencarian teks instan (debounce 400ms), filter multi-kategori (Set, Rarity, Tipe Energi), pengurutan dinamis (Harga, Nama), dan mode pilih multi-select kartu katalog (tekan lama). | `lib/features/dex/screens/search_screen.dart`<br>`lib/features/dex/screens/dex_screen.dart` | Flutter Material, `flutter_riverpod` |
| **12** | **Notifikasi Mobile** | Notifikasi lokal sistem terjadwal untuk jadwal rilis set kartu Pokémon TCG, pengingat klaim pack harian, dan notifikasi sukses transaksi pasar dengan payload navigasi. | `lib/core/services/notification_service.dart` | `flutter_local_notifications`,<br>`timezone` |
| **13** | **Blockchain Sederhana** | Smart Contract ERC-721 di Polygon Amoy Testnet (Chain ID 80002) untuk pencatatan sertifikat kepemilikan kartu (*provenance* digital), tautan langsung ke PolygonScan Explorer, verifikasi QR Code, dan buku besar (*ledger*) hash-chain SHA-256 lokal. | `lib/features/marketplace/screens/ledger_screen.dart`<br>`lib/core/services/blockchain_service.dart` | `web3dart`,<br>`crypto` (SHA-256),<br>`qr_flutter`,<br>`url_launcher` |
| **+** | **AI Rekomendasi Personal On-Device** | Content-based filtering heuristik berbobot dengan *time-decay exponential* (waktu paruh 14 hari) berdasarkan perilaku kolektor di SQLite lokal, Carousel "Untuk Kamu", badge "Cocok" di pasar, dan Radar Minat di profil. | `lib/core/services/recommendation_engine.dart`<br>`lib/features/dex/widgets/recommendation_carousel.dart` | SQLite v6 (`user_interactions`), In-memory Affinity Matrix |

---

## 🏗️ Arsitektur & Tech Stack

```
lib/
├── app/                  # Inisialisasi aplikasi, router (go_router), & tema gelap konsisten
├── core/
│   ├── constants/        # Token warna (AppColors), tema typography, konstanta sistem
│   ├── database/         # SQLite helper (local_db.dart) & Supabase REST client
│   ├── models/           # Data models manual (CardModel, ListingModel, UserModel, dll.)
│   ├── services/         # Layanan auth PBKDF2, biometrik, currency, lokasi, blockchain, notifikasi
│   └── utils/            # Formatter harga multi-mata uang, hashing, env loader
├── features/
│   ├── auth/             # Splash screen, Login (PBKDF2 & Biometrik), Registrasi
│   ├── dex/              # Katalog kartu Pokémon, carousel rekomendasi AI, filter & detail kartu
│   ├── marketplace/      # Pasar P2P, peta LBS penjual COD, buat listing, buku besar blockchain
│   ├── profile/          # Profil pengguna, ganti foto profil, radar selera AI, binder koleksi & watchlist
│   ├── pack_opening/     # Mini game buka booster pack kartu dengan accelerometer
│   ├── converter/        # Konverter 4 mata uang & kalender jam 4 zona waktu
│   ├── ai/               # HoloBot asisten AI Gemini via REST API murni
│   └── saran_kesan/      # Form masukan, saran & kesan perkuliahan
└── shared/
    ├── providers/        # State Riverpod global (shared_providers.dart)
    └── widgets/          # Komponen UI global (BottomNavShell, LoadingWidget)
```

### Prinsip Utama
1. **Feature-First Architecture:** Tiap domain fitur terisolasi di dalam direktorinya masing-masing.
2. **Tanpa Code Generation:** Model data ditulis tangan dengan validasi parsing yang aman, menghindari build runner yang berat.
3. **Keamanan Bertingkat:** Tanpa hardcoded secret keys. Kunci sensitif dimuat melalui `.env`. Password tidak pernah disimpan dalam format teks biasa, melainkan melalui *salted hashing* PBKDF2.

---

## 🚀 Cara Instalasi & Menjalankan Aplikasi

### 1. Prasyarat
- Flutter SDK `^3.13.2` atau lebih baru
- Android SDK (API Level 26+ / Android 8.0 ke atas direkomendasikan)
- Java Development Kit (JDK 17)

### 2. Kloning Repositori & Instalasi Dependensi
```bash
git clone https://github.com/IlhamKurniawan46/tugasakhir-mobile.git
cd tugasakhir-mobile
flutter pub get
```

### 3. Konfigurasi Environment (`.env`)
Salin berkas `.env.example` menjadi `.env` di root proyek:
```bash
cp .env.example .env
```
Isi variabel konfigurasi di dalam file `.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
GEMINI_API_KEY=your_gemini_api_key
POLYGON_AMOY_RPC_URL=https://polygon-amoy-bor-rpc.publicnode.com
POLYGON_EXPLORER_BASE_URL=https://amoy.polygonscan.com
BLOCKCHAIN_OPERATOR_PRIVATE_KEY=your_operator_private_key
```

### 4. Menjalankan Aplikasi
Hubungkan perangkat Android fisik atau jalankan emulator Android, lalu jalankan:
```bash
flutter run
```

### 5. Kompilasi APK Debug Siap Pakai
Untuk menguji instalasi langsung pada HP demo tanpa komputer:
```bash
flutter build apk --debug
```
Berkas APK output berada di: `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 🧪 Hasil Pengujian Otomatis

Proyek ini dilengkapi rangkaian pengujian unit dan widget otomatis untuk memastikan keandalan fungsi:

```bash
flutter test
```
**Hasil:**
```text
00:15 +119: All tests passed!
```
- **10 Unit Tests:** Algoritma rekomendasi personal on-device (ekstraksi nama, peluruhan waktu, scoring afinitas, penalti diversitas set, cold-start fallback).
- **5 Unit Tests:** Layanan interaksi SQLite (deduplikasi 30 detik, isolasi multi-user, pemangkasan batas event).
- **8 Unit Tests:** Layanan konversi 4 zona waktu (WIB, WITA, WIT, London GMT/BST & daylight saving).
- **5 Unit Tests:** Layanan notifikasi lokal & formatting payload routing.
- **4 Unit Tests:** Kalkulasi jarak GPS Haversine & validasi LBS.
- **80+ Unit & Widget Tests:** Enkripsi PBKDF2, simulasi probabilitas pack opening, parser kartu, dan rendering responsif bebas overflow layout pada layar sempit 320dp.

---

## 🎬 Skenario Pengujian & Panduan Demo Dosen

Untuk mendemokan ke-13 ketentuan kepada dosen penguji secara efisien, ikuti alur skenario berikut:

1. **Autentikasi & Biometrik (Ketentuan 2, 3, 4):**
   - Buka aplikasi → Halaman Splash menampilkan logo HoloDex.
   - Daftar akun baru di layar Register.
   - Masuk menggunakan password (demonstrasikan hashing PBKDF2).
   - Masuk ke tab **Profil** → aktifkan tombol **"Login Sidik Jari"**.
   - Logout akun → pada layar Login, tekan tombol sidik jari untuk login instan tanpa mengetik password.
2. **Katalog Kartu & Konversi Mata Uang (Ketentuan 1, 4, 7, 11):**
   - Pada tab **Dex**, ketuk chip mata uang di header (**IDR**, **USD**, **EUR**, **JPY**) untuk melihat harga kartu berubah secara instan mengikuti kurs ECB terkini.
   - Gunakan fitur pencarian (misal ketik *"Charizard"* atau *"Pikachu"*), gunakan filter set atau tipe elemen.
   - Tekan lama pada salah satu kartu untuk mengaktifkan **Mode Multi-Select** → pilih 2 kartu → ketuk ikon ringkasan harga di AppBar untuk melihat total nilai kartu.
3. **Sensor 1 — Gyroscope Holografik 3D (Ketentuan 8):**
   - Buka detail kartu berlabel holo (misal kartu foil Charizard atau Dragonite).
   - Miringkan HP ke kiri, kanan, atas, dan bawah → perhatikan lapisan cahaya holografik bergerak dinamis mengikuti sudut kemiringan fisik perangkat.
4. **AI Asisten HoloBot (Ketentuan 9):**
   - Pada halaman detail kartu atau dari tile beranda, buka **"HoloBot"**.
   - Ajukan pertanyaan seperti *"Apakah kartu ini cocok untuk investasi jangka panjang?"* → HoloBot memberikan analisis berbasis data kartu.
5. **Sensor 2 & Mini Game — Pack Opening (Ketentuan 8, 10):**
   - Pada baris fitur di tab Dex, pilih tile **"Mini Game"**.
   - Guncangkan HP (*shake accelerometer*) atau ketuk tombol buka pack.
   - Buka kartu satu per satu dengan efek haptic feedback → lihat total nilai IDR pack yang didapatkan dan bandingkan di papan leaderboard.
6. **Pasar P2P, LBS, & Deskripsi AI (Ketentuan 4, 5, 9):**
   - Di tab **Pasar**, ketuk ikon peta untuk melihat sebaran penjual terdekat berbasis OpenStreetMap.
   - Buka tombol **"Jual Kartu"** (buat listing) → gunakan tombol **"Kunci Titik GPS"** untuk menyematkan lokasi COD penjual.
   - Tekan tombol **"Tulis via AI"** pada kolom deskripsi → AI Gemini secara otomatis menyusun deskripsi promosi barang dagangan yang menarik dan sopan.
   - Beli listing kartu menggunakan saldo virtual → verifikasi transaksi tersimpan atomik di Supabase dan saldo terpotong akurat.
7. **Sertifikat Blockchain & Ledger Transaksi (Ketentuan 13):**
   - Masuk ke detail kartu yang dibeli atau menu **"Buku Besar Blockchain"**.
   - Tunjukkan hash SHA-256 yang saling mengikat (*hash-chain*) dan tombol **"Lihat di PolygonScan"** untuk membuktikan catatan transaksi terdesentralisasi di Polygon Testnet Amoy. Tampilkan juga modal QR Code untuk pemindaian instan via kamera.
8. **Fitur Pelengkap & Profil (Ketentuan 6, 7):**
   - Buka tile **"Konverter & Waktu"** → tunjukkan konversi multi-arah 4 mata uang dan jam digital 4 zona waktu (WIB, WITA, WIT, London GMT/BST) lengkap dengan countdown rilis set baru.
   - Masuk ke tab **Profil** → ketuk avatar untuk **mengganti foto profil** menggunakan kamera atau galeri ponsel.
   - Buka tab **Saran & Kesan** → isi masukan dan kesan perkuliahan mata kuliah Pemrograman Aplikasi Mobile.
9. **AI Rekomendasi On-Device (Fitur Tambahan):**
   - Tunjukkan Carousel **"Rekomendasi Untuk Kamu"** di beranda yang mempelajari histori pencarian dan klik kartu pengguna secara lokal tanpa internet.
   - Tunjukkan **Radar Minat Kolektor** di tab Profil beserta tombol **Reset Data Minat**.

---