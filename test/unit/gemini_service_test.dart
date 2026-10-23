import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/features/ai/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyCard = CardModel(
    id: 'swsh3-001',
    name: 'Butterfree VMAX',
    setName: 'Darkness Ablaze',
    setId: 'swsh3',
    localId: '001',
    rarity: 'VMAX',
    cardType: 'Pokémon',
    priceIdr: 45000,
    priceUsd: 3.0,
    priceEur: 2.7,
  );

  group('GeminiService Unit Tests', () {
    setUp(() {
      GeminiService.clearCache();
    });

    test('GeminiCacheEntry TTL 60 menit validasi expiry', () {
      final freshEntry = GeminiCacheEntry(
        answer: 'Test Answer',
        timestamp: DateTime.now(),
      );
      expect(freshEntry.isExpired, isFalse);

      final expiredEntry = GeminiCacheEntry(
        answer: 'Old Answer',
        timestamp: DateTime.now().subtract(const Duration(minutes: 61)),
      );
      expect(expiredEntry.isExpired, isTrue);
    });

    test('askCardAdvisor mengembalikan pesan ramah jika API key belum diisi', () async {
      // Jika di lingkungan test API key belum terisi / dummy
      final response = await GeminiService.askCardAdvisor(
        card: dummyCard,
        question: 'Apakah kartu ini bagus?',
      );

      // Verifikasi respons tidak crash
      expect(response, isNotEmpty);
    });

    test('generateListingDescription menghasilkan deskripsi otomatis yang relevan', () async {
      final desc = await GeminiService.generateListingDescription(
        card: dummyCard,
        conditionLabel: 'Near Mint (Sangat Mulus)',
      );

      expect(desc, isNotEmpty);
      expect(desc.toLowerCase(), contains('butterfree vmax'));
    });
  });
}
