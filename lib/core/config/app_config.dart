class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  /// OAuth client ID of the "Web application" client in Google Cloud. When
  /// set, Android uses the native Google account picker; otherwise Google
  /// sign-in falls back to the browser flow.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const careTimezone = String.fromEnvironment(
    'CARE_TIMEZONE',
    defaultValue: 'Asia/Kolkata',
  );

  static bool get hasSupabaseConfiguration =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  const AppConfig._();
}
