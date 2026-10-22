import 'collection_repository.dart';

/// Service adapter untuk kompatibilitas backward dengan Sesi 7.
/// Seluruh logika telah dipusatkan pada [CollectionRepository].
class CollectionService {
  static Future<bool> isInCollection(String userId, String cardId) =>
      CollectionRepository.isCardInCollection(userId, cardId);

  static Future<bool> isInWatchlist(String userId, String cardId) =>
      CollectionRepository.isInWatchlist(userId, cardId);

  static Future<void> addToWatchlist(
    String userId,
    String cardId, {
    double? alertPriceIdr,
  }) =>
      CollectionRepository.addToWatchlist(
        userId,
        cardId,
        alertPriceIdr: alertPriceIdr,
      );

  static Future<void> removeFromWatchlist(String userId, String cardId) =>
      CollectionRepository.removeFromWatchlist(userId, cardId);
}
