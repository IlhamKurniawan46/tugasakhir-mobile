import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Enum 4 zona waktu yang didukung sesuai Ketentuan Dosen #7:
/// 3 zona waktu nasional (WIB, WITA, WIT) + 1 zona internasional (London).
enum AppTimeZone {
  wib(
    code: 'WIB',
    name: 'Waktu Indonesia Barat',
    locationName: 'Asia/Jakarta',
    baseOffsetHours: 7,
    flag: '🇮🇩',
  ),
  wita(
    code: 'WITA',
    name: 'Waktu Indonesia Tengah',
    locationName: 'Asia/Makassar',
    baseOffsetHours: 8,
    flag: '🇮🇩',
  ),
  wit(
    code: 'WIT',
    name: 'Waktu Indonesia Timur',
    locationName: 'Asia/Jayapura',
    baseOffsetHours: 9,
    flag: '🇮🇩',
  ),
  london(
    code: 'LDN',
    name: 'London (GMT / BST)',
    locationName: 'Europe/London',
    baseOffsetHours: 0,
    flag: '🇬🇧',
  );

  final String code;
  final String name;
  final String locationName;
  final int baseOffsetHours;
  final String flag;

  const AppTimeZone({
    required this.code,
    required this.name,
    required this.locationName,
    required this.baseOffsetHours,
    required this.flag,
  });
}

/// Representasi data waktu dari suatu zona
class ZoneTimeInfo {
  final AppTimeZone zone;
  final DateTime dateTime;
  final String timeFormatted; // misal "14:30:15"
  final String dateFormatted; // misal "21 Okt 2026"
  final String offsetLabel; // misal "UTC+7" atau "UTC+1 (BST)"
  final bool isDst; // Daylight Saving Time (khusus London saat musim panas)

  const ZoneTimeInfo({
    required this.zone,
    required this.dateTime,
    required this.timeFormatted,
    required this.dateFormatted,
    required this.offsetLabel,
    this.isDst = false,
  });
}

/// Layanan penanganan zona waktu berbasis pustaka resmi `timezone`.
/// Menjamin penanganan offset otomatis termasuk Daylight Saving Time (DST) di London.
class TimezoneService {
  static bool _initialized = false;

  /// Inisialisasi basis data zona waktu IANA
  static void ensureInitialized() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Ambil objek `tz.Location` berdasarkan nama lokasi
  static tz.Location getLocation(String locationName) {
    ensureInitialized();
    return tz.getLocation(locationName);
  }

  /// Dapatkan waktu sekarang di zona tertentu
  static tz.TZDateTime nowInZone(AppTimeZone zone) {
    ensureInitialized();
    final location = tz.getLocation(zone.locationName);
    return tz.TZDateTime.now(location);
  }

  /// Konversi sembarang `DateTime` (UTC atau Local) ke zona tertentu
  static tz.TZDateTime convertToZone(DateTime dateTime, AppTimeZone targetZone) {
    ensureInitialized();
    final location = tz.getLocation(targetZone.locationName);
    // Pastikan konversi berbasis UTC yang akurat
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return tz.TZDateTime.from(utc, location);
  }

  /// Konversi waktu tertentu dari suatu zona asal ke semua 4 zona
  static Map<AppTimeZone, ZoneTimeInfo> getAllZonesInfo([DateTime? sourceTime, AppTimeZone? fromZone]) {
    ensureInitialized();
    
    // Tentukan waktu UTC acuan
    late final DateTime utcTime;
    if (sourceTime == null) {
      utcTime = DateTime.now().toUtc();
    } else if (fromZone != null) {
      final loc = tz.getLocation(fromZone.locationName);
      final tzFrom = tz.TZDateTime(
        loc,
        sourceTime.year,
        sourceTime.month,
        sourceTime.day,
        sourceTime.hour,
        sourceTime.minute,
        sourceTime.second,
      );
      utcTime = tzFrom.toUtc();
    } else {
      utcTime = sourceTime.isUtc ? sourceTime : sourceTime.toUtc();
    }

    final result = <AppTimeZone, ZoneTimeInfo>{};

    for (final zone in AppTimeZone.values) {
      final loc = tz.getLocation(zone.locationName);
      final tzDate = tz.TZDateTime.from(utcTime, loc);
      final isDst = tzDate.timeZone.isDst;
      final offsetHours = tzDate.timeZoneOffset.inHours;

      String offsetLabel = offsetHours >= 0 ? 'UTC+$offsetHours' : 'UTC$offsetHours';
      if (zone == AppTimeZone.london) {
        offsetLabel = isDst ? 'UTC+1 (BST)' : 'UTC+0 (GMT)';
      }

      final h = tzDate.hour.toString().padLeft(2, '0');
      final m = tzDate.minute.toString().padLeft(2, '0');
      final s = tzDate.second.toString().padLeft(2, '0');
      final timeFormatted = '$h:$m:$s';

      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final dateFormatted = '${tzDate.day} ${months[tzDate.month - 1]} ${tzDate.year}';

      result[zone] = ZoneTimeInfo(
        zone: zone,
        dateTime: tzDate,
        timeFormatted: timeFormatted,
        dateFormatted: dateFormatted,
        offsetLabel: offsetLabel,
        isDst: isDst,
      );
    }

    return result;
  }

  /// Format countdown durasi dari sekarang sampai waktu target
  static Map<String, int> calculateCountdown(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now);

    if (difference.isNegative) {
      return {'days': 0, 'hours': 0, 'minutes': 0, 'seconds': 0, 'isPast': 1};
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return {
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'isPast': 0,
    };
  }
}
