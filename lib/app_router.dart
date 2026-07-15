import 'package:flutter/foundation.dart';
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

/// A [ChangeNotifier] that re-triggers GoRouter's redirect whenever
/// [authProvider] changes — avoids recreating the entire GoRouter on
/// every auth state update (which causes route resets).
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this.ref) {
    ref.listen<AuthState>(authProvider, (_, next) {
      notifyListeners();
    });
  }

  final Ref ref;
  AuthState get _auth => ref.read(authProvider);
}

/// App-wide router.
///
/// KEY BEHAVIOURS:
/// 1. While [AuthState.isLoading] is true (session restore in progress),
///    the redirect returns null — no flash-to-login on cold start.
/// 2. Uses [refreshListenable] so GoRouter re-evaluates the redirect each
///    time auth state changes without recreating the router object.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      // Never redirect the quick-add overlay — it bypasses auth entirely.
      if (state.matchedLocation.startsWith('/quick-add')) return null;

      final auth = ref.read(authProvider);

      // While session restore is in progress — hold position.
      if (auth.isLoading) return null;

      final loggingIn = state.matchedLocation == '/login';
      if (!auth.isLoggedIn && !loggingIn) return '/login';
      if (auth.isLoggedIn && loggingIn) return '/home';
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
          final tripId    = state.pathParameters['id']!;
          final tripName  = state.uri.queryParameters['name'] ?? 'Trip';
          final isNewTrip = state.uri.queryParameters['isNewTrip'] == 'true';
          final code      = state.uri.queryParameters['code'];
          return InviteScreen(
            tripId: tripId,
            tripName: tripName,
            isNewTrip: isNewTrip,
            initialCode: code,
          );
        },
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const JoinTripScreen(),
      ),

      // ── Quick-add overlay ──────────────────────────────────────
      // Launched by QuickAddActivity — a transparent Activity with its
      // own Flutter engine. No auth redirect here.
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
