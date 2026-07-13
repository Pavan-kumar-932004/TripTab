import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import 'database_provider.dart';

/// Watches all trips from the local database as a live stream.
final allTripsProvider = StreamProvider<List<Trip>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.tripsDao.watchAllTrips();
});

/// Holds the currently selected/viewed trip ID.
final selectedTripIdProvider = StateProvider<String?>((ref) => null);

/// Derives the selected [Trip] from the current trip list and selected ID.
///
/// Returns null if no trip is selected or the trip isn't found.
final selectedTripProvider = Provider<Trip?>((ref) {
  final tripId = ref.watch(selectedTripIdProvider);
  if (tripId == null) return null;

  final tripsAsync = ref.watch(allTripsProvider);
  return tripsAsync.whenData((trips) {
    try {
      return trips.firstWhere((t) => t.id == tripId);
    } catch (_) {
      return null;
    }
  }).value;
});

/// Watches a single trip by ID.
final tripByIdProvider = StreamProvider.family<Trip?, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.trips)..where((t) => t.id.equals(tripId))).watchSingleOrNull();
});
