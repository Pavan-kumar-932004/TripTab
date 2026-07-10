import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/trips_table.dart';
import '../tables/trip_members_table.dart';
import '../tables/users_table.dart';

part 'trips_dao.g.dart';

@DriftAccessor(tables: [Trips, TripMembers, Users])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  /// Watch all non-deleted trips, newest first.
  Stream<List<Trip>> watchAllTrips() {
    return (select(trips)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Get a single trip by ID, or null if not found.
  Future<Trip?> getTrip(String id) {
    return (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new trip.
  Future<void> createTrip(TripsCompanion trip) {
    return into(trips).insert(trip);
  }

  /// Update a trip by ID.
  Future<void> updateTrip(String id, TripsCompanion companion) {
    return (update(trips)..where((t) => t.id.equals(id))).write(companion);
  }

  /// Soft-delete a trip by setting deletedAt.
  Future<void> softDeleteTrip(String id) {
    return (update(trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// Add a member to a trip.
  Future<void> addMember(TripMembersCompanion member) {
    return into(tripMembers).insert(member);
  }

  /// Watch all members for a given trip.
  Stream<List<TripMember>> watchTripMembers(String tripId) {
    return (select(tripMembers)..where((m) => m.tripId.equals(tripId)))
        .watch();
  }

  /// Watch user profiles for all members of a trip (join trip_members + users).
  Stream<List<LocalUser>> watchTripMemberUsers(String tripId) {
    final query = select(users).join([
      innerJoin(tripMembers, tripMembers.userId.equalsExp(users.id)),
    ])
      ..where(tripMembers.tripId.equals(tripId));

    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(users)).toList();
    });
  }
}
