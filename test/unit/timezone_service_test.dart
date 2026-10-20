import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/timezone_service.dart';

void main() {
  setUpAll(() {
    TimezoneService.ensureInitialized();
  });

  group('TimezoneService Tests', () {
    test('Memastikan inisialisasi berhasil dan lokasi tersedia', () {
      final jakarta = TimezoneService.getLocation('Asia/Jakarta');
      final makassar = TimezoneService.getLocation('Asia/Makassar');
      final jayapura = TimezoneService.getLocation('Asia/Jayapura');
      final london = TimezoneService.getLocation('Europe/London');

      expect(jakarta.name, equals('Asia/Jakarta'));
      expect(makassar.name, equals('Asia/Makassar'));
      expect(jayapura.name, equals('Asia/Jayapura'));
      expect(london.name, equals('Europe/London'));
    });

    test('Konversi waktu UTC tetap akurat dengan selisih zona WIB, WITA, WIT', () {
      // 2026-10-21 00:00:00 UTC
      final utcTime = DateTime.utc(2026, 10, 21, 0, 0, 0);

      final wib = TimezoneService.convertToZone(utcTime, AppTimeZone.wib);
      final wita = TimezoneService.convertToZone(utcTime, AppTimeZone.wita);
      final wit = TimezoneService.convertToZone(utcTime, AppTimeZone.wit);

      expect(wib.hour, equals(7)); // UTC+7
      expect(wita.hour, equals(8)); // UTC+8
      expect(wit.hour, equals(9)); // UTC+9
    });

    test('London mendeteksi BST (Daylight Saving Time) di musim panas (mis. Juli)', () {
      // Bulan Juli di London selalu BST (UTC+1)
      final summerDate = DateTime.utc(2026, 7, 15, 12, 0, 0);
      final londonSummer = TimezoneService.convertToZone(summerDate, AppTimeZone.london);

      expect(londonSummer.timeZone.isDst, isTrue);
      expect(londonSummer.timeZoneOffset.inHours, equals(1));
    });

    test('London mendeteksi GMT (tanpa DST) di musim dingin (mis. Januari)', () {
      // Bulan Januari di London selalu GMT (UTC+0)
      final winterDate = DateTime.utc(2026, 1, 15, 12, 0, 0);
      final londonWinter = TimezoneService.convertToZone(winterDate, AppTimeZone.london);

      expect(londonWinter.timeZone.isDst, isFalse);
      expect(londonWinter.timeZoneOffset.inHours, equals(0));
    });

    test('getAllZonesInfo menghasilkan data lengkap untuk keempat zona', () {
      final zonesInfo = TimezoneService.getAllZonesInfo();
      expect(zonesInfo.containsKey(AppTimeZone.wib), isTrue);
      expect(zonesInfo.containsKey(AppTimeZone.wita), isTrue);
      expect(zonesInfo.containsKey(AppTimeZone.wit), isTrue);
      expect(zonesInfo.containsKey(AppTimeZone.london), isTrue);

      expect(zonesInfo[AppTimeZone.wib]!.offsetLabel, equals('UTC+7'));
      expect(zonesInfo[AppTimeZone.wita]!.offsetLabel, equals('UTC+8'));
      expect(zonesInfo[AppTimeZone.wit]!.offsetLabel, equals('UTC+9'));
      expect(zonesInfo[AppTimeZone.london]!.offsetLabel, anyOf('UTC+0 (GMT)', 'UTC+1 (BST)'));
    });

    test('calculateCountdown menghitung sisa waktu secara presisi', () {
      final futureDate = DateTime.now().add(const Duration(days: 2, hours: 3, minutes: 15, seconds: 30));
      final countdown = TimezoneService.calculateCountdown(futureDate);

      expect(countdown['days'], equals(2));
      expect(countdown['hours'], equals(3));
      expect(countdown['isPast'], equals(0));
    });
  });
}
