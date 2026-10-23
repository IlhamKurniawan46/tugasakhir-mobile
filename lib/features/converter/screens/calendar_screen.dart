import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/release_event_model.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/timezone_service.dart';
import '../providers/calendar_provider.dart';

/// Halaman Kalender & Jadwal Event Pokémon TCG
/// Dilengkapi Hero Countdown live, Jam Digital 4 Zona Waktu (WIB/WITA/WIT/London dengan DST otomatis),
/// dan Kalkulator Konversi Jam Rilis Interaktif.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    ClockTicker.start();
  }

  @override
  void dispose() {
    ClockTicker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final nearestEvent = state.nearestUpcomingEvent;

    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLow,
        elevation: 0,
        title: const Text(
          'Kalender Event',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Event',
            icon: const Icon(Icons.refresh, color: AppColors.outline),
            onPressed: () => ref.read(calendarProvider.notifier).loadEvents(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(calendarProvider.notifier).loadEvents(),
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Hero Countdown Card (Event Mendatang Terdekat)
            if (nearestEvent != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _HeroCountdownCard(event: nearestEvent),
                ),
              ),

            // 2. World Clock Strip 4 Zona (WIB, WITA, WIT, London DST) - Grid 2x2
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _WorldClockSection(),
              ),
            ),

            // 3. Tombol Cepat Buka Kalkulator Selisih Jam
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  onTap: () => _showTimeConverterSheet(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceHigh),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.access_time_filled, color: AppColors.gold, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kalkulator Selisih Waktu 4 Zona',
                                style: TextStyle(
                                  color: AppColors.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Konversi jam antar WIB, WITA, WIT, dan London',
                                style: TextStyle(
                                  color: AppColors.outline,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Header Filter Kategori Event (Bebas overflow, scrollable horizontal)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timeline Agenda',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: EventFilter.values.map((filter) {
                          final isSelected = state.filter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(
                                filter == EventFilter.all
                                    ? 'Semua Event'
                                    : (filter == EventFilter.setRelease
                                        ? 'Rilis Set'
                                        : 'Turnamen'),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                ref.read(calendarProvider.notifier).setFilter(filter);
                              },
                              selectedColor: AppColors.gold,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.onGold
                                    : AppColors.onSurfaceVariant,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Daftar Event
            if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (state.filteredEvents.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Tidak ada event untuk filter ini',
                    style: TextStyle(color: AppColors.outline),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = state.filteredEvents[index];
                      return _EventCard(event: event);
                    },
                    childCount: state.filteredEvents.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTimeConverterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _TimeConverterSheetContent(),
    );
  }
}

String _getHeroLabel(ReleaseEventModel event) {
  switch (event.eventType) {
    case 'set_release':
      return 'RILIS BERIKUTNYA';
    case 'tournament':
      return 'TURNAMEN BERIKUTNYA';
    case 'auction':
      return 'LELANG BERIKUTNYA';
    case 'meetup':
      return 'KOPDAR BERIKUTNYA';
    default:
      return 'EVENT BERIKUTNYA';
  }
}

/// Widget Hero Countdown untuk event mendatang terdekat
class _HeroCountdownCard extends StatelessWidget {
  final ReleaseEventModel event;

  const _HeroCountdownCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceHigh.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: event.isSetRelease
                      ? AppColors.gold.withValues(alpha: 0.2)
                      : AppColors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      event.isSetRelease ? Icons.style : Icons.emoji_events,
                      size: 13,
                      color: event.isSetRelease ? AppColors.gold : AppColors.cyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getHeroLabel(event),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: event.isSetRelease ? AppColors.gold : AppColors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
              if (event.location != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 12, color: AppColors.outline),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          event.location!,
                          style: const TextStyle(fontSize: 11, color: AppColors.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          if (event.description != null) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),

          // Countdown Blocks live terisolasi
          ValueListenableBuilder<DateTime>(
            valueListenable: ClockTicker.liveTimeNotifier,
            builder: (context, _, child) {
              final countdown = TimezoneService.calculateCountdown(event.eventDate);
              final isPast = countdown['isPast'] == 1;

              if (isPast) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Event Sedang / Telah Berlangsung',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _CountdownBox(
                      label: 'HARI',
                      value: countdown['days'] ?? 0,
                    ),
                  ),
                  _CountdownColon(),
                  Expanded(
                    child: _CountdownBox(
                      label: 'JAM',
                      value: countdown['hours'] ?? 0,
                    ),
                  ),
                  _CountdownColon(),
                  Expanded(
                    child: _CountdownBox(
                      label: 'MENIT',
                      value: countdown['minutes'] ?? 0,
                    ),
                  ),
                  _CountdownColon(),
                  Expanded(
                    child: _CountdownBox(
                      label: 'DETIK',
                      value: countdown['seconds'] ?? 0,
                      isHighlighted: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.gold),
              label: const Text(
                'Pasang Pengingat Notifikasi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _showEventReminderSheet(context, event),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBox extends StatelessWidget {
  final String label;
  final int value;
  final bool isHighlighted;

  const _CountdownBox({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? AppColors.gold.withValues(alpha:0.6) : AppColors.surfaceHigh,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isHighlighted ? AppColors.gold : AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isHighlighted ? AppColors.gold : AppColors.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownColon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.outline,
        ),
      ),
    );
  }
}

