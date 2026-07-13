// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_invites_dao.dart';

// ignore_for_file: type=lint
mixin _$TripInvitesDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripInvitesTable get tripInvites => attachedDatabase.tripInvites;
  $TripMembersTable get tripMembers => attachedDatabase.tripMembers;
  $UsersTable get users => attachedDatabase.users;
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
  TripInvitesDaoManager get managers => TripInvitesDaoManager(this);
}

class TripInvitesDaoManager {
  final _$TripInvitesDaoMixin _db;
  TripInvitesDaoManager(this._db);
  $$TripInvitesTableTableManager get tripInvites =>
      $$TripInvitesTableTableManager(_db.attachedDatabase, _db.tripInvites);
  $$TripMembersTableTableManager get tripMembers =>
      $$TripMembersTableTableManager(_db.attachedDatabase, _db.tripMembers);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db.attachedDatabase, _db.syncOutbox);
}
