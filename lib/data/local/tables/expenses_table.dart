import 'package:drift/drift.dart';

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get loggedBy => text()();
  TextColumn get fundedByUser => text().nullable()();
  TextColumn get fundedByCashPool => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get splitType => text().withDefault(const Constant('equal'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get paymentAt => dateTime()();
  DateTimeColumn get entryAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get originDeviceId => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
