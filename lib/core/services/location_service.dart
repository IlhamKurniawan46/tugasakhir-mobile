import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Layanan penanganan GPS dan Location-Based Services (LBS) HoloDex.
class LocationService {
  /// Koordinat default (Monas, Jakarta Pusat) jika GPS dimatikan atau izin ditolak.
  static const LatLng defaultLocation = LatLng(-6.1754, 106.8272);

  /// Cek dan minta izin lokasi ke pengguna secara bertahap.
  static Future<LocationPermission> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Mengambil lokasi GPS pengguna saat ini.
  /// Mengembalikan null jika izin ditolak atau layanan tidak aktif.
  static Future<Position?> getCurrentPosition() async {
    try {
      // 1. Minta izin aplikasi terlebih dahulu agar dialog izin Android muncul
      final permission = await checkAndRequestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[HoloDex LBS] Izin lokasi ditolak oleh pengguna ($permission).');
        return null;
      }

      // 2. Cek apakah layanan GPS di perangkat aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[HoloDex LBS] Layanan GPS perangkat dinonaktifkan.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('[HoloDex LBS Error] Gagal mendapatkan lokasi GPS: $e');
      return null;
    }
  }

  /// Mendapatkan pesan penjelasan status izin dan GPS untuk pengguna
  static Future<String> getStatusExplanation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return 'Izin lokasi dinonaktifkan di sistem. Buka Pengaturan untuk mengizinkan.';
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Layanan GPS perangkat sedang nonaktif. Silakan nyalakan GPS.';
    }
    return 'Izin lokasi tidak diberikan. Menampilkan pusat Jakarta sebagai titik acuan.';
  }

  /// Buka pengaturan aplikasi di Android
  static Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Menghitung jarak antara dua koordinat geografis dalam satuan Kilometer (km).
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return distanceInMeters / 1000.0;
  }

  /// Format teks jarak yang ramah dibaca pengguna.
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }
}
