class AppConstants {
  // Nama & Info App
  static const String appName = 'HoloDex';
  static const String appVersion = '1.0.0';

  // Disclaimer Wajib Dosen/Lisensi
  static const String academicDisclaimer =
      'HoloDex tidak berafiliasi dengan Nintendo, The Pokémon Company, atau TCGplayer. '
      'Nama dan gambar Pokémon adalah merek dagang pemiliknya. '
      'Aplikasi ini dibuat semata-mata untuk tujuan akademis (Tugas Akhir).';

  // API Endpoints
  static const String tcgdexBaseUrl = 'https://api.tcgdex.net/v2/en';
  static const String frankfurterBaseUrl = 'https://api.frankfurter.dev';
  static const String geminiModel = 'gemini-3.8-flash';

  // SQLite Database
  static const String localDbName = 'holodex.db';
  static const int localDbVersion = 7;

  // Nilai Awal Saldo Baru (Simulasi)
  static const double initialBalanceIdr = 100000.0;
}
