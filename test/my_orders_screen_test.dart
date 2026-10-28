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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    CurrencyService.setMockRates(const CurrencyRates(
      usdToEur: 0.92,
      usdToIdr: 16000.0,
      ecbDate: '2026-10-25',
    ));
  });

  const sampleCard = CardModel(
    id: 'swsh3-19',
    localId: '19',
    name: 'Charizard V',
    setId: 'swsh3',
    setName: 'Darkness Ablaze',
    rarity: 'Ultra Rare',
    priceIdr: 250000,
    hasPrice: true,
  );

  final sampleListing = ListingModel(
    id: 'list-101',
    cardId: 'swsh3-19',
    sellerId: 'user-seller-1',
    priceIdr: 250000,
    condition: 'near_mint',
    lat: -6.2088,
    lng: 106.8456,
    status: 'reserved',
  );

  const testUser = UserModel(
    id: 'user-buyer-1',
    username: 'ilham_collector',
    balanceIdr: 1000000,
  );

  final now = DateTime.now();
  final expiresFuture = now.add(const Duration(hours: 48));

  final buyerOrderReserved = OrderModel(
    id: 'ord-1',
    listingId: 'list-101',
    buyerId: 'user-buyer-1',
    sellerId: 'user-seller-1',
    cardId: 'swsh3-19',
    amountIdr: 250000,
    status: OrderStatus.reserved,
    reservedAt: now,
    expiresAt: expiresFuture,
    isBuyer: true,
    otherPartyUsername: 'kolektor_jkt',
    card: sampleCard,
    listing: sampleListing,
  );

  final buyerOrderCompleted = OrderModel(
    id: 'ord-2',
    listingId: 'list-102',
    buyerId: 'user-buyer-1',
    sellerId: 'user-seller-1',
    cardId: 'swsh3-19',
    amountIdr: 180000,
    status: OrderStatus.completed,
    reservedAt: now.subtract(const Duration(days: 2)),
    expiresAt: expiresFuture,
    completedAt: now.subtract(const Duration(days: 1)),
    isBuyer: true,
    otherPartyUsername: 'kolektor_jkt',
    card: sampleCard,
  );

  final sellerOrderReserved = OrderModel(
    id: 'ord-3',
    listingId: 'list-103',
    buyerId: 'user-buyer-2',
    sellerId: 'user-buyer-1',
    cardId: 'swsh3-19',
    amountIdr: 300000,
    status: OrderStatus.reserved,
    reservedAt: now,
    expiresAt: expiresFuture,
    isBuyer: false,
    otherPartyUsername: 'pembeli_sby',
    card: sampleCard,
    listing: sampleListing,
  );

  group('MyOrdersScreen Widget Tests', () {
    testWidgets(
      'MyOrdersScreen builds on 320dp with fontScale 1.3 without layout exception',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 1100 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        FlutterErrorDetails? errorDetails;
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          errorDetails = details;
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                (ref) => FakeAuthNotifier(
                  const AuthState(
                    status: AuthStatus.authenticated,
                    user: testUser,
                  ),
                ),
              ),
              orderProvider.overrideWith(
                (ref) => FakeOrderNotifier(
                  ref,
                  OrderState(
                    orders: [
                      buyerOrderReserved,
                      buyerOrderCompleted,
                      sellerOrderReserved,
                    ],
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 1100),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: const MyOrdersScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        FlutterError.onError = oldHandler;

        expect(find.text('Pesanan Rekber'), findsOneWidget);
        expect(find.text('Pembelian'), findsOneWidget);
        expect(find.text('Penjualan'), findsOneWidget);

        // Periksa render kartu pesanan di tab Pembelian
        expect(find.text('Charizard V'), findsWidgets);
        expect(find.text('Dipesan'), findsWidgets);
        expect(find.text('Sudah Kuterima'), findsOneWidget);
        expect(find.text('Batalkan'), findsOneWidget);

        // Periksa status Selesai pada pesanan kedua
        expect(find.text('Selesai'), findsOneWidget);

        expect(errorDetails, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('MyOrdersScreen tab Penjualan menampilkan aksi hanya Batalkan tanpa Sudah Kuterima', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
              ),
            ),
            orderProvider.overrideWith(
              (ref) => FakeOrderNotifier(
                ref,
                OrderState(
                  orders: [sellerOrderReserved],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MyOrdersScreen(initialTabIndex: 1), // Tab Penjualan
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pembeli: @pembeli_sby'), findsOneWidget);
      expect(find.text('Batalkan'), findsOneWidget);
      // Penjual TIDAK boleh memiliki tombol 'Sudah Kuterima'
      expect(find.text('Sudah Kuterima'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MyOrdersScreen empty state displays informative message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
              ),
            ),
            orderProvider.overrideWith(
              (ref) => FakeOrderNotifier(
                ref,
                const OrderState(orders: []),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MyOrdersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Belum ada pesanan pembelian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MyOrdersScreen klik Batalkan membuka _CancelOrderDialog dan ditutup tanpa exception', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
              ),
            ),
            orderProvider.overrideWith(
              (ref) => FakeOrderNotifier(
                ref,
                OrderState(
                  orders: [buyerOrderReserved],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const MyOrdersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cari tombol Batalkan
      final cancelButton = find.widgetWithText(OutlinedButton, 'Batalkan');
      expect(cancelButton, findsOneWidget);

      // Klik tombol Batalkan
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Verifikasi dialog pembatalan muncul
      expect(find.text('Batalkan Pesanan?'), findsOneWidget);
      expect(find.text('Ya, Batalkan'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);

      // Masukkan teks alasan pembatalan
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Jadwal COD bentrok');
      await tester.pumpAndSettle();

      // Klik tombol Kembali untuk menutup dialog dengan aman
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();

      // Dialog harus tertutup dan tidak ada assertion error _dependents.isEmpty
      expect(find.text('Batalkan Pesanan?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

