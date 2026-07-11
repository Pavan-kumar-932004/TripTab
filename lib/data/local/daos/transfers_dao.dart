import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/transfers_table.dart';
import '../tables/sync_outbox_table.dart';

part 'transfers_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Transfers, SyncOutbox])
class TransfersDao extends DatabaseAccessor<AppDatabase>
    with _$TransfersDaoMixin {
  TransfersDao(super.db);

  /// Watch non-deleted transfers for a trip.
  Stream<List<Transfer>> watchTransfersForTrip(String tripId) {
    return (select(transfers)
          ..where((t) => t.tripId.equals(tripId) & t.deletedAt.isNull()))
        .watch();
  }

  /// Create a transfer and queue it for sync, in one transaction.
  Future<void> createTransfer(TransfersCompanion transfer) {
    return transaction(() async {
      await into(transfers).insert(transfer);

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'transfers',
        rowId: transfer.id.value,
        operation: 'insert',
        payload: '', // Populated by sync worker from the actual row
      ));
    });
  }

  /// Soft-delete a transfer by setting deletedAt.
  Future<void> softDeleteTransfer(String id) {
    return (update(transfers)..where((t) => t.id.equals(id))).write(
      TransfersCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
