import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/notification_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../core/models/card_model.dart';
import '../core/models/listing_model.dart';
import '../features/converter/screens/calendar_screen.dart';
import '../features/converter/screens/converter_screen.dart';
import '../features/dex/screens/card_detail_screen.dart';
import '../features/dex/screens/dex_screen.dart';
import '../features/dex/screens/search_screen.dart';
import '../features/marketplace/screens/create_listing_screen.dart';
import '../features/marketplace/screens/listing_detail_screen.dart';
import '../features/marketplace/screens/map_screen.dart';
import '../features/marketplace/screens/marketplace_screen.dart';
import '../features/marketplace/screens/my_orders_screen.dart';
import '../features/marketplace/screens/transaction_history_screen.dart';
import '../features/profile/screens/collection_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/watchlist_screen.dart';
import '../features/pack_opening/screens/pack_opening_screen.dart';
import '../features/saran_kesan/screens/saran_kesan_screen.dart';
import '../shared/widgets/bottom_nav_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/converter',
      name: 'converter',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ConverterScreen(
          initialAmount: (extra?['initialAmount'] as num?)?.toDouble(),
          initialCurrency: extra?['initialCurrency'] as String?,
          cardName: extra?['cardName'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/calendar',
      name: 'calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/collection',
      name: 'collection',
      builder: (context, state) => const CollectionScreen(),
    ),
    GoRoute(
      path: '/watchlist',
      name: 'watchlist',
      builder: (context, state) => const WatchlistScreen(),
    ),
    GoRoute(
      path: '/profile/collection',
      redirect: (context, state) => '/collection',
    ),
    GoRoute(
      path: '/profile/watchlist',
      redirect: (context, state) => '/watchlist',
    ),
    GoRoute(
      path: '/pack-opening',
      name: 'pack-opening',
      builder: (context, state) => const PackOpeningScreen(),
    ),
    // Detail Kartu di root navigator (layar penuh, bebas tabrakan shell branch & double-tap)
    GoRoute(
      path: '/dex/card/:id',
      name: 'card-detail',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final cardId = state.pathParameters['id'] ?? '';
        final initialCard = state.extra as CardModel?;
        return MaterialPage(
          key: ValueKey('card_${cardId}_${DateTime.now().microsecondsSinceEpoch}'),
          child: CardDetailScreen(
            cardId: cardId,
            initialCard: initialCard,
          ),
        );
      },
    ),
    // Shell 5 tab (Dex, Pasar, Profil, Saran & Logout)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BottomNavShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Dex
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dex',
              name: 'dex',
              builder: (context, state) => const DexScreen(),
              routes: [
                GoRoute(
                  path: 'search',
                  name: 'search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
          ],
        ),
        // Tab 1: Pasar (Marketplace)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/marketplace',
              name: 'marketplace',
              builder: (context, state) => const MarketplaceScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  name: 'marketplace-create',
                  builder: (context, state) {
                    final card = state.extra as CardModel?;
                    return CreateListingScreen(preselectedCard: card);
                  },
                ),
                GoRoute(
                  path: 'history',
                  name: 'marketplace-history',
                  builder: (context, state) => const TransactionHistoryScreen(),
                ),
                GoRoute(
                  path: 'orders',
                  name: 'marketplace-orders',
                  builder: (context, state) => const MyOrdersScreen(),
                ),
                GoRoute(
                  path: 'map',
                  name: 'marketplace-map',
                  builder: (context, state) => const MapScreen(),
                ),
                GoRoute(
                  path: 'listing/:id',
                  name: 'listing-detail',
                  builder: (context, state) {
                    final listingId = state.pathParameters['id'] ?? '';
                    final initialListing = state.extra as ListingModel?;
                    return ListingDetailScreen(
                      listingId: listingId,
                      initialListing: initialListing,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        // Tab 2: Profil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        // Tab 3: Saran & Kesan
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saran-kesan',
              name: 'saran-kesan',
              builder: (context, state) => const SaranKesanScreen(),
            ),
          ],
        ),
      ],
    ),
    // Backward compatibility untuk route /home
    GoRoute(
      path: '/home',
      redirect: (context, state) => '/dex',
    ),
  ],
);

/// Menghubungkan klik notifikasi ke sistem routing aplikasi
void setupNotificationNavigation() {
  NotificationService.onNotificationTapped = (payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'];
      if (type == 'collection') {
        appRouter.push('/collection');
      } else if (type == 'calendar') {
        appRouter.push('/calendar');
      } else if (type == 'card_detail' && data['cardId'] != null) {
        appRouter.push('/dex/card/${data['cardId']}');
      } else if (type == 'marketplace') {
        appRouter.push('/marketplace/transactions');
      } else if (type == 'orders') {
        appRouter.push('/marketplace/orders');
      }
    } catch (e) {
      debugPrint('[HoloDex Router] Error handling notification tap: $e');
    }
  };
}
