// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trips_dao.dart';

// ignore_for_file: type=lint
mixin _$TripsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripsTable get trips => attachedDatabase.trips;
  $TripMembersTable get tripMembers => attachedDatabase.tripMembers;
  $UsersTable get users => attachedDatabase.users;
  TripsDaoManager get managers => TripsDaoManager(this);
}

class TripsDaoManager {
  final _$TripsDaoMixin _db;
  TripsDaoManager(this._db);
  $$TripsTableTableManager get trips =>
      $$TripsTableTableManager(_db.attachedDatabase, _db.trips);
  $$TripMembersTableTableManager get tripMembers =>
      $$TripMembersTableTableManager(_db.attachedDatabase, _db.tripMembers);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
}
