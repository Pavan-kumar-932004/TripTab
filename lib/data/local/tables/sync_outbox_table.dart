import 'package:drift/drift.dart';

/// Local-only table — not in the SQL migration.
/// Queues writes for sync to Supabase.
@DataClassName('SyncOutboxEntry')
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text()();
  TextColumn get rowId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
