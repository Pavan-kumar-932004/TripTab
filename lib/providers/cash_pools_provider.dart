import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database.dart';
import 'database_provider.dart';

/// Watches all cash pools for a specific trip.
final tripCashPoolsProvider = StreamProvider.family<List<CashPool>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return db.cashPoolsDao.watchCashPoolsForTrip(tripId);
});
