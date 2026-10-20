import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/models/release_event_model.dart';
import '../../../core/services/timezone_service.dart';

/// Filter tipe event yang ditampilkan di kalender
enum EventFilter {
  all(label: 'Semua Event'),
  setRelease(label: 'Rilis Set (Pack)'),
  tournament(label: 'Turnamen Resmi');

  final String label;
  const EventFilter({required this.label});
}

/// Ticker waktu live terisolasi untuk kartu jam & countdown
/// Memperbarui ValueNotifier setiap detik sehingga TIDAK me-rebuild seluruh layar
class ClockTicker {
  static final ValueNotifier<DateTime> liveTimeNotifier =
      ValueNotifier<DateTime>(DateTime.now());
  static Timer? _timer;
  static int _refCount = 0;

  static void start() {
    _refCount++;
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        liveTimeNotifier.value = DateTime.now();
      });
    }
  }

  static void stop() {
    _refCount--;
    if (_refCount <= 0) {
      _timer?.cancel();
      _timer = null;
      _refCount = 0;
    }
  }
}

/// State untuk halaman kalender
class CalendarState {
  final List<ReleaseEventModel> allEvents;
  final EventFilter filter;
  final bool isLoading;
  final String? errorMessage;
  final AppTimeZone calculatorSourceZone;
  final DateTime calculatorSourceTime;

  const CalendarState({
    required this.allEvents,
    this.filter = EventFilter.all,
    this.isLoading = false,
    this.errorMessage,
    this.calculatorSourceZone = AppTimeZone.london,
    required this.calculatorSourceTime,
  });

  /// Daftar event yang sudah difilter dan diurutkan
  List<ReleaseEventModel> get filteredEvents {
    var list = allEvents;
    if (filter == EventFilter.setRelease) {
      list = list.where((e) => e.isSetRelease).toList();
    } else if (filter == EventFilter.tournament) {
      list = list.where((e) => e.isTournament).toList();
    }
    final now = DateTime.now().toUtc();
    final upcoming = list.where((e) => e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final past = list.where((e) => !e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return [...upcoming, ...past];
  }

  /// Event mendatang paling dekat untuk ditampilkan di Hero Countdown
  ReleaseEventModel? get nearestUpcomingEvent {
    final now = DateTime.now().toUtc();
    final upcoming = allEvents.where((e) => e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    if (upcoming.isNotEmpty) {
      return upcoming.first;
    }
    return allEvents.isNotEmpty ? allEvents.first : null;
  }

  /// Hasil kalkulator konversi waktu dari zona yang dipilih
  Map<AppTimeZone, ZoneTimeInfo> get calculatedZonesInfo {
    return TimezoneService.getAllZonesInfo(calculatorSourceTime, calculatorSourceZone);
  }

  CalendarState copyWith({
    List<ReleaseEventModel>? allEvents,
    EventFilter? filter,
    bool? isLoading,
    String? errorMessage,
    AppTimeZone? calculatorSourceZone,
    DateTime? calculatorSourceTime,
  }) {
    return CalendarState(
      allEvents: allEvents ?? this.allEvents,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      calculatorSourceZone: calculatorSourceZone ?? this.calculatorSourceZone,
      calculatorSourceTime: calculatorSourceTime ?? this.calculatorSourceTime,
    );
  }
}

/// Notifier pengelola data kalender (hanya berubah saat fetch/filter/kalkulator, BUKAN tiap detik)
class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(
          CalendarState(
            allEvents: ReleaseEventModel.defaultEvents,
            calculatorSourceTime: DateTime.now(),
          ),
        ) {
    TimezoneService.ensureInitialized();
    loadEvents();
  }

  /// Muat daftar event dari Supabase (dengan fallback default events)
  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (!SupabaseService.isInitialized) {
        state = state.copyWith(
          allEvents: ReleaseEventModel.defaultEvents,
          isLoading: false,
        );
        return;
      }

      final response = await SupabaseService.client
          .from('release_events')
          .select()
          .order('event_date', ascending: true);

      final list = (response as List)
          .map((item) => ReleaseEventModel.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        allEvents: list.isNotEmpty ? list : ReleaseEventModel.defaultEvents,
        isLoading: false,
      );
    } catch (e) {
      // Offline fallback: tetap gunakan default events agar UI tidak pernah kosong
      state = state.copyWith(
        allEvents: ReleaseEventModel.defaultEvents,
        isLoading: false,
      );
    }
  }

  /// Ganti filter tipe event (Semua, Rilis Set, Turnamen)
  void setFilter(EventFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Atur zona acuan kalkulator
  void setCalculatorSourceZone(AppTimeZone zone) {
    state = state.copyWith(calculatorSourceZone: zone);
  }

  /// Atur jam acuan kalkulator
  void setCalculatorSourceTime(DateTime time) {
    state = state.copyWith(calculatorSourceTime: time);
  }
}

/// Provider global untuk Calendar
final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});
