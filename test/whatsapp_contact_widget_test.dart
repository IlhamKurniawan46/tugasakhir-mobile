import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holodex/app/theme.dart';
import 'package:holodex/core/models/card_model.dart';
import 'package:holodex/core/models/listing_model.dart';
import 'package:holodex/core/models/order_model.dart';
import 'package:holodex/core/models/user_model.dart';
import 'package:holodex/core/services/currency_service.dart';
import 'package:holodex/features/auth/providers/auth_provider.dart';
import 'package:holodex/features/marketplace/providers/order_provider.dart';
import 'package:holodex/features/marketplace/screens/my_orders_screen.dart';
import 'package:holodex/features/profile/widgets/whatsapp_dialog.dart';

class FakeOrderNotifier extends OrderNotifier {
  final OrderState initialState;
  FakeOrderNotifier(super.ref, this.initialState) {
    state = initialState;
  }

  @override
  Future<void> loadOrders({bool silent = false}) async {}

  @override
  void startPolling() {}

  @override
  void stopPolling() {}
}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  FakeAuthNotifier(this.initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<String?> updateWhatsapp(String? phoneNumber) async {
    return phoneNumber;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    CurrencyService.setMockRates(const CurrencyRates(
      usdToEur: 0.92,
      usdToIdr: 16000.0,
      ecbDate: '2026-10-22',
    ));
  });

  const sampleCard = CardModel(
    id: 'swsh3-19',
    localId: '19',
    name: 'Charizard V',
    setId: 'swsh3',
    setName: 'Darkness Ablaze',
    rarity: 'Ultra Rare',
    priceIdr: 150000,
    hasPrice: true,
  );

  const sampleListing = ListingModel(
    id: 'listing-001',
    sellerId: 'seller-uuid',
    sellerUsername: 'kolektor_bandung',
    cardId: 'swsh3-19',
    card: sampleCard,
    priceIdr: 150000,
    condition: 'near_mint',
    lat: -6.9175,
    lng: 107.6191,
    status: 'reserved',
  );

  final sampleReservedOrder = OrderModel(
    id: 'order-reserved-001',
    listingId: 'listing-001',
    buyerId: 'buyer-uuid',
    sellerId: 'seller-uuid',
    cardId: 'swsh3-19',
    amountIdr: 150000,
    status: OrderStatus.reserved,
    reservedAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 48)),
    isBuyer: true,
    card: sampleCard,
    listing: sampleListing,
    otherPartyUsername: 'kolektor_bandung',
  );

  final sampleCompletedOrder = OrderModel(
    id: 'order-completed-002',
    listingId: 'listing-002',
    buyerId: 'buyer-uuid',
    sellerId: 'seller-uuid',
    cardId: 'swsh3-19',
    amountIdr: 150000,
    status: OrderStatus.completed,
    reservedAt: DateTime.now().subtract(const Duration(days: 2)),
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
    completedAt: DateTime.now().subtract(const Duration(days: 1)),
    isBuyer: true,
    card: sampleCard,
    listing: sampleListing,
    otherPartyUsername: 'kolektor_bandung',
  );

  const sampleUser = UserModel(
    id: 'buyer-uuid',
    username: 'muhildham',
    balanceIdr: 500000,
    whatsappNumber: '6281234567890',
  );

  Widget createTestWidget({
    required Widget child,
    List<OrderModel>? orders,
    UserModel? user,
    double textScale = 1.0,
    Size size = const Size(360, 640),
  }) {
    final activeUser = user ?? sampleUser;
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => FakeAuthNotifier(
            AuthState(status: AuthStatus.authenticated, user: activeUser),
          ),
        ),
        orderProvider.overrideWith(
          (ref) => FakeOrderNotifier(
            ref,
            OrderState(
              orders: orders ?? [sampleReservedOrder],
              isLoading: false,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('WhatsAppDialog Widget Tests', () {
    testWidgets('Renders WhatsAppDialog and handles 320dp textScale 1.3 safely',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(
            body: WhatsAppDialog(
              initialPhone: '081234567890',
            ),
          ),
          size: const Size(320, 568),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nomor WhatsApp'), findsWidgets);
      expect(find.textContaining('Dipakai hanya agar pembeli dan penjual'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('Shows error message when invalid number is entered',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const Scaffold(
            body: WhatsAppDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Masukkan nomor tidak valid (terlalu pendek)
      await tester.enterText(find.byType(TextField), '08123');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Format nomor tidak valid'), findsOneWidget);
    });
  });

  group('MyOrdersScreen WhatsApp Contact Button Tests', () {
    testWidgets('Menampilkan tombol Hubungi via WhatsApp pada order reserved',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(
        createTestWidget(
          child: const MyOrdersScreen(),
          orders: [sampleReservedOrder],
          size: const Size(320, 568),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Tombol WhatsApp harus muncul
      expect(find.text('Hubungi via WhatsApp'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

      // Teks tips keselamatan harus muncul
      expect(
        find.textContaining('Bertemu di tempat umum dan periksa kartu'),
        findsOneWidget,
      );
    });

    testWidgets('TIDAK menampilkan tombol WhatsApp pada order yang sudah completed',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const MyOrdersScreen(),
          orders: [sampleCompletedOrder],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hubungi via WhatsApp'), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });
  });
}
