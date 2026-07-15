import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/database.dart';
import 'database_provider.dart';

/// Authentication state — wraps a [LocalUser] and tracks auth mode.
class AuthState {
  final LocalUser? user;
  final bool isGuest;
  /// True while we're still checking for a persisted session on startup.
  final bool isLoading;

  const AuthState({this.user, this.isGuest = false, this.isLoading = false});

  bool get isLoggedIn => user != null;

  AuthState copyWith({LocalUser? user, bool? isGuest, bool? isLoading}) {
    return AuthState(
      user: user ?? this.user,
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Manages authentication via Supabase email/password.
///
/// KEY FIX: starts with `isLoading = true` and completes the async
/// session restore before the router evaluates the auth state.
/// This prevents the flash-to-login bug on cold start.
class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;

  AuthNotifier(this._db) : super(const AuthState(isLoading: true)) {
    _restoreSession();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Try to restore a persisted Supabase session on app startup.
  /// Sets isLoading=false when done (regardless of outcome).
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
          state = AuthState(user: localUser, isGuest: false, isLoading: false);
          return;
        }
      }
    } catch (_) {
      // No session or offline — fall through to logged-out state.
    }
    // Mark loading complete — stays logged out.
    state = const AuthState(isLoading: false);
  }

  /// Sign up with email + password.
  ///
  /// NOTE: Supabase email confirmation is turned OFF in the dashboard
  /// (Authentication > Providers > Email > Confirm email = OFF).
  /// When deployed, enable it and set a redirect URL.
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
      throw Exception(
          'Sign-up failed. If email confirmation is on, check your inbox.');
    }

    final localUser = await _ensureLocalUser(supaUser.id, displayName, email);
    state = AuthState(user: localUser, isGuest: false, isLoading: false);
  }

  /// Sign in with email + password.
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
    state = AuthState(user: localUser, isGuest: false, isLoading: false);
  }

  /// Creates a guest user with a local-only ID (offline mode).
  Future<void> loginAsGuest(String name) async {
    final id = 'guest_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

    // Use insertOnConflictUpdate so re-tapping guest after restart doesn't crash.
    await _db.into(_db.users).insertOnConflictUpdate(
      UsersCompanion.insert(id: id, name: name),
    );

    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals(id)))
        .getSingle();

    state = AuthState(user: user, isGuest: true, isLoading: false);
  }

  /// Sign out — clears both Supabase session and local state.
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Offline sign-out is fine — just clear local state.
    }
    state = const AuthState(isLoading: false);
  }

  /// Ensures a local `users` row exists for the given Supabase user.
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

/// True only once the session-restore check has finished.
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

/// Convenience provider: whether a user is currently logged in.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoggedIn;
});
