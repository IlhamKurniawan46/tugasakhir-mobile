/// Helper murni untuk pengelolaan nomor WhatsApp, penyamaran privasi,
/// dan pembentukan URL wa.me dengan pesan awal serah terima COD.
class WhatsAppHelper {
  WhatsAppHelper._();

  /// Normalisasi nomor telepon format Indonesia.
  /// - Membuang semua karakter non-digit (spasi, tanda strip, kurung, dsb.).
  /// - Mengubah awalan `0` menjadi `62` (misal `0812` -> `62812`).
  /// - Mengubah awalan `+62` menjadi `62`.
  /// - Mengubah awalan `8` langsung menjadi `628`.
  /// - Memvalidasi panjang digit (10 sampai 15 digit) dan awalan `628`.
  /// Mengembalikan `null` jika format tidak valid atau kosong.
  static String? normalizePhoneId(String? raw) {
    if (raw == null) return null;

    // Hapus semua karakter non-digit
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return null;

    String normalized = clean;

    if (normalized.startsWith('0')) {
      normalized = '62${normalized.substring(1)}';
    } else if (normalized.startsWith('8')) {
      normalized = '62$normalized';
    }

    // Panjang standar nomor seluler Indonesia dengan kode negara 62: 10 - 15 digit
    if (normalized.length < 10 || normalized.length > 15) {
      return null;
    }

    // Nomor seluler Indonesia setelah 62 harus diawali digit 8 (misal 628...)
    if (!normalized.startsWith('628')) {
      return null;
    }

    return normalized;
  }

  /// Menyamarkan nomor telepon demi privasi.
  /// Hanya menampilkan 4 digit terakhir (misal: `•••• •••• 1234`).
  /// Mengembalikan 'Belum diatur' jika nomor kosong/null.
  static String maskPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Belum diatur';
    }

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) {
      return '••••';
    }

    final last4 = digits.substring(digits.length - 4);
    return '•••• •••• $last4';
  }

  /// Format tampilan nomor terkelompok (misal: `+62 812-3456-7890`).
  static String formatDisplayPhone(String? phone) {
    final normalized = normalizePhoneId(phone);
    if (normalized == null) return phone ?? '-';

    if (normalized.startsWith('62') && normalized.length >= 11) {
      final p1 = normalized.substring(2, 5); // 812
      final p2 = normalized.substring(5, 9); // 3456
      final p3 = normalized.substring(9); // 7890
      return '+62 $p1-$p2-$p3';
    }

    return '+$normalized';
  }

  /// Membentuk template pesan awal konfirmasi pertemuan COD.
  /// Format sesuai instruksi:
  /// "Halo, saya [nama] dari HoloDex. Soal pesanan [nama kartu] (#[kode pendek order]) di titik COD [nama titik]. Kapan kita bisa bertemu?"
  static String buildInitialCodMessage({
    required String myName,
    required String cardName,
    required String shortOrderId,
    required String codLocation,
  }) {
    final cleanName = myName.trim().isEmpty ? 'Kolektor' : myName.trim();
    final cleanCard = cardName.trim().isEmpty ? 'Kartu Pokémon' : cardName.trim();
    final cleanLoc = codLocation.trim().isEmpty ? 'titik yang disepakati' : codLocation.trim();
    final cleanShortId = shortOrderId.trim().isEmpty ? 'PESANAN' : shortOrderId.trim();

    return 'Halo, saya $cleanName dari HoloDex. Soal pesanan $cleanCard (#$cleanShortId) di titik COD $cleanLoc. Kapan kita bisa bertemu?';
  }

  /// Membentuk URL wa.me resmi dengan parameter teks yang di-URL-encode.
  /// Menghasilkan format: `https://wa.me/<digit>?text=<urlencoded>`
  static Uri buildWhatsAppUri({
    required String phone,
    required String message,
  }) {
    final normalized = normalizePhoneId(phone) ?? phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedText = Uri.encodeComponent(message);
    return Uri.parse('https://wa.me/$normalized?text=$encodedText');
  }

  /// Mengambil kode pendek order (6 karakter pertama) untuk referensi pesan chat.
  static String getShortOrderId(String orderId) {
    final clean = orderId.replaceAll('-', '').trim();
    if (clean.length <= 6) return clean.toUpperCase();
    return clean.substring(0, 6).toUpperCase();
  }
}

