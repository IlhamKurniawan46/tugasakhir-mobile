# HoloDex — Pokémon TCG Companion & P2P Collector Marketplace

[![Flutter](https://img.shields.io/badge/Flutter-3.13%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.1%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?logo=android&logoColor=white)](https://android.com)
[![Tests](https://img.shields.io/badge/Tests-119%20Passed-brightgreen?logo=checkmarx&logoColor=white)](test/)
[![Security](https://img.shields.io/badge/Security-PBKDF2--HMAC--SHA256-blueviolet?logo=shield&logoColor=white)](#-keamanan--kriptografi)
[![Blockchain](https://img.shields.io/badge/Web3-Polygon%20Amoy%20ERC--721-8247E5?logo=polygon&logoColor=white)](#-sertifikasi-kepemilikan-digital-web3--blockchain)

**HoloDex** adalah aplikasi mobile *end-to-end* untuk kolektor Pokémon TCG yang menggabungkan katalog kartu interaktif, pasar *peer-to-peer* (P2P) berbasis lokasi fisik (LBS), simulasi fisik kartu holografik 3D berbantuan sensor giroskop, mesin rekomendasi personal *on-device* berbasis privasi, dan sertifikasi kepemilikan digital terdesentralisasi (blockchain).

---

## 📑 Daftar Isi
1. [Fitur Utama](#-fitur-utama)
2. [Spesifikasi Arsitektur & Rekayasa Sistem](#-spesifikasi-arsitektur--rekayasa-sistem)
3. [Keamanan & Kriptografi](#-keamanan--kriptografi)
4. [Sertifikasi Kepemilikan Digital (Web3 & Blockchain)](#-sertifikasi-kepemilikan-digital-web3--blockchain)
5. [AI Personal On-Device & HoloBot](#-ai-personal-on-device--holobot)
6. [Struktur Direktori Proyek](#-struktur-direktori-proyek)
7. [Panduan Instalasi & Menjalankan Proyek](#-panduan-instalasi--menjalankan-proyek)
8. [Jaminan Kualitas & Pengujian Otomatis](#-jaminan-kualitas--pengujian-otomatis)
9. [Alur Eksplorasi Fitur (User Journey)](#-alur-eksplorasi-fitur-user-journey)
10. [Lisensi & Penafian](#-lisensi--penafian)

---

## 🌟 Fitur Utama

- **Katalog Terkurasi Multi-Set:** Ratusan kartu dari berbagai generasi dan seri kartu terpopuler (`swsh3`, `swsh7`, `sv01`, `sv05`, `sv03.5`, `me02.5`, `sv08.5`, `me02`) dengan integrasi data nilai pasar internasional (TCGPlayer & Cardmarket).
- **Mesin Konversi Multi-Mata Uang Real-Time:** Sinkronisasi kurs acuan resmi European Central Bank (ECB / Frankfurter API) yang mendukung konversi terpusat 4 mata uang (**IDR, USD, EUR, JPY**) dengan cache toleran offline (TTL 24 jam).
- **Simulasi Holografik 3D Berbasis Sensor (Gyroscope):** Lapisan efek kemilau foil interaktif yang merespons orientasi kemiringan fisik perangkat pengguna secara presisi dengan visualisasi cahaya dinamis.
- **Pasar Peer-to-Peer & LBS Terintegrasi:** Kolektor dapat memperjualbelikan kartu fisik, menandai titik temu COD (*Cash on Delivery*) berbasis OpenStreetMap & geolokasi GPS presisi, serta mengeksekusi transaksi atomik di backend.
- **Rekomendasi Cerdas On-Device (Zero-Cloud Privacy):** Algoritma *content-based filtering* heuristik berbobot dengan peluruhan eksponensial waktu (*time-decay exponential*, waktu paruh 14 hari) yang mempelajari selera kolektor secara lokal tanpa mengirimkan data pribadi ke server.
- **Asisten AI Terintegrasi (HoloBot):** Analisis kelayakan koleksi kartu dan generator deskripsi barang jual otomatis memanfaatkan model Google Gemini melalui koneksi HTTP REST murni.
- **Mini Game Booster Pack Simulator (Accelerometer):** Interaksi buka kartu menggunakan guncangan fisik ponsel (*shake-to-reveal*), animasi buka kartu berbobot probabilitas resmi, efek *haptic feedback*, dan kalkulasi nilai perolehan IDR.
- **Sertifikasi Digital Terdesentralisasi:** Pencatatan riwayat kepemilikan kartu fisik (*digital provenance*) pada jaringan publik Polygon Testnet Amoy (ERC-721), dilengkapi pemindai QR Code dan tautan verifikasi penjelajah blok (PolygonScan).

---

## ⚙️ Spesifikasi Arsitektur & Rekayasa Sistem

Aplikasi ini dibangun menggunakan arsitektur modular **Feature-First** berbasis Flutter & Riverpod tanpa *code-generation*, memberikan kendali penuh pada performa, skalabilitas, dan kemudahan audit kode.

| Modul Sistem | Kapabilitas & Implementasi Teknis | Komponen / Layar Utama | Stack & Pustaka Utama |
|---|---|---|---|
| **Manajemen Autentikasi** | Salted hashing PBKDF2-HMAC-SHA256 (100.000 iterasi), zero plaintext password, sesi UUID persisten di hardware secure enclave. | `lib/features/auth/` | `pointycastle`, `flutter_secure_storage` |
| **Keamanan Biometrik** | Autentikasi sidik jari perangkat dengan fallback verifikasi kata sandi kriptografis. | `lib/core/services/biometric_service.dart` | `local_auth` |
| **Penyimpanan Ganda (Hybrid Database)** | **Cloud:** PostgreSQL terkelola via Supabase dengan transaksi atomik RPC.<br>**Edge/Local:** SQLite v6 untuk cache offline, watchlist, riwayat minat, dan sertifikat kartu. | `lib/core/database/` | `sqflite`, `supabase_flutter` |
| **Layanan Web & LBS** | Integrasi REST API publik (TCGdex, ECB) dan penentuan titik temu COD interaktif berbasis peta OSM dengan kalkulasi jarak formula Haversine. | `lib/features/marketplace/` | `http`, `flutter_map`, `geolocator` |
| **Katalog & Konversi Finansial** | Normalisasi harga global, konversi dinamis 4 mata uang (IDR, USD, EUR, JPY), dan pemantau jadwal rilis set kartu dengan jam digital 4 zona waktu (WIB, WITA, WIT, London GMT/BST). | `lib/features/converter/`<br>`lib/features/dex/` | `http` (Frankfurter), `timezone`, `intl` |
| **Integrasi Sensor Fisik** | **Gyroscope:** Kalkulasi rotasi kuaternion/derajat untuk shader kilau holo 3D.<br>**Accelerometer:** Deteksi ambang batas akselerasi guncangan (*shake gesture*) untuk mini game. | `lib/features/dex/widgets/holo_card_widget.dart`<br>`lib/features/pack_opening/` | `sensors_plus` |
| **Kecerdasan Buatan (LLM)** | Asisten penasihat kartu koleksi dan pembuat draf deskripsi listing otomatis via direct REST request ke Google Gemini API (tanpa SDK pihak ketiga yang berat). | `lib/features/ai/` | `http` (Direct Gemini REST endpoint) |
| **Pencarian & Seleksi Tingkat Lanjut** | Pencarian instan ter-debounce (400ms), multi-filter terindeks (Set, Rarity, Tipe), pengurutan multi-kriteria, serta mode seleksi kartu massal (*multi-select contextual action bar*). | `lib/features/dex/` | `flutter_riverpod` |
| **Sistem Notifikasi Lokal** | Notifikasi push sistem berkala untuk pengingat kalender rilis set kartu, klaim booster pack, dan status penyelesaian transaksi pasar. | `lib/core/services/notification_service.dart` | `flutter_local_notifications`, `timezone` |
| **Provenance Blockchain** | Smart contract ERC-721 di Polygon Amoy Testnet (Chain ID 80002), penelusuran transaksi on-chain via PolygonScan, modal QR Code verifikasi fisik, dan buku besar *hash-chain* SHA-256 lokal. | `lib/features/marketplace/screens/ledger_screen.dart` | `web3dart`, `crypto`, `qr_flutter`, `url_launcher` |
| **Personalisasi On-Device** | Content-based filtering heuristik berbobot berbasis histori interaksi lokal, carousel "Rekomendasi Untuk Kamu", penandaan cerdas "Cocok", dan visualisasi Radar Minat. | `lib/core/services/recommendation_engine.dart` | SQLite v6 (`user_interactions`), In-Memory Affinity Matrix |

---

## 🔒 Keamanan & Kriptografi

HoloDex menerapkan prinsip pertahanan berlapis (*defense-in-depth*) untuk melindungi privasi dan integritas data pengguna:

1. **Hashing Kata Sandi Mandiri (PBKDF2-HMAC-SHA256):**
   - Menggunakan salt acak 16-byte kriptografis aman (`SecureRandom` dari PointyCastle).
   - Melakukan 100.000 iterasi peregangan kunci (*key stretching*) dengan panjang output 32-byte.
   - Pengecekan kecocokan kata sandi menggunakan fungsi perbandingan waktu-konstan (*constant-time equality check*) untuk mencegah eksploitasi *timing attacks*.
2. **Penyimpanan Sesi Hardware-Backed:**
   - Kredensial sesi disimpan menggunakan `flutter_secure_storage` yang terenkripsi langsung pada modul Android Keystore / iOS Keychain.
   - Tidak ada token sensitif yang disimpan dalam `SharedPreferences` biasa.
3. **Integritas Transaksi Atomik (ACID):**
   - Transaksi jual-beli pasar dieksekusi secara atomik melalui PostgreSQL Stored Procedure (`buy_listing`) pada Supabase, mencegah *race condition* dan pengeluaran ganda (*double spending*).
4. **Isolasi Data Minat Lokal:**
   - Seluruh jejak klik, pencarian, dan preferensi kuis pengguna disimpan murni di database lokal SQLite v6. Tidak ada data analitik perilaku yang diunggah ke cloud.

---

## ⛓️ Sertifikasi Kepemilikan Digital (Web3 & Blockchain)

Untuk menjamin keaslian dan melacak riwayat perpindahan tangan kartu bernilai tinggi:
- **Jaringan:** Polygon Testnet (Amoy) — Chain ID `80002`.
- **Standar Kontrak:** ERC-721 (`HoloDexCertificate.sol`) dengan pencatatan `mintCard` dan `recordTransfer`.
- **Relayer Tanpa Friksi Gas:** Dilengkapi mekanisme *custodial relayer* yang menandatangani transaksi on-chain sehingga pengguna tidak perlu memasang dompet eksternal atau memikirkan gas fee.
- **Auditabilitas Publik:** Setiap transaksi menghasilkan `tx_hash` dan `token_id` valid yang dapat diperiksa langsung di [PolygonScan Explorer](https://amoy.polygonscan.com) serta diverifikasi melalui QR Code digital.
- **Ledger Hash-Chain Lokal:** Setiap mutasi kepemilikan membentuk blok rantai hash kriptografis SHA-256 di basis data lokal sebagai verifikasi cadangan saat offline.

---

## 🧠 AI Personal On-Device & HoloBot

### 1. On-Device Recommendation Engine (Zero-Cloud Privacy)
Berbeda dengan sistem rekomendasi berbasis cloud yang mengumpulkan privasi pengguna, HoloDex menjalankan mesin inferensi *content-based filtering* 100% di perangkat:
- **Event Logging Berbobot:** Pembelian (`5.0`), Penambahan Watchlist (`3.0`), Kuis Minat (`3.0`), Pencarian Terarah (`2.0`), dan Peninjauan Kartu (`1.0`).
- **Peluruhan Waktu Eksponensial:** Riwayat diberi bobot berbasis rumus peluruhan waktu:
  $$w(t) = w_0 \times 2^{-\frac{\Delta t}{14\text{ hari}}}$$
  Interaksi yang berumur lebih dari 90 hari otomatis dieliminasi ($w = 0$).
- **Anti-Filter Bubble:** Penalti diversitas membatasi maksimal 3 kartu dari set yang sama, mengecualikan kartu yang sudah dimiliki/dilihat dalam 24 jam, serta mencadangkan 20% slot untuk eksplorasi kartu bernilai tinggi di luar selera utama pengguna.

### 2. Generative AI Companion (HoloBot & Auto-Copywriter)
- Menggunakan arsitektur koneksi langsung ke Google Gemini API via REST HTTP.
- Memberikan masukan strategis mengenai tren kelangkaan kartu, pergerakan harga pasar, dan menghasilkan deskripsi penjualan kartu secara otomatis, rapi, dan terstruktur.

---

## 📁 Struktur Direktori Proyek

```
lib/
├── app/                  # Inisialisasi aplikasi, deklarasi rute (go_router), tema visual
├── core/
│   ├── constants/        # Token warna (AppColors), tipografi, dimensi responsif
│   ├── database/         # SQLite helper (local_db.dart) & klien REST Supabase
│   ├── models/           # Entitas data (CardModel, ListingModel, UserModel, dll.)
│   ├── services/         # Layanan auth PBKDF2, biometrik, currency, lokasi, blockchain, notifikasi
│   └── utils/            # Formatter harga multi-kurs, utilitas hash, env loader
├── features/
│   ├── auth/             # Splash screen, Login (PBKDF2 & Biometrik), Registrasi
│   ├── dex/              # Katalog kartu Pokémon, carousel rekomendasi AI, filter & detail kartu
│   ├── marketplace/      # Pasar P2P, peta LBS penjual COD, buat listing, buku besar blockchain
│   ├── profile/          # Profil pengguna, ganti foto profil kamera/galeri, radar selera AI, binder koleksi
│   ├── pack_opening/     # Mini game simulasi pack opening dengan sensor akselerometer
│   ├── converter/        # Konverter kurs 4 mata uang & kalender jam 4 zona waktu
│   ├── ai/               # HoloBot penasihat kartu koleksi via Gemini REST
│   └── saran_kesan/      # Modul masukan & evaluasi pengguna
└── shared/
    ├── providers/        # State Riverpod global terpusat
    └── widgets/          # Komponen UI global (BottomNavShell, LoadingWidget)
```

---

## 🛠️ Panduan Instalasi & Menjalankan Proyek

### 1. Prasyarat Sistem
- **Flutter SDK:** Version `^3.13.2` atau lebih baru
- **Dart SDK:** Version `^3.1.0`
- **Android Target:** API Level 26 ke atas (Android 8.0+)
- **JDK:** OpenJDK 17

### 2. Kloning Repositori & Instalasi Paket
```bash
git clone https://github.com/IlhamKurniawan46/tugasakhir-mobile.git
cd tugasakhir-mobile
flutter pub get
```

### 3. Konfigurasi Kredensial Environment (`.env`)
Salin berkas konfigurasi template:
```bash
cp .env.example .env
```
Sesuaikan parameter environment di dalam berkas `.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
GEMINI_API_KEY=your_gemini_api_key
POLYGON_AMOY_RPC_URL=https://polygon-amoy-bor-rpc.publicnode.com
POLYGON_EXPLORER_BASE_URL=https://amoy.polygonscan.com
BLOCKCHAIN_OPERATOR_PRIVATE_KEY=your_operator_private_key
```

### 4. Menjalankan Mode Pengembangan
Pastikan perangkat Android atau emulator terhubung:
```bash
flutter run
```

### 5. Kompilasi Berkas APK Siap Pakai
Untuk membuat bundel APK debug mandiri:
```bash
flutter build apk --debug
```
Berkas keluaran biner berada di: `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 🧪 Jaminan Kualitas & Pengujian Otomatis

Keandalan seluruh modul diverifikasi melalui rangkaian pengujian unit dan widget otomatis:

```bash
flutter test
```

### Rekapitulasi Hasil Uji Otomatis
```text
00:15 +119: All tests passed!
```
- **Rekomendasi Cerdas On-Device:** 10 pengujian unit mencakup normalisasi nama Pokémon, peluruhan eksponensial waktu, kedekatan rentang harga, penalti saturasi set, dan mekanisme *cold start*.
- **Database & Interaksi SQLite:** 5 pengujian unit mencakup deduplikasi log 30 detik, isolasi multitenant lokal, pemangkasan batas 1.000 riwayat, dan pencatatan kuis.
- **Konversi Finansial & Waktu:** 8 pengujian unit untuk keakuratan kalkulasi 4 zona waktu (WIB, WITA, WIT, London GMT/BST daylight saving) dan konversi mata uang lintas negara.
- **Layanan Notifikasi & LBS:** 9 pengujian unit mencakup parsing payload routing, pencegahan notifikasi kedaluwarsa, dan kalkulasi jarak geospasial Haversine.
- **Enkripsi & Layout Responsif:** 80+ pengujian unit dan widget mencakup verifikasi hash PBKDF2, probabilitas buka booster pack, dan ketahanan layout pada layar 320dp dengan skala font besar (bebas *overflow*).

---

## 🗺️ Alur Eksplorasi Fitur (User Journey)

1. **Autentikasi & Keamanan:**
   - Registrasi pengguna baru dengan pengacakan salt 16-byte.
   - Masuk akun dan aktifkan tombol **"Login Sidik Jari"** pada tab Profil untuk login instan selanjutnya via biometrik.
2. **Katalog & Konversi Dinamis:**
   - Jelajahi katalog kartu di tab **Dex**. Ubah mata uang aktif (**IDR, USD, EUR, JPY**) pada chip header untuk melihat pembaruan harga real-time berbasis kurs ECB.
   - Gunakan fitur pencarian instan dan filter multi-atribut. Tekan lama kartu untuk mengaktifkan **Mode Multi-Select** guna menghitung akumulasi nilai koleksi kartu.
3. **Simulasi Sensorik (Holo 3D & Shake Pack):**
   - Buka kartu berlabel holo pada detail kartu. Miringkan perangkat fisik untuk mengamati pantulan cahaya holografik 3D yang digerakkan sensor giroskop.
   - Masuk ke menu **"Mini Game"** di beranda Dex. Guncang fisik ponsel (*accelerometer*) untuk membuka booster pack 5 kartu beranimasi.
4. **Pasar Kolektor & Peta COD:**
   - Masuk ke tab **Pasar** untuk meninjau listing penjualan kartu.
   - Buka tampilan peta LBS interaktif untuk memvisualisasikan titik temu COD terdekat dari koordinat pengguna.
   - Buat listing penjualan kartu, sematkan koordinat GPS lokasi fisik Anda, dan manfaatkan tombol **"Tulis via AI"** untuk membuat narasi deskripsi penjualan otomatis.
5. **Verifikasi Web3 & Buku Besar Kepemilikan:**
   - Selesaikan transaksi pembelian di pasar.
   - Buka menu **"Buku Besar Blockchain"** untuk melihat sertifikat kepemilikan kartu yang tercatat permanen di Polygon Testnet Amoy, lengkap dengan tautan PolygonScan dan QR Code fisik.
6. **Personalisasi & Kontrol Privasi:**
   - Amati bagaimana deretan kartu pada carousel **"Untuk Kamu"** di beranda dan lencana **"Cocok"** di pasar beradaptasi secara dinamis mengikuti kartu yang sering Anda lihat.
   - Masuk ke tab **Profil** untuk melihat visualisasi **Radar Minat Kolektor**, atau tekan tombol **"Reset Data"** kapan saja untuk menghapus seluruh riwayat analitik lokal secara transparan.

---

## ⚖️ Lisensi & Penafian

- **Hak Cipta Konten:** Hak cipta atas nama Pokémon, ilustrasi kartu, atribut, dan merek dagang Pokémon TCG merupakan hak milik sepenuhnya dari Nintendo, Creatures Inc., dan The Pokémon Company International.
- **Tujuan Pengembangan:** Proyek ini dikembangkan secara independen sebagai platform edukasi non-komersial dan implementasi rekayasa perangkat lunak mobile modern.
- **Lisensi Kode:** Seluruh kode sumber dirilis di bawah lisensi terbuka [MIT License](LICENSE).