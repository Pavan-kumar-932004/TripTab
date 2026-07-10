import 'package:drift/drift.dart';

class TripMembers extends Table {
  TextColumn get tripId => text()();
  TextColumn get userId => text()();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get role => text().withDefault(const Constant('member'))();

  @override
  Set<Column> get primaryKey => {tripId, userId};
}
