import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database.dart';
import 'database_provider.dart';

/// Watches all transfers for a specific trip.
final tripTransfersProvider = StreamProvider.family<List<Transfer>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return db.transfersDao.watchTransfersForTrip(tripId);
});
