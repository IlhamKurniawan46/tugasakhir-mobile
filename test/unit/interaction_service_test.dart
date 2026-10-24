import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/core/services/interaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final service = InteractionService.instance;

  group('InteractionService Unit Tests', () {
    const testUser1 = 'test_user_ai_1';
    const testUser2 = 'test_user_ai_2';

    setUp(() async {
      await service.clearUserInteractions(testUser1);
      await service.clearUserInteractions(testUser2);
    });

    tearDown(() async {
      await service.clearUserInteractions(testUser1);
      await service.clearUserInteractions(testUser2);
    });

    test('1. Deduplikasi 30 detik pada card_view bekerja dengan benar', () async {
      // Pembukaan pertama -> harus tercatat
      await service.logCardView(userId: testUser1, cardId: 'c-charizard');
      var count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(1));

      // Pembukaan kedua langsung (<30 detik) -> diabaikan
      await service.logCardView(userId: testUser1, cardId: 'c-charizard');
      count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(1));

      // Pembukaan kartu BERBEDA -> harus tercatat
      await service.logCardView(userId: testUser1, cardId: 'c-blastoise');
      count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(2));
    });

    test('2. Pencarian teks kosong atau < 3 karakter diabaikan', () async {
      await service.logSearch(userId: testUser1, query: '');
      await service.logSearch(userId: testUser1, query: '  ');
      await service.logSearch(userId: testUser1, query: 'ab');
      var count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(0));

      // Query >= 3 karakter tercatat
      await service.logSearch(userId: testUser1, query: 'Mew');
      count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(1));
    });

    test('3. Isolasi antar pengguna bekerja dengan benar', () async {
      await service.logPurchase(userId: testUser1, cardId: 'c-pikachu');
      await service.logPurchase(userId: testUser2, cardId: 'c-eevee');

      final events1 = await service.getRecentInteractions(testUser1);
      final events2 = await service.getRecentInteractions(testUser2);

      expect(events1.length, equals(1));
      expect(events1.first.cardId, equals('c-pikachu'));

      expect(events2.length, equals(1));
      expect(events2.first.cardId, equals('c-eevee'));
    });

    test('4. Pemangkasan maksimal 1000 event per pengguna', () async {
      // Uji insert beberapa event dan verifikasi batas
      for (int i = 0; i < 5; i++) {
        await service.logListingView(userId: testUser1, cardId: 'c-$i');
      }
      final count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(5));

      // Reset
      await service.clearUserInteractions(testUser1);
      final countAfterClear = await service.getUserInteractionCount(testUser1);
      expect(countAfterClear, equals(0));
    });

    test('5. Pencatatan kuis selera pengguna (eventQuiz)', () async {
      await service.logQuizAnswer(userId: testUser1, answerKey: 'type:Fire');
      await service.logQuizAnswer(userId: testUser1, answerKey: 'set:sv03.5');
      await service.logQuizAnswer(userId: testUser1, answerKey: 'price:under1');

      final count = await service.getUserInteractionCount(testUser1);
      expect(count, equals(3));

      final events = await service.getRecentInteractions(testUser1);
      expect(events.length, equals(3));
      expect(events.every((e) => e.eventType == InteractionService.eventQuiz), isTrue);
    });
  });
}
