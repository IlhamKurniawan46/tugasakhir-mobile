import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/location_service.dart';

void main() {
  group('LocationService Unit Tests', () {
    test('calculateDistanceKm returns accurate distance between two coordinates', () {
      // Monas Jakarta (-6.1754, 106.8272) ke Gedung Sate Bandung (-6.9025, 107.6186)
      final distanceKm = LocationService.calculateDistanceKm(
        startLatitude: -6.1754,
        startLongitude: 106.8272,
        endLatitude: -6.9025,
        endLongitude: 107.6186,
      );

      // Jarak geografis garis lurus sekitar 118-122 km
      expect(distanceKm, greaterThan(110.0));
      expect(distanceKm, lessThan(130.0));
    });

    test('calculateDistanceKm returns 0 for same coordinates', () {
      final distanceKm = LocationService.calculateDistanceKm(
        startLatitude: -6.1754,
        startLongitude: 106.8272,
        endLatitude: -6.1754,
        endLongitude: 106.8272,
      );

      expect(distanceKm, closeTo(0.0, 0.001));
    });

    test('formatDistance formats meters when distance < 1 km', () {
      expect(LocationService.formatDistance(0.35), '350 m');
      expect(LocationService.formatDistance(0.05), '50 m');
      expect(LocationService.formatDistance(0.999), '999 m');
    });

    test('formatDistance formats 1 decimal place when 1 km <= distance < 10 km', () {
      expect(LocationService.formatDistance(1.23), '1.2 km');
      expect(LocationService.formatDistance(5.67), '5.7 km');
      expect(LocationService.formatDistance(9.94), '9.9 km');
    });

    test('formatDistance formats rounded integer when distance >= 10 km', () {
      expect(LocationService.formatDistance(10.4), '10 km');
      expect(LocationService.formatDistance(25.8), '26 km');
      expect(LocationService.formatDistance(120.2), '120 km');
    });
  });
}
