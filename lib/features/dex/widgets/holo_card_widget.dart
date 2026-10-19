import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../app/theme.dart';

/// Kartu dengan efek holo 3D yang mengikuti gerakan HP (gyroscope).
///
/// Cara kerja:
/// - Gyroscope memberikan kecepatan putar (rad/s). Sudut kemiringan
///   didapat dengan mengintegrasikan kecepatan (ω × dt).
/// - Integrasi diberi peluruhan eksponensial (decay τ = 0.7s) sehingga saat HP
///   diletakkan datar di atas meja, kartu otomatis kembali tegak ke tengah.
/// - Sudut di-clamp presisi ±15° agar kartu tidak terbalik.
/// - Jika gyroscope tidak tersedia (emulator/HP tanpa gyro), pengguna
///   dapat menggeser kartu dengan jari (pan gesture fallback).
class HoloCardWidget extends StatefulWidget {
  final String? cardId;
  final String? imageUrl;
  final String? placeholderUrl;
  final String? rarity;
  final bool? isHolo;

  /// 0..1 — seberapa kuat kilau holo. Lihat [intensityForRarity].
  final double intensity;

  /// Dipanggil setelah status sensor diketahui.
  final ValueChanged<bool>? onSensorAvailabilityChanged;

  const HoloCardWidget({
    super.key,
    this.cardId,
    required this.imageUrl,
    this.placeholderUrl,
    this.rarity,
    this.isHolo,
    this.intensity = 1.0,
    this.onSensorAvailabilityChanged,
  });

  static const double maxTiltDeg = 15;

  /// Menentukan apakah kartu dengan [rarity] tertentu memiliki efek holografis.
  /// Kartu kategori 'common', 'uncommon', dan 'rare' (biasa) bukan kartu holo.
  static bool isHoloRarity(String? rarity) {
    if (rarity == null) return false;
    final r = rarity.trim().toLowerCase();
    if (r.isEmpty) return false;
    if (r == 'common' || r == 'uncommon' || r == 'rare') {
      return false;
    }
    return true;
  }

  /// Intensitas kilau berdasarkan kelangkaan (rarity) kartu jika kartu holo.
  static double intensityForRarity(String? rarity) {
    if (!isHoloRarity(rarity)) return 0.0;
    final r = (rarity ?? '').trim().toLowerCase();
    if (r.contains('secret') ||
        r.contains('hyper') ||
        r.contains('special') ||
        r.contains('illustration') ||
        r.contains('ultra')) {
      return 1.0;
    }
    return 0.85;
  }

  @override
  State<HoloCardWidget> createState() => _HoloCardWidgetState();
}

