import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show
        GoogleSignIn,
        GoogleSignInAccount,
        GoogleSignInException,
        GoogleSignInExceptionCode;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';

class AuthService {
  AuthService(this._client);

  static const googleCallbackUrl = 'io.supabase.memora://login-callback';
  static const passwordRecoveryCallbackUrl =
      'io.supabase.memora://reset-password';

  final SupabaseClient _client;

  static Future<void>? _googleInitialization;

  /// Android uses the native account picker when the web client ID is
  /// configured. The web build and iOS use Supabase's browser flow.
  static bool get _useNativeGoogleSignIn =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      AppConfig.googleWebClientId.trim().isNotEmpty;

  /// On the web, Supabase returns to the page the app is served from.
  static String get _webRedirectUrl => Uri.base.origin;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// Returns null when the account still needs to choose a role.
  Future<UserRole?> signInWithPassword({
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
      // The confirmation link in the email opens the app and signs in.
      emailRedirectTo: kIsWeb ? _webRedirectUrl : googleCallbackUrl,
    );

    return response.session != null;
  }

  Future<void> signInWithGoogle() async {
    if (_useNativeGoogleSignIn) {
      await _signInWithGoogleNative();
      return;
    }
    final opened = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? _webRedirectUrl : googleCallbackUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const AuthException('Unable to open Google sign-in.');
    }
  }

  Future<void> _signInWithGoogleNative() async {
    final googleSignIn = GoogleSignIn.instance;
    await (_googleInitialization ??= googleSignIn.initialize(
      serverClientId: AppConfig.googleWebClientId.trim(),
    ));

    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (error) {
      // Closing the account picker is not an error worth showing.
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      throw AuthException(
        error.description ?? 'Google sign-in failed. Please try again.',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
        'Google sign-in is not configured correctly. Check the web client ID.',
      );
    }
    final authorization = await account.authorizationClient
        .authorizationForScopes(const ['email', 'profile']);
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );
  }

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? _webRedirectUrl : passwordRecoveryCallbackUrl,
      );

  Future<void> updatePassword(String password) async {
    if (_client.auth.currentSession == null) {
      throw const AuthException(
        'This password reset link is invalid or has expired. Request a new one.',
      );
    }
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  /// The role chosen at sign-up, for use when the database cannot be reached.
  /// Mirrors handle_new_auth_user, which makes every account without the
  /// patient role a caregiver.
  UserRole? get roleFromAccountMetadata {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final role = (user.userMetadata?['role'] as String?)?.trim().toLowerCase();
    return role == UserRole.patient.name
        ? UserRole.patient
        : UserRole.caregiver;
  }

  /// The account's role, or null if it has not chosen one yet.
  Future<UserRole?> resolveCurrentUserRole() async {
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

    return null;
  }

  /// Makes the signed-in account a patient or a caregiver. The backend keeps
  /// an existing role, so the returned role may differ from [role].
  Future<UserRole> chooseRole(UserRole role) async {
    final chosen = await _client.rpc<String>(
      'choose_account_role',
      params: {'selected_role': role.name},
    );
    return chosen == UserRole.patient.name
        ? UserRole.patient
        : UserRole.caregiver;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    // Forget the Google account too, so the picker appears on next sign-in.
    if (_googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Google sign-out failed: $error');
      }
    }
  }
}

String readableAuthError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Something went wrong. Please try again.';
}
