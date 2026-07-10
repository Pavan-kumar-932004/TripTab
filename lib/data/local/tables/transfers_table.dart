import 'package:drift/drift.dart';

class Transfers extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get fromUser => text()();
  TextColumn get toUser => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get type => text()();
  TextColumn get relatedPoolId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get paymentAt => dateTime()();
  DateTimeColumn get entryAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get originDeviceId => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
