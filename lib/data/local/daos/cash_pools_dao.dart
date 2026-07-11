import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/cash_pools_table.dart';
import '../tables/sync_outbox_table.dart';

part 'cash_pools_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [CashPools, SyncOutbox])
class CashPoolsDao extends DatabaseAccessor<AppDatabase>
    with _$CashPoolsDaoMixin {
  CashPoolsDao(super.db);

  /// Watch non-deleted cash pools for a trip.
  Stream<List<CashPool>> watchCashPoolsForTrip(String tripId) {
    return (select(cashPools)
          ..where((c) => c.tripId.equals(tripId) & c.deletedAt.isNull()))
        .watch();
  }

  /// Create a cash pool and queue it for sync, in one transaction.
  Future<void> createCashPool(CashPoolsCompanion pool) {
    return transaction(() async {
      await into(cashPools).insert(pool);

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'cash_pools',
        rowId: pool.id.value,
        operation: 'insert',
        payload: '', // Populated by sync worker from the actual row
      ));
    });
  }

  /// Update the remaining amount on a cash pool.
  Future<void> updateRemainingMinor(String id, int newRemaining) {
    return (update(cashPools)..where((c) => c.id.equals(id))).write(
      CashPoolsCompanion(remainingMinor: Value(newRemaining)),
    );
  }
}
