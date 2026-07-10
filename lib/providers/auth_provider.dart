import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/local/database.dart';
import 'database_provider.dart';

/// Represents the currently authenticated (or guest) user state.
class AuthState {
  final LocalUser? user;
  final bool isGuest;

  const AuthState({this.user, this.isGuest = false});

  bool get isLoggedIn => user != null;

  AuthState copyWith({LocalUser? user, bool? isGuest}) {
    return AuthState(
      user: user ?? this.user,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

/// Manages authentication state.
///
/// Since Supabase credentials are not yet configured, this supports a
/// "guest mode" that creates a local-only user with a client-generated
/// UUID, consistent with the offline-first architecture.
class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;

  AuthNotifier(this._db) : super(const AuthState());

  /// Creates a guest user with the given [name] and persists it locally.
  ///
  /// Generates a client-side UUID (never server auto-increment) per the
  /// project's sync design. The user is written to the local Drift DB
  /// immediately — no network required.
  Future<void> loginAsGuest(String name) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    // Insert a local-only user row via the database.
    // The companion uses the Drift-generated type for the users table.
    await _db.into(_db.users).insert(
      UsersCompanion.insert(
        id: id,
        displayName: name,
        createdAt: now,
      ),
    );

    // Read it back to get the full LocalUser object.
    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals(id)))
        .getSingle();

    state = AuthState(user: user, isGuest: true);
  }

  /// Logs out the current user (clears local state only).
  void logout() {
    state = const AuthState();
  }
}

/// Provides the [AuthNotifier] and its [AuthState].
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthNotifier(db);
});

/// Convenience provider: the current [LocalUser], or null.
final currentUserProvider = Provider<LocalUser?>((ref) {
  return ref.watch(authProvider).user;
});

/// Convenience provider: whether a user is currently logged in.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoggedIn;
});
