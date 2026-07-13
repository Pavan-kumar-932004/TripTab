import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/database.dart';
import 'database_provider.dart';

/// Authentication state — wraps a [LocalUser] and tracks auth mode.
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

/// Manages authentication via Supabase email/password.
///
/// On launch, checks for an existing Supabase session (persistent login).
/// Falls back to guest mode for offline use.
class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;

  AuthNotifier(this._db) : super(const AuthState()) {
    _restoreSession();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Try to restore a persisted Supabase session on app startup.
  Future<void> _restoreSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        final supaUser = _supabase.auth.currentUser;
        if (supaUser != null) {
          final localUser = await _ensureLocalUser(
            supaUser.id,
            supaUser.userMetadata?['display_name'] as String? ??
                supaUser.email?.split('@').first ??
                'User',
            supaUser.email,
          );
          state = AuthState(user: localUser, isGuest: false);
          return;
        }
      }
    } catch (_) {
      // No session or offline — stay logged out until explicit action.
    }
  }

  /// Sign up with email + password.
  ///
  /// Creates the Supabase auth user, then upserts a row in the local
  /// `users` table with the same UUID as `auth.uid()` for RLS compat.
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final supaUser = response.user;
    if (supaUser == null) {
      throw Exception('Sign-up returned no user. Check email confirmation settings.');
    }

    final localUser = await _ensureLocalUser(
      supaUser.id,
      displayName,
      email,
    );
    state = AuthState(user: localUser, isGuest: false);
  }

  /// Sign in with email + password.
  ///
  /// Supabase persists the session automatically — the user stays
  /// logged in across app restarts until explicit sign-out.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final supaUser = response.user;
    if (supaUser == null) {
      throw Exception('Sign-in failed. Please check your credentials.');
    }

    final localUser = await _ensureLocalUser(
      supaUser.id,
      supaUser.userMetadata?['display_name'] as String? ??
          supaUser.email?.split('@').first ??
          'User',
      supaUser.email,
    );
    state = AuthState(user: localUser, isGuest: false);
  }

  /// Creates a guest user with a local-only UUID (offline mode).
  Future<void> loginAsGuest(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

    await _db.into(_db.users).insert(
      UsersCompanion.insert(id: 'guest_$id', name: name),
    );

    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals('guest_$id')))
        .getSingle();

    state = AuthState(user: user, isGuest: true);
  }

  /// Sign out — clears both Supabase session and local state.
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Offline sign-out is fine — just clear local state.
    }
    state = const AuthState();
  }

  /// Ensures a local `users` row exists for the given Supabase user.
  ///
  /// Uses the Supabase `auth.uid()` as the local PK so that RLS
  /// policies (which compare `auth.uid()` to `users.id`) work correctly.
  Future<LocalUser> _ensureLocalUser(
    String supabaseUid,
    String name,
    String? email,
  ) async {
    final existing = await (_db.select(_db.users)
          ..where((u) => u.id.equals(supabaseUid)))
        .getSingleOrNull();

    if (existing != null) return existing;

    await _db.into(_db.users).insert(
      UsersCompanion.insert(id: supabaseUid, name: name),
    );

    return await (_db.select(_db.users)
          ..where((u) => u.id.equals(supabaseUid)))
        .getSingle();
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
