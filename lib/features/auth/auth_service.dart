import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/models.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<UserRole> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return resolveCurrentUserRole();
  }

  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim(), 'role': role.name},
    );

    return response.session != null;
  }

  Future<void> signInWithGoogle() async {
    final opened = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.memora://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const AuthException('Unable to open Google sign-in.');
    }
  }

  Future<UserRole> resolveCurrentUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user was found.');
    }

    final patient = await _client
        .from('patients')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (patient != null) return UserRole.patient;

    final caregiver = await _client
        .from('caregivers')
        .select('id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (caregiver != null) return UserRole.caregiver;

    throw const AuthException(
      'Your account setup is incomplete. Please contact support.',
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

String readableAuthError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Something went wrong. Please try again.';
}
