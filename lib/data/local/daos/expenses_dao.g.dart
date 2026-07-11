// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expenses_dao.dart';

// ignore_for_file: type=lint
mixin _$ExpensesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExpensesTable get expenses => attachedDatabase.expenses;
  $ExpenseParticipantsTable get expenseParticipants =>
      attachedDatabase.expenseParticipants;
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
  ExpensesDaoManager get managers => ExpensesDaoManager(this);
}

class ExpensesDaoManager {
  final _$ExpensesDaoMixin _db;
  ExpensesDaoManager(this._db);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db.attachedDatabase, _db.expenses);
  $$ExpenseParticipantsTableTableManager get expenseParticipants =>
      $$ExpenseParticipantsTableTableManager(
        _db.attachedDatabase,
        _db.expenseParticipants,
      );
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db.attachedDatabase, _db.syncOutbox);
}
