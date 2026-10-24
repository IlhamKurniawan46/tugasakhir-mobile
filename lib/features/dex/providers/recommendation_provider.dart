import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/database/local_db.dart';
import '../../../core/models/card_model.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/services/interaction_service.dart';
import '../../../core/services/recommendation_engine.dart';
import '../../../core/services/session_service.dart';
import '../../auth/providers/auth_provider.dart';

/// State untuk bagian rekomendasi personal di layar Dex
class RecommendationState {
  final List<RecommendedCard> items;
  final UserInterestProfile? profile;
  final int interactionCount;
  final bool isLoading;
  final bool isColdStart;
  final String? errorMessage;
  final String? userId;

  const RecommendationState({
    this.items = const [],
    this.profile,
    this.interactionCount = 0,
    this.isLoading = false,
    this.isColdStart = true,
    this.errorMessage,
    this.userId,
  });

  RecommendationState copyWith({
    List<RecommendedCard>? items,
    UserInterestProfile? profile,
    int? interactionCount,
    bool? isLoading,
    bool? isColdStart,
    String? errorMessage,
    String? userId,
  }) =>
      RecommendationState(
        items: items ?? this.items,
        profile: profile ?? this.profile,
        interactionCount: interactionCount ?? this.interactionCount,
        isLoading: isLoading ?? this.isLoading,
        isColdStart: isColdStart ?? this.isColdStart,
        errorMessage: errorMessage,
        userId: userId ?? this.userId,
      );
}

/// Notifier Riverpod untuk menghitung dan memperbarui rekomendasi personal pengguna
class RecommendationNotifier extends StateNotifier<RecommendationState> {
  final Ref? ref;

  RecommendationNotifier([this.ref]) : super(const RecommendationState()) {
    // Dengarkan perubahan event interaksi secara realtime
    InteractionService.instance.interactionEpoch.addListener(_onInteractionChanged);

    // Dengarkan pergantian user dari authProvider (login, logout, ganti akun)
    ref?.listen<AuthState>(authProvider, (previous, next) {
      final prevUserId = previous?.user?.id;
      final nextUserId = next.user?.id;
      if (prevUserId != nextUserId) {
        debugPrint('[HoloDex AI] Pergantian akun terdeteksi ($prevUserId -> $nextUserId). Mereset rekomendasi.');
        resetForUser(nextUserId);
      }
    });

    loadRecommendations();
  }

  void _onInteractionChanged() {
    loadRecommendations();
  }

  /// Reset state dan hitung ulang rekomendasi saat pengguna berganti akun
  Future<void> resetForUser(String? newUserId) async {
    state = RecommendationState(
      items: const [],
      profile: null,
      interactionCount: 0,
      isLoading: true,
      isColdStart: true,
      userId: newUserId,
    );
    await loadRecommendations(force: true);
  }

  @override
  void dispose() {
    InteractionService.instance.interactionEpoch.removeListener(_onInteractionChanged);
    super.dispose();
  }

  /// Menghitung ulang daftar rekomendasi dari riwayat interaksi lokal
  Future<void> loadRecommendations({bool force = false}) async {
    final activeUserId = await SessionService.getActiveUserId();

    // Jika dipaksa atau user berganti, kosongkan state lama
    if (force) {
      state = state.copyWith(
        items: const [],
        profile: null,
        interactionCount: 0,
        isLoading: true,
        userId: activeUserId,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        isLoading: state.items.isEmpty,
        userId: activeUserId,
        errorMessage: null,
      );
    }

    try {
      final db = await LocalDb.instance;

      // 1. Ambil katalog dari database lokal
      final cardRows = await db.query(
        'cards',
        where: 'has_price = 1 AND image_url IS NOT NULL',
        orderBy: 'price_ref_usd DESC',
      );

      final catalog = cardRows.map((r) => CardModel.fromMap(r)).toList();
      if (catalog.isEmpty) {
        state = state.copyWith(isLoading: false, items: []);
        return;
      }

      final cardMap = {for (final c in catalog) c.id: c};

      // 2. Ambil ID kartu yang ada di Binder (Koleksi Saya) & Watchlist
      final binderCardIds = <String>{};
      final watchlistCardIds = <String>{};
      final recentViewedCardIds = <String>{};

      if (activeUserId != null && activeUserId.isNotEmpty) {
        final collectionItems =
            await CollectionRepository.getCollectionCards(activeUserId);
        binderCardIds.addAll(collectionItems.map((c) => c.cardId));

        final watchlistItems =
            await CollectionRepository.getWatchlist(activeUserId);
        watchlistCardIds.addAll(watchlistItems.map((w) => w.cardId));

        // 3. Ambil riwayat interaksi 90 hari terakhir
        final interactions = await InteractionService.instance
            .getRecentInteractions(activeUserId, days: 90);

        final now = DateTime.now().toUtc();
        final oneDayAgo = now.subtract(const Duration(hours: 24));

        for (final item in interactions) {
          if (item.cardId != null &&
              item.eventType == InteractionService.eventCardView &&
              item.createdAt.isAfter(oneDayAgo)) {
            recentViewedCardIds.add(item.cardId!);
          }
        }

        // 4. Bangun profil minat pengguna
        final profile = RecommendationEngine.buildProfile(
          interactions: interactions,
          cardMap: cardMap,
          now: now,
        );

        // 5. Generate daftar rekomendasi
        final recommendations = RecommendationEngine.generateRecommendations(
          catalog: catalog,
          profile: profile,
          binderCardIds: binderCardIds,
          watchlistCardIds: watchlistCardIds,
          recentViewedCardIds: recentViewedCardIds,
          userId: activeUserId,
          now: now,
        );

        final totalInteractions = await InteractionService.instance
            .getUserInteractionCount(activeUserId);

        state = state.copyWith(
          items: recommendations,
          profile: profile,
          interactionCount: totalInteractions,
          isLoading: false,
          isColdStart: profile.isColdStart,
          errorMessage: null,
        );
      } else {
        // Tamu / belum login -> Fallback Cold Start
        final now = DateTime.now().toUtc();
        final emptyProfile = RecommendationEngine.buildProfile(
          interactions: [],
          cardMap: cardMap,
          now: now,
        );

        final recommendations = RecommendationEngine.generateRecommendations(
          catalog: catalog,
          profile: emptyProfile,
          binderCardIds: {},
          watchlistCardIds: {},
          recentViewedCardIds: {},
          userId: 'guest',
          now: now,
        );

        state = state.copyWith(
          items: recommendations,
          profile: emptyProfile,
          interactionCount: 0,
          isLoading: false,
          isColdStart: true,
          errorMessage: null,
        );
      }
    } catch (e) {
      debugPrint('[HoloDex Error] Gagal memuat rekomendasi personal: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menghitung rekomendasi',
      );
    }
  }
}

/// Provider global rekomendasi personal
final recommendationProvider =
    StateNotifierProvider<RecommendationNotifier, RecommendationState>((ref) {
  return RecommendationNotifier(ref);
});
