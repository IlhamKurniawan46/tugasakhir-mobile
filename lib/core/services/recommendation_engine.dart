import 'dart:math';

import '../models/card_model.dart';
import '../models/user_interaction_model.dart';
import 'interaction_service.dart';

/// Pita harga USD untuk kartu Pokémon TCG
enum PriceBracket {
  under1('<1 USD', 0, 1.0),
  oneToFive('1-5 USD', 1.0, 5.0),
  fiveToTwenty('5-20 USD', 5.0, 20.0),
  twentyToOneHundred('20-100 USD', 20.0, 100.0),
  aboveOneHundred('>100 USD', 100.0, double.infinity);

  final String label;
  final double min;
  final double max;
  const PriceBracket(this.label, this.min, this.max);

  static PriceBracket? fromUsd(double? priceUsd) {
    if (priceUsd == null || priceUsd < 0) return null;
    for (final b in PriceBracket.values) {
      if (priceUsd >= b.min && priceUsd < b.max) {
        return b;
      }
    }
    return PriceBracket.aboveOneHundred;
  }

  /// Kedekatan antar pita harga: sama = 1.0, bersebelahan = 0.5, lainnya = 0.0
  double proximityTo(PriceBracket? other) {
    if (other == null) return 0.0;
    final diff = (index - other.index).abs();
    if (diff == 0) return 1.0;
    if (diff == 1) return 0.5;
    return 0.0;
  }
}

/// Hasil rekomendasi satu kartu lengkap dengan skor dan alasan
class RecommendedCard {
  final CardModel card;
  final double score;
  final String reason;
  final bool isExploration;

  const RecommendedCard({
    required this.card,
    required this.score,
    required this.reason,
    this.isExploration = false,
  });
}

/// Representasi item minat teratas pengguna untuk visualisasi profil
class InterestAffinity {
  final String category; // 'Pokémon', 'Set', 'Tipe', 'Rarity', 'Budget'
  final String label;
  final double weight;
  final double percentage; // Relatif terhadap bobot teratas (0.0 - 1.0)

  const InterestAffinity({
    required this.category,
    required this.label,
    required this.weight,
    required this.percentage,
  });
}

/// Profil minat pengguna yang dihitung dari riwayat interaksi berbobot dan peluruhan waktu
class UserInterestProfile {
  final Map<String, double> pokemonWeights;
  final Map<String, double> setWeights;
  final Map<String, double> rarityWeights;
  final Map<String, double> typeWeights;
  final Map<PriceBracket, double> priceBracketWeights;
  final double totalWeight;

  const UserInterestProfile({
    required this.pokemonWeights,
    required this.setWeights,
    required this.rarityWeights,
    required this.typeWeights,
    required this.priceBracketWeights,
    required this.totalWeight,
  });

  bool get isColdStart => totalWeight < RecommendationEngine.coldStartThreshold;

  /// Mengambil daftar minat teratas lintas kategori untuk visualisasi di profil
  List<InterestAffinity> getTopInterests({int limit = 5}) {
    final list = <InterestAffinity>[];

    for (final e in pokemonWeights.entries) {
      if (e.value > 0.1) {
        list.add(InterestAffinity(
          category: 'Pokémon',
          label: e.key,
          weight: e.value,
          percentage: 0.0,
        ));
      }
    }
    for (final e in typeWeights.entries) {
      if (e.value > 0.1) {
        list.add(InterestAffinity(
          category: 'Tipe',
          label: e.key,
          weight: e.value,
          percentage: 0.0,
        ));
      }
    }
    for (final e in setWeights.entries) {
      if (e.value > 0.1) {
        list.add(InterestAffinity(
          category: 'Set',
          label: e.key.toUpperCase(),
          weight: e.value,
          percentage: 0.0,
        ));
      }
    }
    for (final e in rarityWeights.entries) {
      if (e.value > 0.1) {
        list.add(InterestAffinity(
          category: 'Rarity',
          label: e.key,
          weight: e.value,
          percentage: 0.0,
        ));
      }
    }
    for (final e in priceBracketWeights.entries) {
      if (e.value > 0.1) {
        list.add(InterestAffinity(
          category: 'Budget',
          label: e.key.label,
          weight: e.value,
          percentage: 0.0,
        ));
      }
    }

    if (list.isEmpty) return [];

    list.sort((a, b) => b.weight.compareTo(a.weight));
    final topList = list.take(limit).toList();
    final maxWeight = topList.first.weight;

    return topList.map((item) {
      final pct = maxWeight > 0 ? (item.weight / maxWeight).clamp(0.0, 1.0) : 0.0;
      return InterestAffinity(
        category: item.category,
        label: item.label,
        weight: item.weight,
        percentage: pct,
      );
    }).toList();
  }
}

