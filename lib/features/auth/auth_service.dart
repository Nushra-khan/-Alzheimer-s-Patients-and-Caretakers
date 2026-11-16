import 'dart:async';

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
    final response = await _withTimeout(
      _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim(), 'role': role.name},
        // The confirmation link in the email opens the app and signs in.
        emailRedirectTo: kIsWeb ? _webRedirectUrl : googleCallbackUrl,
      ),
    );

    // With email confirmation on, Supabase hides whether an address is
    // already registered by returning a user with no identities and no
    // session. Tell the person instead of waiting for an email that never
    // comes.
    final identities = response.user?.identities;
    if (response.session == null && identities != null && identities.isEmpty) {
      throw const AuthException(
        'An account with this email already exists. Log in instead.',
        code: 'user_already_exists',
      );
    }

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
      final description = error.description ?? '';
      debugPrint('Google sign-in failed: ${error.code} $description');
      // Android also reports setup problems (wrong SHA-1, package name or
      // client ID) as "canceled", so only stay quiet when the person really
      // closed the account picker.
      final closedByUser =
          error.code == GoogleSignInExceptionCode.canceled &&
          (description.isEmpty ||
              description.toLowerCase().contains('cancel')) &&
          !_looksLikeGoogleSetupProblem(description);
      if (closedByUser) return;
      throw AuthException(_googleErrorMessage(error.code, description));
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

  Future<void> sendPasswordReset(String email) => _withTimeout(
    _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? _webRedirectUrl : passwordRecoveryCallbackUrl,
    ),
  );

  Future<void> updatePassword(String password) async {
    if (_client.auth.currentSession == null) {
      throw const AuthException(
        'This password reset link is invalid or has expired. Request a new one.',
      );
    }
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  static bool _looksLikeGoogleSetupProblem(String description) {
    final text = description.toLowerCase();
    return text.contains('developer console') ||
        text.contains('28444') ||
        text.contains('developer_error') ||
        text.contains('not set up') ||
        text.contains('misconfigured') ||
        text.contains('client id');
  }

  static String _googleErrorMessage(
    GoogleSignInExceptionCode code,
    String description,
  ) {
    if (code == GoogleSignInExceptionCode.clientConfigurationError ||
        code == GoogleSignInExceptionCode.providerConfigurationError ||
        _looksLikeGoogleSetupProblem(description)) {
      return 'Google sign-in is not set up for this version of the app. '
          'Check the Android OAuth client (package name and SHA-1) in '
          'Google Cloud.';
    }
    return switch (code) {
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in could not open. Please try again.',
      _ =>
        description.isEmpty
            ? 'Google sign-in did not finish. Please try again.'
            : 'Google sign-in failed: $description',
    };
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

  Future<void> resendConfirmation(String email) => _withTimeout(
    _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: kIsWeb ? _webRedirectUrl : googleCallbackUrl,
    ),
  );

  /// Requests that send an email wait on the mail server; never let the
  /// spinner run forever when it is slow or broken.
  static Future<T> _withTimeout<T>(Future<T> request) => request.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw const AuthException(
      'The server took too long to respond. Check your internet and try '
      'again.',
      code: 'request_timeout',
    ),
  );

  /// True for accounts that sign in with email and password (Google
  /// accounts have no Memora password to change).
  bool get isEmailAccount {
    final metadata = _client.auth.currentUser?.appMetadata ?? const {};
    final providers = metadata['providers'];
    if (providers is List) return providers.contains('email');
    return metadata['provider'] == 'email';
  }

  Future<void> changePassword(String newPassword) => _withTimeout(
    _client.auth.updateUser(UserAttributes(password: newPassword)),
  );

  /// Permanently deletes the signed-in account. Photos are removed from
  /// storage first, because Supabase does not allow deleting them from SQL.
  /// Returns the deleted role ('patient', 'caregiver' or 'unassigned').
  Future<String> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in again to delete your account.');
    }
    try {
      final bucket = _client.storage.from('profile-photos');
      final files = await bucket.list(path: user.id);
      if (files.isNotEmpty) {
        await bucket.remove([
          for (final file in files) '${user.id}/${file.name}',
        ]);
      }
    } catch (error) {
      // A leftover photo must not block deletion; it is unreachable once
      // the account is gone.
      debugPrint('Photo cleanup before deletion failed: $error');
    }
    final role = await _withTimeout(
      _client.rpc<String>('delete_my_account'),
    );
    await signOut();
    return role;
  }

  Future<void> signOut() async {
    try {
      // Clears the session on this phone first; only the server call can
      // fail (for example, offline), which must not block signing out.
      await _client.auth.signOut();
    } catch (error) {
      debugPrint('Server sign-out failed: $error');
    }
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
  final message = _readableAuthError(error);
  // While testing (debug builds only), show the technical details too, so
  // problems can be traced. Release builds show the friendly text alone.
  if (!kDebugMode) return message;
  final detail = switch (error) {
    AuthException(:final code, :final statusCode, message: final raw) =>
      '${code ?? statusCode ?? 'auth'}: $raw',
    PostgrestException(:final code, message: final raw) =>
      '${code ?? 'db'}: $raw',
    _ => error.toString(),
  };
  return detail.trim().isEmpty || message.contains(detail)
      ? message
      : '$message\n[$detail]';
}

String _readableAuthError(Object error) {
  if (error is AuthException) {
    final String? message = switch (error.code) {
      'invalid_credentials' => 'Wrong email or password.',
      'email_not_confirmed' =>
        'Please confirm your email first. Check your inbox for the Memora '
            'email.',
      'user_already_exists' || 'email_exists' =>
        'An account with this email already exists. Log in instead.',
      'weak_password' => 'Choose a stronger password (at least 8 characters).',
      'same_password' => 'Choose a password different from your old one.',
      'over_email_send_rate_limit' =>
        'Too many emails were sent. Wait a few minutes and try again.',
      'over_request_rate_limit' =>
        'Too many attempts. Wait a minute and try again.',
      'reauthentication_needed' =>
        'For your security, sign out and sign in again, then change your '
            'password.',
      'request_timeout' =>
        'The server took too long to respond. Check your internet and try '
            'again.',
      'signup_disabled' => 'New sign-ups are turned off right now.',
      'otp_expired' ||
      'flow_state_expired' ||
      'flow_state_not_found' ||
      'bad_code_verifier' => 'This link has expired. Request a new one.',
      _ => null,
    };
    if (message != null) return message;
    final lower = error.message.toLowerCase();
    if (lower.contains('sending') && lower.contains('email')) {
      return "We couldn't send the email. The app's email settings need "
          'checking. Please try again later.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many emails were sent. Wait a while and try again.';
    }
    if (error is AuthRetryableFetchException) return _offlineMessage;
    if (error.message.contains('Invalid login credentials')) {
      return 'Wrong email or password.';
    }
    return error.message;
  }
  if (error is PostgrestException) return error.message;
  if (_looksOffline(error)) return _offlineMessage;
  return 'Something went wrong. Please try again.';
}

const _offlineMessage =
    'No internet connection. Check your network and try again.';

bool _looksOffline(Object error) {
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup');
}
