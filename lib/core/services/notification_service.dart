import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/local_db.dart';
import '../models/card_model.dart';

/// Hasil penjadwalan notifikasi
enum NotificationScheduleResult {
  success,
  pastTime,
  error,
}

/// Service Notifikasi Mobile Lokal (Ketentuan Dosen #12)
/// Menggunakan flutter_local_notifications + timezone tanpa Firebase
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Callback navigasi saat notifikasi ditekan
  static void Function(String? payload)? onNotificationTapped;

  // Channel IDs
  static const String channelEvents = 'holodex_events';
  static const String channelMarketplace = 'holodex_marketplace';
  static const String channelAlerts = 'holodex_alerts';

  /// Inisialisasi plugin notifikasi, channel Android, dan timezone data
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Inisialisasi timezone database
      tz.initializeTimeZones();

      // 2. Pengaturan platform Android & iOS
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '[HoloDex Notifikasi] Notifikasi ditekan dengan payload: ${response.payload}',
          );
          onNotificationTapped?.call(response.payload);
        },
      );

      // 3. Daftarkan Notification Channels di Android
      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelEvents,
            'Pengingat Rilis Pokémon',
            description: 'Notifikasi jadwal peluncuran set kartu Pokémon baru',
            importance: Importance.high,
            playSound: true,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMarketplace,
            'Transaksi Pasar HoloDex',
            description: 'Status pembelian dan penjualan kartu fisik koleksi',
            importance: Importance.high,
            playSound: true,
          ),
        );

        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelAlerts,
            'Peringatan Harga Watchlist',
            description: 'Pemberitahuan saat kartu incaran mencapai target harga',
            importance: Importance.defaultImportance,
            playSound: true,
          ),
        );
      }

      _isInitialized = true;
      debugPrint('[HoloDex Notifikasi] NotificationService berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal inisialisasi: $e');
    }
  }

  /// Meminta izin notifikasi (wajib untuk Android 13+ / Tiramisu)
  Future<bool> requestPermission() async {
    try {
      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi] Error request permission: $e');
      return false;
    }
  }

  /// Menampilkan notifikasi instan langsung (misalnya saat beli kartu di pasar)
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelMarketplace,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == channelMarketplace
            ? 'Transaksi Pasar HoloDex'
            : 'Notifikasi HoloDex',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      debugPrint('[HoloDex Notifikasi] Instant notification ditampilkan: $title');
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal menampilkan instant notif: $e');
    }
  }


  /// Menjadwalkan pengingat rilis Pokémon pada tanggal dan waktu spesifik (zonedSchedule)
  Future<NotificationScheduleResult> scheduleEventNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String timeZoneName = 'Asia/Jakarta',
  }) async {
    try {
      final location = tz.getLocation(timeZoneName);
      final tzScheduled = tz.TZDateTime.from(scheduledDate, location);

      // Jangan jadwalkan jika waktu target sudah berlalu
      if (tzScheduled.isBefore(tz.TZDateTime.now(location))) {
        debugPrint(
          '[HoloDex Notifikasi] Waktu target sudah berlalu: $tzScheduled',
        );
        return NotificationScheduleResult.pastTime;
      }

      const androidDetails = AndroidNotificationDetails(
        channelEvents,
        'Pengingat Rilis Pokémon',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (alarmError) {
        debugPrint(
          '[HoloDex Notifikasi] exactAllowWhileIdle ditolak ($alarmError), fallback ke inexact...',
        );
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: payload,
        );
      }

      debugPrint(
        '[HoloDex Notifikasi] Pengingat rilis dijadwalkan pada: $tzScheduled (ID: $id)',
      );
      return NotificationScheduleResult.success;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal jadwalkan notifikasi: $e');
      return NotificationScheduleResult.error;
    }
  }

  /// Menjadwalkan pengingat simulasi / demo (misal: 5-10 detik dari sekarang)
  Future<void> scheduleDemoReminder({
    required int id,
    required String title,
    required String body,
    int delaySeconds = 5,
    String? payload,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduled = now.add(Duration(seconds: delaySeconds));

      const androidDetails = AndroidNotificationDetails(
        channelEvents,
        'Pengingat Rilis Pokémon',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (alarmError) {
        debugPrint(
          '[HoloDex Notifikasi] exact alarm ditolak ($alarmError), gunakan timer fallback...',
        );
        Future.delayed(Duration(seconds: delaySeconds), () {
          showInstantNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
            channelId: channelEvents,
          );
        });
      }
      debugPrint(
        '[HoloDex Notifikasi] Simulasi pengingat dijadwalkan $delaySeconds detik lagi.',
      );
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal simulasi: $e');
    }
  }

  /// Membatalkan notifikasi terjadwal
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
    debugPrint('[HoloDex Notifikasi] Notifikasi id: $id dibatalkan.');
  }

  /// Memeriksa daftar notifikasi yang masih pending
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  /// Cek Price Alert Watchlist: memicu notifikasi jika harga live mencapai target
  Future<int> checkWatchlistPriceAlerts({
    required List<CardModel> catalogCards,
  }) async {
    try {
      final db = await LocalDb.instance;
      final watchlistRows = await db.query('watchlist');
      int triggeredCount = 0;

      final cardMap = {for (var c in catalogCards) c.id: c};

      for (var row in watchlistRows) {
        final cardId = row['card_id'] as String;
        final targetPrice = (row['target_price'] as num?)?.toDouble();

        if (targetPrice == null || targetPrice <= 0) continue;

        final card = cardMap[cardId];
        if (card != null && card.priceIdr != null) {
          final livePrice = card.priceIdr!;
          // Target tercapai jika harga live <= target harga pembeli
          if (livePrice <= targetPrice) {
            triggeredCount++;
            final notifId = cardId.hashCode.abs();
            await showInstantNotification(
              id: notifId,
              title: '🎯 Target Harga Tercapai: ${card.name}!',
              body: 'Harga pasar turun ke Rp${livePrice.round()} '
                  '(Target Anda: Rp${targetPrice.round()}). Ketuk untuk lihat kartu.',
              channelId: channelAlerts,
              payload: jsonEncode({
                'type': 'card_detail',
                'cardId': cardId,
              }),
            );
          }
        }
      }
      return triggeredCount;
    } catch (e) {
      debugPrint('[HoloDex Notifikasi Error] Gagal check watchlist alert: $e');
      return 0;
    }
  }
}