/// Mesin rekomendasi on-device murni (Content-Based Filtering Heuristik Berbobot)
/// Tanpa LLM / API eksternal, transparan, dan deterministik.
class RecommendationEngine {
  // Waktu paruh peluruhan eksponensial (14 hari)
  static const double halfLifeDays = 14.0;

  // Batas rentang riwayat interaksi (90 hari)
  static const int maxInteractionAgeDays = 90;

  // Ambang batas cold start profil minat
  static const double coldStartThreshold = 5.0;

  // Bobot kelompok atribut awal (dinormalisasi ulang agar total = 1.0)
  // pokemon: 0.30, set: 0.20, rarity: 0.15, type: 0.15, price: 0.15 (total dasar = 0.95)
  static const double baseWeightPokemon = 0.30 / 0.95; // ~0.3158
  static const double baseWeightSet = 0.20 / 0.95; // ~0.2105
  static const double baseWeightRarity = 0.15 / 0.95; // ~0.1579
  static const double baseWeightType = 0.15 / 0.95; // ~0.1579
  static const double baseWeightPrice = 0.15 / 0.95; // ~0.1579

  // Batas maksimal kartu dari set yang sama di daftar rekomendasi
  static const int maxCardsPerSet = 3;

  // Target jumlah rekomendasi
  static const int targetRecommendationCount = 10;

  // Daftar sufiks nama Pokémon yang dibuang untuk ekstraksi nama Pokémon dasar
  static final RegExp _pokemonSuffixRegex = RegExp(
    r'\b(VMAX|VSTAR|V-UNION|V|ex|EX|GX|BREAK|Tag Team|Prism Star|Prime|LV\.X|Star|Radiant|Shiny|Tera|Mega|Ancient|Future)\b',
    caseSensitive: false,
  );

  /// Ekstraksi nama dasar Pokémon dari nama kartu (mis. "Charizard ex" -> "Charizard")
  static String extractPokemonName(String cardName) {
    var cleaned = cardName.replaceAll(_pokemonSuffixRegex, '').trim();
    // Hilangkan tanda kurung atau simbol ekstra
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : cardName.trim();
  }

  /// Menghitung peluruhan eksponensial bobot event: bobot_dasar * 0.5^(umur_hari / 14)
  static double calculateDecayedWeight({
    required double baseWeight,
    required DateTime eventTime,
    required DateTime currentTime,
  }) {
    final ageInHours = currentTime.difference(eventTime).inHours;
    final ageInDays = max(0.0, ageInHours / 24.0);

    if (ageInDays > maxInteractionAgeDays) return 0.0;

    return baseWeight * pow(0.5, ageInDays / halfLifeDays);
  }

