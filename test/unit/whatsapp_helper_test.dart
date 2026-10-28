import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/order_repository.dart';
import 'package:holodex/core/utils/whatsapp_helper.dart';

void main() {
  group('WhatsAppHelper.normalizePhoneId Unit Tests', () {
    test('Mengubah awalan 0 menjadi 62 dengan benar', () {
      expect(WhatsAppHelper.normalizePhoneId('081234567890'), '6281234567890');
      expect(WhatsAppHelper.normalizePhoneId('085611223344'), '6285611223344');
    });

    test('Membuang spasi, tanda strip, kurung, dan awalan +62', () {
      expect(WhatsAppHelper.normalizePhoneId('+62 812-3456-7890'), '6281234567890');
      expect(WhatsAppHelper.normalizePhoneId('+62 (856) 1122-3344'), '6285611223344');
      expect(WhatsAppHelper.normalizePhoneId('62 813 9999 8888'), '6281399998888');
    });

    test('Mengubah awalan 8 langsung menjadi 628', () {
      expect(WhatsAppHelper.normalizePhoneId('81234567890'), '6281234567890');
      expect(WhatsAppHelper.normalizePhoneId('85611223344'), '6285611223344');
    });

    test('Mempertahankan nomor yang sudah berawalan 628', () {
      expect(WhatsAppHelper.normalizePhoneId('6281234567890'), '6281234567890');
    });

    test('Menolak nomor yang tidak valid / tidak sesuai kriteria', () {
      // Null dan kosong
      expect(WhatsAppHelper.normalizePhoneId(null), isNull);
      expect(WhatsAppHelper.normalizePhoneId(''), isNull);
      expect(WhatsAppHelper.normalizePhoneId('   '), isNull);

      // Terlalu pendek (< 10 digit)
      expect(WhatsAppHelper.normalizePhoneId('08123'), isNull);
      expect(WhatsAppHelper.normalizePhoneId('123456789'), isNull);

      // Terlalu panjang (> 15 digit)
      expect(WhatsAppHelper.normalizePhoneId('081234567890123456'), isNull);

      // Bukan nomor seluler Indonesia (bukan berawalan 628)
      expect(WhatsAppHelper.normalizePhoneId('02112345678'), isNull); // Telepon rumah Jakarta
      expect(WhatsAppHelper.normalizePhoneId('+1 555-123-4567'), isNull); // Nomor AS

      // Mengandung huruf murni tanpa digit yang cukup
      expect(WhatsAppHelper.normalizePhoneId('nomorsaya'), isNull);
    });
  });

  group('WhatsAppHelper.maskPhoneNumber Unit Tests', () {
    test('Menyamarkan nomor dengan menyisakan 4 digit terakhir', () {
      expect(WhatsAppHelper.maskPhoneNumber('6281234567890'), '•••• •••• 7890');
      expect(WhatsAppHelper.maskPhoneNumber('081298765432'), '•••• •••• 5432');
      expect(WhatsAppHelper.maskPhoneNumber('+62 812-3456-1122'), '•••• •••• 1122');
    });

    test('Mengembalikan Belum diatur untuk nomor kosong atau null', () {
      expect(WhatsAppHelper.maskPhoneNumber(null), 'Belum diatur');
      expect(WhatsAppHelper.maskPhoneNumber(''), 'Belum diatur');
      expect(WhatsAppHelper.maskPhoneNumber('   '), 'Belum diatur');
    });
  });

  group('WhatsAppHelper.buildInitialCodMessage & buildWhatsAppUri Unit Tests', () {
    test('Menghasilkan template pesan awal COD dengan benar', () {
      final msg = WhatsAppHelper.buildInitialCodMessage(
        myName: 'Budi',
        cardName: 'Charizard V',
        shortOrderId: 'A1B2C3',
        codLocation: '-6.9175, 107.6191',
      );

      expect(msg, contains('Halo, saya Budi dari HoloDex.'));
      expect(msg, contains('pesanan Charizard V (#A1B2C3)'));
      expect(msg, contains('di titik COD -6.9175, 107.6191'));
      expect(msg, contains('Kapan kita bisa bertemu?'));
    });

    test('Membentuk URL wa.me dengan encoding parameter teks yang tepat', () {
      final uri = WhatsAppHelper.buildWhatsAppUri(
        phone: '081234567890',
        message: 'Halo, saya Budi! Pesanan #ABC.',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/6281234567890');
      expect(uri.queryParameters['text'], 'Halo, saya Budi! Pesanan #ABC.');
      // Memastikan URL mentah ter-encode dengan aman
      expect(uri.toString(), contains('https://wa.me/6281234567890?text='));
    });

    test('getShortOrderId menghasilkan 6 karakter alfanumerik kapital', () {
      expect(WhatsAppHelper.getShortOrderId('e1f2a3b4-5678-9abc-def0'), 'E1F2A3');
      expect(WhatsAppHelper.getShortOrderId('ab12'), 'AB12');
    });
  });

  group('OrderRepository WhatsApp Error Code Mapping Unit Tests', () {
    test('Memetakan kode kesalahan WhatsApp ke pesan ramah pengguna', () {
      expect(
        OrderRepository.mapErrorCodeToMessage('whatsapp_required'),
        contains('Nomor WhatsApp wajib diisi'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('not_allowed'),
        contains('Kontak WhatsApp hanya dapat diakses saat status pesanan masih aktif'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('no_contact'),
        contains('Pihak lawan belum mengisi nomor WhatsApp'),
      );
      expect(
        OrderRepository.mapErrorCodeToMessage('INVALID_PHONE_NUMBER'),
        contains('Format nomor WhatsApp tidak valid'),
      );
    });
  });
}

