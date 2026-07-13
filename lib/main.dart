import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'data/remote/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/quick_add/quick_add_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase — auth sessions persist automatically.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize notifications
  await NotificationService().init();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Detect whether we were launched by QuickAddActivity.
  // QuickAddActivity sets initialRoute = /quick-add/{tripId}?name={tripName}.
  final defaultRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;

  if (defaultRoute.startsWith('/quick-add')) {
    final uri = Uri.parse(defaultRoute);
    final segments = uri.pathSegments; // ['quick-add', '{tripId}']
    final tripId = segments.length >= 2 ? segments[1] : '';
    final tripName = uri.queryParameters['name'] ?? 'Trip';

    runApp(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: QuickAddApp(tripId: tripId, tripName: tripName),
    ));
  } else {
    runApp(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TripTabApp(),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main App
// ─────────────────────────────────────────────────────────────────────────────

/// Root widget for TripTab.
class TripTabApp extends ConsumerWidget {
  const TripTabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TripTab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-Add App (transparent root — launched from notification)
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal app root used exclusively when launched from the active-trip
/// notification via [QuickAddActivity].
class QuickAddApp extends StatelessWidget {
  final String tripId;
  final String tripName;

  const QuickAddApp({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: QuickAddScreen(tripId: tripId, tripName: tripName),
    );
  }
}
