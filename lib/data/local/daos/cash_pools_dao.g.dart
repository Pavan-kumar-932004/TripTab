// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_pools_dao.dart';

// ignore_for_file: type=lint
mixin _$CashPoolsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CashPoolsTable get cashPools => attachedDatabase.cashPools;
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
  CashPoolsDaoManager get managers => CashPoolsDaoManager(this);
}

class CashPoolsDaoManager {
  final _$CashPoolsDaoMixin _db;
  CashPoolsDaoManager(this._db);
  $$CashPoolsTableTableManager get cashPools =>
      $$CashPoolsTableTableManager(_db.attachedDatabase, _db.cashPools);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db.attachedDatabase, _db.syncOutbox);
}
