import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import 'database_provider.dart';

/// Watches [TripMember] rows for a specific trip as a live stream.
///
/// Usage: `ref.watch(tripMembersProvider(tripId))`
final tripMembersProvider =
    StreamProvider.family<List<TripMember>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return db.tripsDao.watchTripMembers(tripId);
});

/// Watches the resolved [LocalUser] objects for all members of a trip.
///
/// This joins trip_members → users to provide display names, avatars, etc.
/// Usage: `ref.watch(tripMemberUsersProvider(tripId))`
final tripMemberUsersProvider =
    StreamProvider.family<List<LocalUser>, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  return db.tripsDao.watchTripMemberUsers(tripId);
});
