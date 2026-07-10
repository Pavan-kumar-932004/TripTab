import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import 'database_provider.dart';

/// Watches expenses for a specific trip as a live stream.
///
/// Usage: `ref.watch(tripExpensesProvider(tripId))`
final tripExpensesProvider =
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return db.expensesDao.watchExpensesForTrip(tripId);
});