  /// Membangun profil minat pengguna dari kumpulan interaksi dan referensi kartu
  static UserInterestProfile buildProfile({
    required List<UserInteraction> interactions,
    required Map<String, CardModel> cardMap,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();

    final pokemonWeights = <String, double>{};
    final setWeights = <String, double>{};
    final rarityWeights = <String, double>{};
    final typeWeights = <String, double>{};
    final priceBracketWeights = <PriceBracket, double>{};
    double totalWeight = 0.0;

    for (final event in interactions) {
      final baseWeight = InteractionService.baseWeights[event.eventType] ?? 1.0;
      final decayedWeight = calculateDecayedWeight(
        baseWeight: baseWeight,
        eventTime: event.createdAt,
        currentTime: currentTime,
      );

      if (decayedWeight <= 0) continue;
      totalWeight += decayedWeight;

      // 1. Jika event memiliki cardId
      if (event.cardId != null && cardMap.containsKey(event.cardId)) {
        final card = cardMap[event.cardId]!;

        // Atribut Pokémon
        final pName = extractPokemonName(card.name);
        pokemonWeights[pName] = (pokemonWeights[pName] ?? 0.0) + decayedWeight;

        // Atribut Set
        if (card.setId != null) {
          setWeights[card.setId!] =
              (setWeights[card.setId!] ?? 0.0) + decayedWeight;
        }

        // Atribut Rarity
        if (card.rarity != null) {
          rarityWeights[card.rarity!] =
              (rarityWeights[card.rarity!] ?? 0.0) + decayedWeight;
        }

        // Atribut Tipe Elemen
        if (card.cardType != null) {
          typeWeights[card.cardType!] =
              (typeWeights[card.cardType!] ?? 0.0) + decayedWeight;
        }

        // Atribut Pita Harga
        final bracket = PriceBracket.fromUsd(card.priceRefUsd);
        if (bracket != null) {
          priceBracketWeights[bracket] =
              (priceBracketWeights[bracket] ?? 0.0) + decayedWeight;
        }
      }

      // 2. Jika event adalah pencarian atau kuis
      if (event.queryText != null && event.queryText!.isNotEmpty) {
        _mapQueryToAttributes(
          query: event.queryText!,
          weight: decayedWeight,
          cardMap: cardMap,
          pokemonWeights: pokemonWeights,
          setWeights: setWeights,
          rarityWeights: rarityWeights,
          typeWeights: typeWeights,
          priceBracketWeights: priceBracketWeights,
        );
      }
    }

    return UserInterestProfile(
      pokemonWeights: pokemonWeights,
      setWeights: setWeights,
      rarityWeights: rarityWeights,
      typeWeights: typeWeights,
      priceBracketWeights: priceBracketWeights,
      totalWeight: totalWeight,
    );
  }

  /// Memetakan kata kunci pencarian / jawaban kuis ke atribut kartu
  static void _mapQueryToAttributes({
    required String query,
    required double weight,
    required Map<String, CardModel> cardMap,
    required Map<String, double> pokemonWeights,
    required Map<String, double> setWeights,
    required Map<String, double> rarityWeights,
    required Map<String, double> typeWeights,
    required Map<PriceBracket, double> priceBracketWeights,
  }) {
    final lowerQuery = query.toLowerCase().trim();

    // Jawaban kuis dengan prefix (Tahap 2)
    if (lowerQuery.startsWith('type:')) {
      final t = query.substring(5).trim();
      typeWeights[t] = (typeWeights[t] ?? 0.0) + weight;
      return;
    }
    if (lowerQuery.startsWith('set:')) {
      final s = query.substring(4).trim();
      setWeights[s] = (setWeights[s] ?? 0.0) + weight;
      return;
    }
    if (lowerQuery.startsWith('price:')) {
      final pLabel = query.substring(6).trim().toLowerCase();
      for (final b in PriceBracket.values) {
        if (b.label.toLowerCase() == pLabel ||
            b.name.toLowerCase() == pLabel) {
          priceBracketWeights[b] = (priceBracketWeights[b] ?? 0.0) + weight;
          return;
        }
      }
      if (pLabel.contains('budget') || pLabel.contains('<1') || pLabel.contains('under1')) {
        priceBracketWeights[PriceBracket.under1] = (priceBracketWeights[PriceBracket.under1] ?? 0.0) + weight;
        return;
      }
      if (pLabel.contains('entry') || pLabel.contains('1-5') || pLabel.contains('onetofive')) {
        priceBracketWeights[PriceBracket.oneToFive] = (priceBracketWeights[PriceBracket.oneToFive] ?? 0.0) + weight;
        return;
      }
      if (pLabel.contains('mid') || pLabel.contains('5-20') || pLabel.contains('fivetotwenty')) {
        priceBracketWeights[PriceBracket.fiveToTwenty] = (priceBracketWeights[PriceBracket.fiveToTwenty] ?? 0.0) + weight;
        return;
      }
      if (pLabel.contains('high') || pLabel.contains('20-100') || pLabel.contains('twentytoonehundred')) {
        priceBracketWeights[PriceBracket.twentyToOneHundred] = (priceBracketWeights[PriceBracket.twentyToOneHundred] ?? 0.0) + weight;
        return;
      }
      if (pLabel.contains('grail') || pLabel.contains('>100') || pLabel.contains('aboveonehundred')) {
        priceBracketWeights[PriceBracket.aboveOneHundred] = (priceBracketWeights[PriceBracket.aboveOneHundred] ?? 0.0) + weight;
        return;
      }
    }

    // Pencarian biasa: cari kecocokan pada tipe elemen resmi
    const pokemonTypes = [
      'Grass',
      'Fire',
      'Water',
      'Lightning',
      'Psychic',
      'Fighting',
      'Darkness',
      'Metal',
      'Dragon',
      'Colorless',
    ];
    for (final t in pokemonTypes) {
      if (lowerQuery == t.toLowerCase()) {
        typeWeights[t] = (typeWeights[t] ?? 0.0) + weight;
        return;
      }
    }

    // Cari kecocokan pada nama Pokémon dari kartu katalog
    for (final card in cardMap.values) {
      final pName = extractPokemonName(card.name);
      if (lowerQuery == pName.toLowerCase()) {
        pokemonWeights[pName] = (pokemonWeights[pName] ?? 0.0) + weight;
        return;
      }
      if (card.setName != null && lowerQuery == card.setName!.toLowerCase()) {
        if (card.setId != null) {
          setWeights[card.setId!] = (setWeights[card.setId!] ?? 0.0) + weight;
          return;
        }
      }
    }
  }

  /// Menghitung skor afinitas sebuah kartu terhadap profil minat pengguna
  static ({double score, String reason}) scoreCard({
    required CardModel card,
    required UserInterestProfile profile,
  }) {
    if (profile.isColdStart) {
      return (score: 0.0, reason: 'Pilihan awal untukmu');
    }

    double totalScore = 0.0;
    double maxContribution = -1.0;
    String primaryReason = 'Sesuai dengan seleramu';

    // 1. Afinitas Pokémon
    final maxPokemonWeight = _maxMapValue(profile.pokemonWeights);
    if (maxPokemonWeight > 0) {
      final pName = extractPokemonName(card.name);
      final pWeight = profile.pokemonWeights[pName] ?? 0.0;
      final affinity = pWeight / maxPokemonWeight;
      final contribution = baseWeightPokemon * affinity;
      totalScore += contribution;

      if (contribution > maxContribution && affinity > 0.2) {
        maxContribution = contribution;
        primaryReason = 'Karena kamu sering melihat $pName';
      }
    }

    // 2. Afinitas Set
    final maxSetWeight = _maxMapValue(profile.setWeights);
    if (maxSetWeight > 0 && card.setId != null) {
      final sWeight = profile.setWeights[card.setId!] ?? 0.0;
      final affinity = sWeight / maxSetWeight;
      final contribution = baseWeightSet * affinity;
      totalScore += contribution;

      if (contribution > maxContribution && affinity > 0.2) {
        maxContribution = contribution;
        primaryReason = 'Set favoritmu: ${card.setName ?? card.setId}';
      }
    }

    // 3. Afinitas Rarity
    final maxRarityWeight = _maxMapValue(profile.rarityWeights);
    if (maxRarityWeight > 0 && card.rarity != null) {
      final rWeight = profile.rarityWeights[card.rarity!] ?? 0.0;
      final affinity = rWeight / maxRarityWeight;
      final contribution = baseWeightRarity * affinity;
      totalScore += contribution;

      if (contribution > maxContribution && affinity > 0.2) {
        maxContribution = contribution;
        primaryReason = 'Rarity yang kamu sukai: ${card.rarity}';
      }
    }

    // 4. Afinitas Tipe Elemen
    final maxTypeWeight = _maxMapValue(profile.typeWeights);
    if (maxTypeWeight > 0 && card.cardType != null) {
      final tWeight = profile.typeWeights[card.cardType!] ?? 0.0;
      final affinity = tWeight / maxTypeWeight;
      final contribution = baseWeightType * affinity;
      totalScore += contribution;

      if (contribution > maxContribution && affinity > 0.2) {
        maxContribution = contribution;
        primaryReason = 'Sesuai minat tipe ${card.cardType}';
      }
    }

    // 5. Afinitas Pita Harga
    final maxPriceWeight = _maxPriceBracketValue(profile.priceBracketWeights);
    final cardBracket = PriceBracket.fromUsd(card.priceRefUsd);
    if (maxPriceWeight > 0 && cardBracket != null) {
      // Cari pita harga dengan bobot tertinggi di profil
      PriceBracket? bestBracket;
      double highestWeight = -1.0;
      profile.priceBracketWeights.forEach((b, w) {
        if (w > highestWeight) {
          highestWeight = w;
          bestBracket = b;
        }
      });

      if (bestBracket != null) {
        final proximity = cardBracket.proximityTo(bestBracket);
        final bracketWeight = profile.priceBracketWeights[bestBracket] ?? 0.0;
        final affinity = proximity * (bracketWeight / maxPriceWeight);
        final contribution = baseWeightPrice * affinity;
        totalScore += contribution;

        if (contribution > maxContribution && affinity > 0.2) {
          maxContribution = contribution;
          primaryReason = 'Pita harga yang sering kamu lihat';
        }
      }
    }

    return (score: totalScore, reason: primaryReason);
  }

  /// Menghasilkan daftar kartu rekomendasi (termasuk 2 slot eksplorasi dan fallback cold start)
  static List<RecommendedCard> generateRecommendations({
    required List<CardModel> catalog,
    required UserInterestProfile profile,
    required Set<String> binderCardIds,
    required Set<String> watchlistCardIds,
    required Set<String> recentViewedCardIds,
    String? userId,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now().toUtc();

    // 1. Filter kartu yang harus dikecualikan:
    // - Sudah ada di Binder (Koleksi)
    // - Sudah ada di Watchlist
    // - Baru dibuka dalam 24 jam terakhir
    final candidates = catalog.where((card) {
      if (binderCardIds.contains(card.id)) return false;
      if (watchlistCardIds.contains(card.id)) return false;
      if (recentViewedCardIds.contains(card.id)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return [];

    // 2. Penanganan COLD START:
    // Jika bobot profil < 5, berikan kartu populer yang beragam
    if (profile.isColdStart) {
      return _generateColdStartRecommendations(candidates);
    }

    // 3. Hitung skor tiap kandidat
    final scoredList = <({CardModel card, double score, String reason})>[];
    for (final card in candidates) {
      final res = scoreCard(card: card, profile: profile);
      scoredList.add((card: card, score: res.score, reason: res.reason));
    }

    // Urutkan berdasarkan skor tertinggi
    scoredList.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.card.id.compareTo(b.card.id); // Deterministik
    });

    final results = <RecommendedCard>[];
    final setCount = <String, int>{};
    final chosenCardIds = <String>{};

    // 4. Pilih slot utama (maks 3 kartu per set)
    // Target 8 kartu personalisasi + 2 kartu eksplorasi = 10 kartu
    const maxPersonalizedSlots = 8;
    for (final item in scoredList) {
      if (results.length >= maxPersonalizedSlots) break;
      if (item.score <= 0.05) break; // Jangan ambil skor yang nyaris nol

      final setId = item.card.setId ?? 'unknown';
      final currentInSet = setCount[setId] ?? 0;
      if (currentInSet >= maxCardsPerSet) continue;

      setCount[setId] = currentInSet + 1;
      chosenCardIds.add(item.card.id);
      results.add(RecommendedCard(
        card: item.card,
        score: item.score,
        reason: item.reason,
        isExploration: false,
      ));
    }

    // 5. Tambahkan 2 Slot EKSPLORASI (kartu bernilai sedang / dari set berbeda yang baru)
    final explorationCandidates = scoredList.where((item) {
      if (chosenCardIds.contains(item.card.id)) return false;
      final setId = item.card.setId ?? 'unknown';
      if ((setCount[setId] ?? 0) >= maxCardsPerSet) return false;
      // Ambil kartu dengan atribut yang belum dominan di profil
      final pName = extractPokemonName(item.card.name);
      final hasSeenPokemon = (profile.pokemonWeights[pName] ?? 0) > 0;
      return !hasSeenPokemon;
    }).toList();

    // Gunakan seed deterministik per hari dan per pengguna
    final dateSeed = currentTime.year * 10000 +
        currentTime.month * 100 +
        currentTime.day +
        (userId?.hashCode ?? 0);
    final random = Random(dateSeed);

    if (explorationCandidates.isNotEmpty) {
      explorationCandidates.shuffle(random);
      for (final exp in explorationCandidates.take(2)) {
        final setId = exp.card.setId ?? 'unknown';
        setCount[setId] = (setCount[setId] ?? 0) + 1;
        chosenCardIds.add(exp.card.id);
        results.add(RecommendedCard(
          card: exp.card,
          score: exp.score,
          reason: 'Coba jelajahi',
          isExploration: true,
        ));
      }
    }

    // Jika slot belum mencapai target, lengkapi dari sisa kartu terbaik yang beragam
    for (final item in scoredList) {
      if (results.length >= targetRecommendationCount) break;
      if (chosenCardIds.contains(item.card.id)) continue;

      final setId = item.card.setId ?? 'unknown';
      final currentInSet = setCount[setId] ?? 0;
      if (currentInSet >= maxCardsPerSet) continue;

      setCount[setId] = currentInSet + 1;
      chosenCardIds.add(item.card.id);
      results.add(RecommendedCard(
        card: item.card,
        score: item.score,
        reason: item.reason,
        isExploration: false,
      ));
    }

    return results;
  }

  /// Pilihan kartu awal untuk pengguna baru (Cold Start)
  static List<RecommendedCard> _generateColdStartRecommendations(
    List<CardModel> candidates,
  ) {
    // Urutkan berdasarkan harga referensi tertinggi (kartu paling populer/menarik)
    final sorted = List<CardModel>.from(candidates)
      ..sort((a, b) {
        final pa = a.priceRefUsd ?? 0.0;
        final pb = b.priceRefUsd ?? 0.0;
        return pb.compareTo(pa);
      });

    final results = <RecommendedCard>[];
    final setCount = <String, int>{};

    for (final card in sorted) {
      if (results.length >= targetRecommendationCount) break;
      final setId = card.setId ?? 'unknown';
      final inSet = setCount[setId] ?? 0;
      if (inSet >= 2) continue; // Batasi maks 2 per set agar bervariasi

      setCount[setId] = inSet + 1;
      results.add(RecommendedCard(
        card: card,
        score: 1.0,
        reason: 'Pilihan populer',
        isExploration: false,
      ));
    }

    return results;
  }

  static double _maxMapValue(Map<String, double> map) {
    if (map.isEmpty) return 0.0;
    return map.values.reduce(max);
  }

  static double _maxPriceBracketValue(Map<PriceBracket, double> map) {
    if (map.isEmpty) return 0.0;
    return map.values.reduce(max);
  }
}
