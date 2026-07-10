import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/users_table.dart';
import 'tables/trips_table.dart';
import 'tables/trip_members_table.dart';
import 'tables/cash_pools_table.dart';
import 'tables/expenses_table.dart';
import 'tables/expense_participants_table.dart';
import 'tables/transfers_table.dart';
import 'tables/edit_history_table.dart';
import 'tables/sync_outbox_table.dart';

import 'daos/trips_dao.dart';
import 'daos/expenses_dao.dart';
import 'daos/transfers_dao.dart';
import 'daos/cash_pools_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users, Trips, TripMembers, CashPools,
    Expenses, ExpenseParticipants, Transfers,
    EditHistory, SyncOutbox,
  ],
  daos: [TripsDao, ExpensesDao, TransfersDao, CashPoolsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'triptab.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
