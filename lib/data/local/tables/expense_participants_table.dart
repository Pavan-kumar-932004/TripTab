import 'package:drift/drift.dart';

class ExpenseParticipants extends Table {
  TextColumn get expenseId => text()();
  TextColumn get userId => text()();
  IntColumn get shareMinor => integer()();

  @override
  Set<Column> get primaryKey => {expenseId, userId};
}
