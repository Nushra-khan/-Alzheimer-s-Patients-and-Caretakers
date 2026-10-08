class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const careTimezone = String.fromEnvironment(
    'CARE_TIMEZONE',
    defaultValue: 'Asia/Kolkata',
  );

  static bool get hasSupabaseConfiguration =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  const AppConfig._();
}
