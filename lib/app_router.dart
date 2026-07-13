import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/invite/invite_screen.dart';
import 'ui/screens/invite/join_trip_screen.dart';
import 'ui/screens/quick_add/quick_add_screen.dart';
import 'ui/screens/settlement/settlement_screen.dart';
import 'ui/screens/trip/create_trip_screen.dart';
import 'ui/screens/trip/trip_detail_screen.dart';
import 'ui/screens/trip/trip_settings_screen.dart';

/// App-wide router configuration using GoRouter.
///
/// Redirects unauthenticated users to /login and authenticated users
/// away from /login. Uses [isLoggedInProvider] for redirect logic.
final appRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Never redirect the quick-add overlay — it is launched by the
      // transparent QuickAddActivity and must bypass auth.
      if (state.matchedLocation.startsWith('/quick-add')) return null;

      final loggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn && !loggingIn) return '/login';
      if (isLoggedIn && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/trip/create',
        builder: (context, state) => const CreateTripScreen(),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return TripDetailScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trip/:id/settings',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return TripSettingsScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trip/:id/settlement',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          return SettlementScreen(tripId: tripId);
        },
      ),
      GoRoute(
        path: '/trip/:id/invite',
        builder: (context, state) {
          final tripId = state.pathParameters['id']!;
          final tripName = state.uri.queryParameters['name'] ?? 'Trip';
          return InviteScreen(tripId: tripId, tripName: tripName);
        },
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinTripScreen(),
      ),

      // ── Quick-add overlay ──────────────────────────────────────
      // Launched by QuickAddActivity (transparent Android window).
      // No auth redirect — this is an OS-level overlay.
      GoRoute(
        path: '/quick-add/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          final tripName = state.uri.queryParameters['name'] ?? 'Trip';
          return QuickAddScreen(tripId: tripId, tripName: tripName);
        },
      ),
    ],
  );
});