class _HoloCardWidgetState extends State<HoloCardWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _maxTilt = HoloCardWidget.maxTiltDeg;
  static const double _decayTau = 0.7;
  static const double _gyroDeadzone = 0.03;
  static const double _gyroGain = 1.6;
  static const double _radToDeg = 180 / math.pi;

  // Rasio fisik kartu Pokémon (63mm x 88mm = ~0.7159)
  static const double _cardAspect = 63.0 / 88.0;
  static const double _cardWidth = 280.0;
  static const double _cardHeight = _cardWidth / _cardAspect;

  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  final Stopwatch _gyroClock = Stopwatch();
  Timer? _sensorProbeTimer;
  bool? _sensorAvailable;
  bool _dragging = false;

  late final AnimationController _resetController;
  Animation<Offset>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        final anim = _resetAnimation;
        if (anim != null) _tilt.value = anim.value;
      });
    _startGyro();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopGyro();
    _sensorProbeTimer?.cancel();
    _resetController.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startGyro();
    } else if (state == AppLifecycleState.paused) {
      _stopGyro();
    }
  }

  void _startGyro() {
    if (_gyroSub != null) return;
    _gyroClock
      ..reset()
      ..start();

    // Fallback timer: jika dalam 1.5 detik tidak ada event, sensor dianggap offline
    _sensorProbeTimer ??= Timer(const Duration(milliseconds: 1500), () {
      if (_sensorAvailable == null) _reportSensor(false);
    });

    runZonedGuarded(() {
      try {
        _gyroSub = gyroscopeEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          _onGyro,
          onError: (Object e) {
            debugPrint('[HoloDex Warning] Gyroscope stream error: $e');
            _reportSensor(false);
            _stopGyro();
          },
          cancelOnError: true,
        );
      } on MissingPluginException catch (e) {
        debugPrint('[HoloDex Warning] Plugin sensor belum ter-link di build APK: $e');
        _reportSensor(false);
        _stopGyro();
      } on PlatformException catch (e) {
        debugPrint('[HoloDex Warning] Sensor platform exception: $e');
        _reportSensor(false);
        _stopGyro();
      } catch (e) {
        debugPrint('[HoloDex Warning] Gagal inisialisasi gyroscope: $e');
        _reportSensor(false);
        _stopGyro();
      }
    }, (error, stack) {
      // Tangkap unhandled exception dari method channel sensors_plus (misal MissingPluginException async)
      debugPrint('[HoloDex Warning] Asynchronous sensor error tertangkap: $error');
      _reportSensor(false);
      _stopGyro();
    });
  }

  void _stopGyro() {
    _gyroSub?.cancel();
    _gyroSub = null;
    _gyroClock.stop();
  }

  void _reportSensor(bool available) {
    if (_sensorAvailable == available) return;
    _sensorAvailable = available;

    // PENTING: Gunakan addPostFrameCallback agar tidak memanggil setState saat build berlangsung
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSensorAvailabilityChanged?.call(available);
      }
    });
  }

  void _onGyro(GyroscopeEvent e) {
    if (_sensorAvailable != true) _reportSensor(true);

    final dt = (_gyroClock.elapsedMicroseconds / 1e6).clamp(0.0, 0.05);
    _gyroClock
      ..reset()
      ..start();

    if (_dragging || _resetController.isAnimating || dt == 0) return;

    final wx = e.x.abs() < _gyroDeadzone ? 0.0 : e.x;
    final wy = e.y.abs() < _gyroDeadzone ? 0.0 : e.y;

    final decay = math.exp(-dt / _decayTau);
    final current = _tilt.value;

    final nextX = (current.dy * decay + wx * dt * _radToDeg * _gyroGain)
        .clamp(-_maxTilt, _maxTilt);
    final nextY = (current.dx * decay + wy * dt * _radToDeg * _gyroGain)
        .clamp(-_maxTilt, _maxTilt);

    _tilt.value = Offset(nextY, nextX);
  }

  void _onPanStart(DragStartDetails _) {
    _dragging = true;
    _resetController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final nx =
        ((details.localPosition.dx / _cardWidth) * 2 - 1).clamp(-1.0, 1.0);
    final ny =
        ((details.localPosition.dy / _cardHeight) * 2 - 1).clamp(-1.0, 1.0);
    _tilt.value = Offset(nx * _maxTilt, -ny * _maxTilt);
  }

  void _onPanEnd([DragEndDetails? _]) {
    _dragging = false;
    _resetAnimation = Tween<Offset>(begin: _tilt.value, end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutBack,
    ));
    _resetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: _cardWidth,
        height: _cardHeight,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanEnd,
          child: ValueListenableBuilder<Offset>(
            valueListenable: _tilt,
            child: _buildCardFace(),
            builder: (context, tilt, cardFace) =>
                _buildTransformed(tilt, cardFace!),
          ),
        ),
      ),
    );
  }

  bool get _isHolo =>
      widget.isHolo ?? HoloCardWidget.isHoloRarity(widget.rarity);

  Widget _buildTransformed(Offset tilt, Widget cardFace) {
    final nx = tilt.dx / _maxTilt;
    final ny = -tilt.dy / _maxTilt;
    final isHolo = _isHolo;
    final strength = isHolo ? widget.intensity.clamp(0.0, 1.0) : 0.0;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(tilt.dy * math.pi / 180)
      ..rotateY(tilt.dx * math.pi / 180);

    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: Container(
        width: _cardWidth,
        height: _cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            // Bayangan 3D realistis yang bergeser mengikuti sudut kemiringan
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.75),
              blurRadius: 30,
              offset: Offset(-nx * 12, 16 - ny * 10),
            ),
            // Pendar ambient halus khusus untuk kartu holo
            if (isHolo)
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.22 * strength),
                blurRadius: 26,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cardFace,
              if (isHolo) ...[
                // Pita pelangi iridescent foil
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.overlay,
                        gradient: LinearGradient(
                          begin: Alignment(-1.4 + nx * 0.9, -1.4 + ny * 0.9),
                          end: Alignment(1.4 + nx * 0.9, 1.4 + ny * 0.9),
                          stops: const [0.2, 0.38, 0.5, 0.62, 0.8],
                          colors: [
                            Colors.transparent,
                            AppColors.cyan.withValues(alpha: 0.55 * strength),
                            AppColors.gold.withValues(alpha: 0.6 * strength),
                            const Color(0xFFFF4FA0)
                                .withValues(alpha: 0.5 * strength),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Titik kilau pantulan cahaya (specular glare holo)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.screen,
                        gradient: RadialGradient(
                          center: Alignment(nx * 0.9, ny * 0.9),
                          radius: 0.75,
                          colors: [
                            Colors.white.withValues(alpha: 0.28 * strength),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Non-holo: Kilau cahaya soft light putih halus yang bergerak saat kartu dimiringkan
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.softLight,
                        gradient: LinearGradient(
                          begin: Alignment(-1.5 + nx * 1.1, -1.5 + ny * 1.1),
                          end: Alignment(1.5 + nx * 1.1, 1.5 + ny * 1.1),
                          stops: const [0.2, 0.5, 0.8],
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.30),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Pantulan specular diffused lembut (soft white light glare)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.softLight,
                        gradient: RadialGradient(
                          center: Alignment(nx * 0.85, ny * 0.85),
                          radius: 0.85,
                          colors: [
                            Colors.white.withValues(alpha: 0.40),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace() {
    final url = widget.imageUrl;
    final placeholderUrl = widget.placeholderUrl;

    Widget fallback(IconData icon) => Container(
          color: AppColors.surfaceLow,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.outline, size: 40),
        );

    final Widget imageWidget = url == null
        ? fallback(Icons.style_outlined)
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => placeholderUrl == null
                ? fallback(Icons.hourglass_empty)
                : CachedNetworkImage(
                    imageUrl: placeholderUrl,
                    fit: BoxFit.contain,
                  ),
            errorWidget: (_, _, _) => placeholderUrl == null
                ? fallback(Icons.broken_image_outlined)
                : CachedNetworkImage(
                    imageUrl: placeholderUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, _, _) =>
                        fallback(Icons.broken_image_outlined),
                  ),
          );

    return ColoredBox(
      color: Colors.transparent,
      child: imageWidget,
    );
  }
}
