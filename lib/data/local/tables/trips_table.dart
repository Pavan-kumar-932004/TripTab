import 'package:drift/drift.dart';

class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get createdBy => text()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
