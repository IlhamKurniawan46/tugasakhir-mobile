import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/models/card_model.dart';
import '../../../core/services/pack_service.dart';

enum PackStage {
  sealed,    // Bungkus pack tertutup, menunggu guncangan atau tap
  shaking,   // Terdeteksi guncangan mendekati threshold
  opening,   // Animasi sobek bungkus pack
  revealing, // Tumpukan kartu, kartu di-reveal satu per satu
  completed, // Semua 5 kartu selesai di-reveal, ringkasan skor muncul
}

class PackState {
  final PackStage stage;
  final List<CardModel> cards;
  final int currentRevealIndex;
  final Set<int> revealedIndices;
  final double currentAcceleration;
  final double bestPullValueIdr;
  final bool isNewRecord;
  final String? selectedSetId;
  final bool isLoading;
  final String? errorMessage;

  const PackState({
    this.stage = PackStage.sealed,
    this.cards = const [],
    this.currentRevealIndex = 0,
    this.revealedIndices = const {},
    this.currentAcceleration = 0.0,
    this.bestPullValueIdr = 0.0,
    this.isNewRecord = false,
    this.selectedSetId,
    this.isLoading = false,
    this.errorMessage,
  });

  double get totalPullValueIdr => PackService.calculateTotalValueIdr(cards);

  CardModel? get chaseCard => cards.isNotEmpty ? cards.last : null;

  bool get isAllRevealed =>
      cards.isNotEmpty && revealedIndices.length >= cards.length;

  PackState copyWith({
    PackStage? stage,
    List<CardModel>? cards,
    int? currentRevealIndex,
    Set<int>? revealedIndices,
    double? currentAcceleration,
    double? bestPullValueIdr,
    bool? isNewRecord,
    String? selectedSetId,
    bool resetSetId = false,
    bool? isLoading,
    String? errorMessage,
  }) =>
      PackState(
        stage: stage ?? this.stage,
        cards: cards ?? this.cards,
        currentRevealIndex: currentRevealIndex ?? this.currentRevealIndex,
        revealedIndices: revealedIndices ?? this.revealedIndices,
        currentAcceleration: currentAcceleration ?? this.currentAcceleration,
        bestPullValueIdr: bestPullValueIdr ?? this.bestPullValueIdr,
        isNewRecord: isNewRecord ?? this.isNewRecord,
        selectedSetId:
            resetSetId ? null : (selectedSetId ?? this.selectedSetId),
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class PackNotifier extends StateNotifier<PackState> {
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSub;
  DateTime _lastShakeTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUiUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const double shakeThreshold = 15.0; // m/s²
  static const int shakeCooldownMs = 1200;

  PackNotifier() : super(const PackState()) {
    _loadBestPullValue();
    startListeningToSensors();
  }

  Future<void> _loadBestPullValue() async {
    final best = await PackService.getBestPullValueIdr();
    state = state.copyWith(bestPullValueIdr: best);
  }

  /// Memulai pendengaran sensor accelerometer untuk deteksi gestur guncangan (shake)
  void startListeningToSensors() {
    _accelerometerSub?.cancel();
    try {
      _accelerometerSub = userAccelerometerEventStream().listen(
        (event) {
          // Hanya dengarkan saat berada di tahap sealed
          if (state.stage != PackStage.sealed) return;

          // Hitung magnitude akselerasi netto
          final magnitude = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );

          // 1. Cek apakah mencapai ambang batas shake
          if (magnitude >= shakeThreshold) {
            final now = DateTime.now();
            if (now.difference(_lastShakeTime).inMilliseconds >=
                shakeCooldownMs) {
              _lastShakeTime = now;
              openPack();
              return;
            }
          }

          // 2. Throttle pembaruan UI meter (maksimal 10x per detik) agar tidak membebani rebuild widget tree
          final now = DateTime.now();
          if (now.difference(_lastUiUpdateTime).inMilliseconds >= 100) {
            _lastUiUpdateTime = now;
            state = state.copyWith(currentAcceleration: magnitude);
          }
        },
        onError: (e) {
          debugPrint('[HoloDex Pack Accelerometer Error] $e');
        },
      );
    } catch (e) {
      debugPrint('[HoloDex Pack] Sensor tidak tersedia di perangkat ini: $e');
    }
  }

  /// Berhenti mendengarkan sensor saat layar ditutup
  void stopListeningToSensors() {
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
  }

  /// Membuka booster pack (dipicu oleh guncangan HP atau tombol Buka Pack manual)
  Future<void> openPack() async {
    if (state.stage != PackStage.sealed && state.stage != PackStage.shaking) {
      return;
    }

    state = state.copyWith(
      stage: PackStage.opening,
      isLoading: true,
      errorMessage: null,
      isNewRecord: false,
    );

    try {
      final cards = await PackService.getRandomPackCards(
        setId: state.selectedSetId,
        count: 5,
      );

      // Beri jeda animasi buka bungkus (700ms)
      await Future.delayed(const Duration(milliseconds: 700));

      state = state.copyWith(
        stage: PackStage.revealing,
        cards: cards,
        currentRevealIndex: 0,
        revealedIndices: {0}, // Kartu pertama langsung terbuka
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        stage: PackStage.sealed,
        isLoading: false,
        errorMessage: 'Gagal membuka pack: $e',
      );
    }
  }

  /// Reveal kartu berikutnya satu per satu
  Future<void> revealNextCard() async {
    if (state.stage != PackStage.revealing) return;

    final nextIndex = state.currentRevealIndex + 1;
    if (nextIndex < state.cards.length) {
      final updatedRevealed = Set<int>.from(state.revealedIndices)..add(nextIndex);
      state = state.copyWith(
        currentRevealIndex: nextIndex,
        revealedIndices: updatedRevealed,
      );
    } else {
      // Semua kartu telah terbuka -> Selesai
      await finishPack();
    }
  }

  /// Buka semua kartu sekaligus (opsi Skip Reveal)
  Future<void> revealAllCards() async {
    if (state.cards.isEmpty) return;
    final allIndices = List.generate(state.cards.length, (i) => i).toSet();
    state = state.copyWith(
      revealedIndices: allIndices,
      currentRevealIndex: state.cards.length - 1,
    );
    await finishPack();
  }

  /// Menyelesaikan pembukaan pack dan mencatat rekor jika tembus rekor terbaik
  Future<void> finishPack() async {
    final totalVal = state.totalPullValueIdr;
    final isNewBest = await PackService.checkAndSaveBestPull(totalVal);
    final bestVal = isNewBest ? totalVal : state.bestPullValueIdr;

    state = state.copyWith(
      stage: PackStage.completed,
      bestPullValueIdr: bestVal,
      isNewRecord: isNewBest,
    );
  }

  /// Reset untuk membuka pack baru
  void resetPack() {
    state = state.copyWith(
      stage: PackStage.sealed,
      cards: const [],
      currentRevealIndex: 0,
      revealedIndices: const {},
      currentAcceleration: 0.0,
      isNewRecord: false,
      isLoading: false,
      errorMessage: null,
    );
  }

  /// Ganti pilihan set booster pack (misal Darkness Ablaze, Evolving Skies, dll.)
  void changeSet(String? setId) {
    if (state.selectedSetId == setId) return;
    if (setId == null) {
      state = state.copyWith(resetSetId: true);
    } else {
      state = state.copyWith(selectedSetId: setId);
    }
    resetPack();
  }

  @override
  void dispose() {
    stopListeningToSensors();
    super.dispose();
  }
}

final packProvider = StateNotifierProvider<PackNotifier, PackState>((ref) {
  return PackNotifier();
});
