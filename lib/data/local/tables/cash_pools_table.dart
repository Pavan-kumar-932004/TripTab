import 'package:drift/drift.dart';

class CashPools extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get fromUser => text()();
  TextColumn get heldByUser => text()();
  IntColumn get amountMinor => integer()();
  IntColumn get remainingMinor => integer()();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
