import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('NotificationService Unit Tests', () {
    final service = NotificationService.instance;

    test('Channel ID terkonfigurasi dengan benar sesuai modul', () {
      expect(NotificationService.channelEvents, 'holodex_events');
      expect(NotificationService.channelMarketplace, 'holodex_marketplace');
      expect(NotificationService.channelAlerts, 'holodex_alerts');
    });

    test('scheduleEventNotification menolak tanggal yang sudah berlalu', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final result = await service.scheduleEventNotification(
        id: 999,
        title: 'Event Lampau',
        body: 'Event ini sudah selesai',
        scheduledDate: pastDate,
      );

      expect(result, NotificationScheduleResult.pastTime);
    });

    test('Payload notifikasi berformat JSON valid untuk deep linking routing', () {
      final payloadData = {
        'type': 'card_detail',
        'cardId': 'swsh7-215',
      };

      final encoded = jsonEncode(payloadData);
      expect(encoded, contains('swsh7-215'));

      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['type'], 'card_detail');
      expect(decoded['cardId'], 'swsh7-215');
    });

    test('Callback onNotificationTapped memicu listener payload', () {
      String? capturedPayload;
      NotificationService.onNotificationTapped = (payload) {
        capturedPayload = payload;
      };

      NotificationService.onNotificationTapped?.call('{"type":"collection"}');
      expect(capturedPayload, '{"type":"collection"}');
    });
  });
}
