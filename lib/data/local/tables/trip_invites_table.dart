import 'package:drift/drift.dart';

/// Local mirror of the `trip_invites` table.
///
/// Stores invite codes that allow new users to join a trip via QR,
/// share link, or manual code entry.
class TripInvites extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get inviteCode => text()(); // 6-char alphanumeric
  TextColumn get createdBy => text()();
  DateTimeColumn get expiresAt => dateTime()();
  IntColumn get maxUses => integer().withDefault(const Constant(50))();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
