import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/users_table.dart';
import 'tables/trips_table.dart';
import 'tables/trip_members_table.dart';
import 'tables/trip_invites_table.dart';
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
import 'daos/trip_invites_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users, Trips, TripMembers, TripInvites, CashPools,
    Expenses, ExpenseParticipants, Transfers,
    EditHistory, SyncOutbox,
  ],
  daos: [TripsDao, ExpensesDao, TransfersDao, CashPoolsDao, TripInvitesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // trip_invites was added in schema v2.
        // Drop first in case it was created with a wrong schema by an
        // earlier onCreate that predated the TripInvites table definition.
        await customStatement('DROP TABLE IF EXISTS trip_invites');
        await m.createTable(tripInvites);
      }
      if (from < 3) {
        // Schema v3: fix trip_invites that may have been created without
        // the invite_code column (schema v2 bug on existing installs).
        await customStatement('DROP TABLE IF EXISTS trip_invites');
        await m.createTable(tripInvites);
      }
    },
  );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'triptab.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
