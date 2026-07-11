import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
export '../data/local/database.dart';

/// Provides the singleton [AppDatabase] instance to the widget tree.
///
/// Every DAO is accessible via `ref.watch(databaseProvider).tripsDao`, etc.
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
