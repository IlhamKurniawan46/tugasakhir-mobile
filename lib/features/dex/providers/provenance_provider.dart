import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/card_certificate_model.dart';
import '../../../core/services/blockchain_repository.dart';

/// Provider untuk mengambil riwayat kepemilikan & sertifikat on-chain kartu tertentu
final cardProvenanceProvider =
    FutureProvider.family<List<CardCertificateModel>, String>((ref, cardId) async {
  return await BlockchainRepository.getCardProvenance(cardId);
});
