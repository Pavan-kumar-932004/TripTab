import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/expenses_table.dart';
import '../tables/expense_participants_table.dart';
import '../tables/sync_outbox_table.dart';
import '../tables/cash_pools_table.dart';

part 'expenses_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Expenses, ExpenseParticipants, SyncOutbox, CashPools])
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

      if (hasFundedByCashPool && expense.amountMinor.present) {
        final poolId = expense.fundedByCashPool.value!;
        final pool = await (select(cashPools)..where((c) => c.id.equals(poolId))).getSingle();
        final newRemaining = pool.remainingMinor - expense.amountMinor.value;
        await (update(cashPools)..where((c) => c.id.equals(poolId)))
            .write(CashPoolsCompanion(remainingMinor: Value(newRemaining)));
      }

      // Queue for sync
      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'expenses',
        rowId: expense.id.value,
        operation: 'insert',
        payload: '', // Populated by sync worker from the actual row
      ));
    });
  }

  /// Update an existing expense and its participants.
  Future<void> updateExpenseWithParticipants(
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

      // Query the old expense to handle cash pool balance adjustment
      final oldExpense = await (select(expenses)..where((e) => e.id.equals(expense.id.value))).getSingle();

      await update(expenses).replace(expense);

      // Simple approach for participants: delete old and insert new
      await (delete(expenseParticipants)..where((p) => p.expenseId.equals(expense.id.value))).go();
      for (final participant in participants) {
        await into(expenseParticipants).insert(participant);
      }

      // Handle Cash Pool remaining balance adjustment
      final oldPoolId = oldExpense.fundedByCashPool;
      final newPoolId = expense.fundedByCashPool.present ? expense.fundedByCashPool.value : oldExpense.fundedByCashPool;
      
      if (oldPoolId != null && oldPoolId != newPoolId) {
        // Was funded by pool, now funded by different pool or user. Refund old pool.
        final oldPool = await (select(cashPools)..where((c) => c.id.equals(oldPoolId))).getSingle();
        await (update(cashPools)..where((c) => c.id.equals(oldPoolId)))
            .write(CashPoolsCompanion(remainingMinor: Value(oldPool.remainingMinor + oldExpense.amountMinor)));
      }
      
      if (newPoolId != null && expense.amountMinor.present) {
        if (oldPoolId == newPoolId) {
          // Same pool, just adjust the delta
          final pool = await (select(cashPools)..where((c) => c.id.equals(newPoolId))).getSingle();
          final delta = expense.amountMinor.value - oldExpense.amountMinor;
          await (update(cashPools)..where((c) => c.id.equals(newPoolId)))
              .write(CashPoolsCompanion(remainingMinor: Value(pool.remainingMinor - delta)));
        } else {
          // New pool, subtract the new amount
          final pool = await (select(cashPools)..where((c) => c.id.equals(newPoolId))).getSingle();
          await (update(cashPools)..where((c) => c.id.equals(newPoolId)))
              .write(CashPoolsCompanion(remainingMinor: Value(pool.remainingMinor - expense.amountMinor.value)));
        }
      }

      // Queue for sync
      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'expenses',
        rowId: expense.id.value,
        operation: 'update',
        payload: '',
      ));
    });
  }

  /// Soft-delete an expense by setting deletedAt.
  Future<void> softDeleteExpense(String id) {
    return transaction(() async {
      final expense = await (select(expenses)..where((e) => e.id.equals(id))).getSingle();
      
      if (expense.fundedByCashPool != null) {
        final poolId = expense.fundedByCashPool!;
        final pool = await (select(cashPools)..where((c) => c.id.equals(poolId))).getSingle();
        await (update(cashPools)..where((c) => c.id.equals(poolId)))
            .write(CashPoolsCompanion(remainingMinor: Value(pool.remainingMinor + expense.amountMinor)));
      }

      await (update(expenses)..where((e) => e.id.equals(id))).write(
        ExpensesCompanion(deletedAt: Value(DateTime.now())),
      );

      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'expenses',
        rowId: id,
        operation: 'update',
        payload: '',
      ));
    });
  }

  /// Watch participants for a specific expense.
  Stream<List<ExpenseParticipant>> watchParticipantsForExpense(
      String expenseId) {
    return (select(expenseParticipants)
          ..where((p) => p.expenseId.equals(expenseId)))
        .watch();
  }

  /// Get all participants for all non-deleted expenses in a trip.
  ///
  /// Used by the settlement algorithm to compute per-user shares
  /// across the entire trip in a single query batch.
  Future<List<ExpenseParticipant>> getParticipantsForTrip(String tripId) async {
    final tripExpenses = await (select(expenses)
          ..where((e) => e.tripId.equals(tripId) & e.deletedAt.isNull()))
        .get();
    final expenseIds = tripExpenses.map((e) => e.id).toList();
    if (expenseIds.isEmpty) return [];
    return (select(expenseParticipants)
          ..where((p) => p.expenseId.isIn(expenseIds)))
        .get();
  }
}
