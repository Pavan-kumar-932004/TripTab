import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/expenses_table.dart';
import '../tables/expense_participants_table.dart';
import '../tables/sync_outbox_table.dart';

part 'expenses_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Expenses, ExpenseParticipants, SyncOutbox])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  /// Watch non-deleted expenses for a trip, newest payment first.
  Stream<List<Expense>> watchExpensesForTrip(String tripId) {
    return (select(expenses)
          ..where((e) => e.tripId.equals(tripId) & e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.paymentAt)]))
        .watch();
  }

  /// Create an expense with its participants and an outbox entry, all in one
  /// transaction. Validates the funded_by mutual-exclusion constraint that
  /// the SQL schema enforces via CHECK.
  Future<void> createExpenseWithParticipants(
    ExpensesCompanion expense,
    List<ExpenseParticipantsCompanion> participants,
  ) {
    return transaction(() async {
      // Enforce mutual exclusion: at most one of fundedByUser / fundedByCashPool
      final hasFundedByUser = expense.fundedByUser.present &&
          expense.fundedByUser.value != null;
      final hasFundedByCashPool = expense.fundedByCashPool.present &&
          expense.fundedByCashPool.value != null;
      if (hasFundedByUser && hasFundedByCashPool) {
        throw ArgumentError(
          'An expense cannot have both fundedByUser and fundedByCashPool set.',
        );
      }

      await into(expenses).insert(expense);

      for (final participant in participants) {
        await into(expenseParticipants).insert(participant);
      }

      // Queue for sync
      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        tableName: 'expenses',
        rowId: expense.id.value,
        operation: 'insert',
        payload: '', // Populated by sync worker from the actual row
      ));
    });
  }

  /// Soft-delete an expense by setting deletedAt.
  Future<void> softDeleteExpense(String id) {
    return (update(expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// Watch participants for a specific expense.
  Stream<List<ExpenseParticipant>> watchParticipantsForExpense(
      String expenseId) {
    return (select(expenseParticipants)
          ..where((p) => p.expenseId.equals(expenseId)))
        .watch();
  }
}
