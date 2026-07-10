import 'package:drift/drift.dart';

@DataClassName('EditHistoryEntry')
class EditHistory extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get editedBy => text()();
  DateTimeColumn get editedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get oldValue => text()();
  TextColumn get newValue => text()();

  @override
  Set<Column> get primaryKey => {id};
}