/// Widget World Clock Strip menampilkan jam 4 zona waktu live dalam Grid 2x2 sama besar
class _WorldClockSection extends StatelessWidget {
  const _WorldClockSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.public, color: AppColors.gold, size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Jam Digital 4 Zona Waktu (Live)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<DateTime>(
          valueListenable: ClockTicker.liveTimeNotifier,
          builder: (context, now, _) {
            final zones = TimezoneService.getAllZonesInfo(now);

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ZoneClockCard(
                        zone: AppTimeZone.wib,
                        info: zones[AppTimeZone.wib]!,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ZoneClockCard(
                        zone: AppTimeZone.wita,
                        info: zones[AppTimeZone.wita]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ZoneClockCard(
                        zone: AppTimeZone.wit,
                        info: zones[AppTimeZone.wit]!,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ZoneClockCard(
                        zone: AppTimeZone.london,
                        info: zones[AppTimeZone.london]!,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Kotak individual jam zona waktu dengan FittedBox dan tabular figures
class _ZoneClockCard extends StatelessWidget {
  final AppTimeZone zone;
  final ZoneTimeInfo info;

  const _ZoneClockCard({
    required this.zone,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final isLondon = zone == AppTimeZone.london;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLondon
              ? AppColors.cyan.withValues(alpha: 0.3)
              : AppColors.surfaceHigh,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(zone.flag, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                zone.code,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isLondon ? AppColors.cyan : AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  info.offsetLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.outline,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              info.timeFormatted, // HH:mm:ss
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isLondon ? AppColors.cyan : AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget Card Event individual di Timeline (Tombol notifikasi disembunyikan sampai Sesi 14)
class _EventCard extends StatelessWidget {
  final ReleaseEventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final countdown = TimezoneService.calculateCountdown(event.eventDate);
    final isPast = countdown['isPast'] == 1;
    final eventZones = TimezoneService.getAllZonesInfo(event.eventDate);

    final wib = eventZones[AppTimeZone.wib]!;
    final ldn = eventZones[AppTimeZone.london]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: event.isSetRelease
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  event.isSetRelease ? Icons.style : Icons.emoji_events,
                  color: event.isSetRelease ? AppColors.gold : AppColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (event.location != null)
                      Text(
                        event.location!,
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPast
                      ? AppColors.surfaceHigh
                      : AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPast
                      ? 'Selesai'
                      : (countdown['days']! > 0
                          ? '${countdown['days']} hari lagi'
                          : '${countdown['hours']} jam lagi'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPast ? AppColors.outline : AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          if (event.description != null) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'WIB: ${wib.dateFormatted}, ${wib.timeFormatted.substring(0, 5)} • London: ${ldn.timeFormatted.substring(0, 5)} ${ldn.isDst ? 'BST' : 'GMT'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isPast) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.notifications_none, size: 16, color: AppColors.gold),
                  label: const Text(
                    'Ingatkan Saya',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                  onPressed: () => _showEventReminderSheet(context, event),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

void _showEventReminderSheet(BuildContext context, ReleaseEventModel event) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notification_add, color: AppColors.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengingat Rilis Pokémon',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih opsi notifikasi jadwal rilis kartu untuk acara ini:',
              style: TextStyle(fontSize: 12, color: AppColors.outline),
            ),
            const SizedBox(height: 12),

            // Opsi 1: Jadwal 1 Hari Sebelum Rilis
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Icon(Icons.calendar_today, color: AppColors.gold, size: 18),
              ),
              title: const Text(
                'Jadwalkan Pengingat Rilis',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Notifikasi otomatis menjelang tanggal rilis resmi',
                style: TextStyle(fontSize: 11, color: AppColors.outline),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!context.mounted) return;
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Izin notifikasi belum diaktifkan di setelan HP.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final now = DateTime.now();
                if (!event.eventDate.isAfter(now)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event ini sudah lewat. Pengingat hanya untuk event mendatang.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final oneDayBefore =
                    event.eventDate.subtract(const Duration(days: 1));
                final targetDate = oneDayBefore.isAfter(now)
                    ? oneDayBefore
                    : event.eventDate;

                final result =
                    await NotificationService.instance.scheduleEventNotification(
                  id: event.id.hashCode.abs(),
                  title: '🔔 Pengingat Rilis Pokémon!',
                  body:
                      'Event "${event.title}" akan berlangsung! Jangan lewatkan rilis resminya.',
                  scheduledDate: targetDate,
                );

                if (context.mounted) {
                  final String message;
                  final Color bgColor;
                  switch (result) {
                    case NotificationScheduleResult.success:
                      message = 'Pengingat rilis berhasil dijadwalkan!';
                      bgColor = AppColors.success;
                      break;
                    case NotificationScheduleResult.pastTime:
                      message = 'Waktu rilis event sudah lewat.';
                      bgColor = AppColors.error;
                      break;
                    case NotificationScheduleResult.error:
                      message = 'Gagal memasang pengingat sistem. Silakan coba opsi Tes Notifikasi 5 Detik.';
                      bgColor = AppColors.error;
                      break;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: bgColor,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            const Divider(color: AppColors.surfaceHigh, height: 16),

            // Opsi 2: Simulasi Cepat (5 Detik) untuk Demo Dosen
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Icon(Icons.flash_on, color: AppColors.cyan, size: 18),
              ),
              title: const Text(
                'Tes Notifikasi Sekarang (Simulasi 5 Detik)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Notifikasi akan muncul 5 detik lagi',
                style: TextStyle(fontSize: 11, color: AppColors.outline),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!context.mounted) return;
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Izin notifikasi belum diaktifkan di setelan HP.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                await NotificationService.instance.scheduleDemoReminder(
                  id: event.id.hashCode.abs(),
                  title: '🔔 Pengingat Rilis: ${event.title}',
                  body:
                      'Set kartu baru resmi dirilis hari ini! Segera cek katalog dan harga pasarnya.',
                  delaySeconds: 5,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Simulasi dimulai! Notifikasi akan muncul dalam 5 detik.',
                      ),
                      backgroundColor: AppColors.surfaceHighest,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),

            const Divider(color: AppColors.surfaceHigh, height: 16),

            // Opsi 3: Batalkan Notifikasi
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Icon(
                  Icons.notifications_off_outlined,
                  color: AppColors.error,
                  size: 18,
                ),
              ),
              title: const Text(
                'Batalkan Pengingat Event Ini',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              subtitle: const Text(
                'Hapus jadwal pengingat untuk event ini',
                style: TextStyle(fontSize: 11, color: AppColors.outline),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await NotificationService.instance
                    .cancelNotification(event.id.hashCode.abs());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengingat event dibatalkan.'),
                      backgroundColor: AppColors.surfaceHighest,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  },
  );
}

/// Modal Bottom Sheet untuk Kalkulator Selisih Jam Antar Zona
class _TimeConverterSheetContent extends ConsumerStatefulWidget {
  const _TimeConverterSheetContent();

  @override
  ConsumerState<_TimeConverterSheetContent> createState() =>
      _TimeConverterSheetContentState();
}

class _TimeConverterSheetContentState extends ConsumerState<_TimeConverterSheetContent> {
  late TimeOfDay _selectedTime;
  late AppTimeZone _selectedZone;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    _selectedZone = AppTimeZone.london;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final targetDate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final convertedZones = TimezoneService.getAllZonesInfo(targetDate, _selectedZone);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Kalkulator Selisih Waktu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.outline),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih zona asal dan jam rilis untuk melihat waktu ekuivalennya di seluruh zona:',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
          const SizedBox(height: 14),

          // Selector Zona Asal
          const Text(
            'Zona Waktu Asal:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: AppTimeZone.values.map((zone) {
              final isSelected = _selectedZone == zone;
              return ChoiceChip(
                label: Text('${zone.flag} ${zone.code}'),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedZone = zone;
                  });
                },
                selectedColor: AppColors.gold,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.onGold : AppColors.onSurface,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.gold : AppColors.surfaceHigh,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Picker Jam
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.gold,
                        onPrimary: AppColors.onGold,
                        surface: AppColors.surface,
                        onSurface: AppColors.onSurface,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedTime = picked;
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha:0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm, color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Pukul ${_selectedTime.format(context)} (${_selectedZone.code})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Ubah Jam',
                    style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hasil Konversi ke 4 Zona
          const Text(
            'Waktu Ekuivalen di Tiap Zona:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          const SizedBox(height: 8),
          ...AppTimeZone.values.map((zone) {
            final info = convertedZones[zone]!;
            final isOrigin = zone == _selectedZone;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOrigin ? AppColors.gold.withValues(alpha:0.12) : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOrigin ? AppColors.gold : AppColors.surfaceHigh,
                ),
              ),
              child: Row(
                children: [
                  Text(zone.flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${zone.name} (${zone.code})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isOrigin ? AppColors.gold : AppColors.onSurface,
                          ),
                        ),
                        Text(
                          info.offsetLabel,
                          style: const TextStyle(fontSize: 10, color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    info.timeFormatted.substring(0, 5), // HH:mm
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: isOrigin ? AppColors.gold : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
