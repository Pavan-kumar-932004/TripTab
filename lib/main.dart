import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TripTabApp()));
}

/// Root widget for TripTab.
///
/// Wrapped in [ProviderScope] for Riverpod state management.
/// Uses [GoRouter] for declarative routing with auth redirects.
/// Dark theme with teal accent via [AppTheme.dark].
class TripTabApp extends ConsumerWidget {
  const TripTabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TripTab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
