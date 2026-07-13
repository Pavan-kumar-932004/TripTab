import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/trip_invites_table.dart';
import '../tables/trip_members_table.dart';
import '../tables/users_table.dart';
import '../tables/sync_outbox_table.dart';

part 'trip_invites_dao.g.dart';

const _uuid = Uuid();

/// Generates a random 6-character alphanumeric invite code.
String _generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // skip 0/O and 1/I
  final rand = DateTime.now().microsecondsSinceEpoch;
  final buf = StringBuffer();
  var seed = rand;
  for (int i = 0; i < 6; i++) {
    buf.write(chars[seed % chars.length]);
    seed = (seed ~/ chars.length) + DateTime.now().microsecond;
  }
  return buf.toString();
}

@DriftAccessor(tables: [TripInvites, TripMembers, Users, SyncOutbox])
class TripInvitesDao extends DatabaseAccessor<AppDatabase>
    with _$TripInvitesDaoMixin {
  TripInvitesDao(super.db);

  /// Create a new invite code for [tripId].
  ///
  /// Returns the invite code string. The code expires in 7 days
  /// and has a max of 50 uses.
  Future<String> createInvite({
    required String tripId,
    required String createdBy,
  }) async {
    final code = _generateCode();
    final id = _uuid.v4();

    await into(tripInvites).insert(
      TripInvitesCompanion.insert(
        id: id,
        tripId: tripId,
        inviteCode: code,
        createdBy: createdBy,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    );

    return code;
  }

  /// Look up an invite by [code]. Returns null if not found or expired.
  Future<TripInvite?> getInviteByCode(String code) async {
    return (select(tripInvites)
          ..where((i) =>
              i.inviteCode.equals(code.toUpperCase()) &
              i.expiresAt.isBiggerThanValue(DateTime.now())))
        .getSingleOrNull();
  }

  /// Join a trip using [code]. Returns the trip ID on success.
  ///
  /// Throws if the code is invalid, expired, or usage limit is reached.
  Future<String> joinByCode({
    required String code,
    required String userId,
  }) async {
    final invite = await getInviteByCode(code);
    if (invite == null) {
      throw Exception('Invalid or expired invite code.');
    }
    if (invite.useCount >= invite.maxUses) {
      throw Exception('This invite link has reached its usage limit.');
    }

    return transaction(() async {
      // Add user to trip_members (no-op if already a member).
      await into(tripMembers).insertOnConflictUpdate(
        TripMembersCompanion.insert(
          tripId: invite.tripId,
          userId: userId,
        ),
      );

      // Increment use count.
      await (update(tripInvites)..where((i) => i.id.equals(invite.id))).write(
        TripInvitesCompanion(useCount: Value(invite.useCount + 1)),
      );

      // Queue sync.
      await into(syncOutbox).insert(SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'trip_members',
        rowId: '${invite.tripId}_$userId',
        operation: 'insert',
        payload: '',
      ));

      return invite.tripId;
    });
  }

  /// Watch all invites for a trip (for displaying in trip settings).
  Stream<List<TripInvite>> watchInvitesForTrip(String tripId) {
    return (select(tripInvites)
          ..where((i) => i.tripId.equals(tripId))
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .watch();
  }
}
