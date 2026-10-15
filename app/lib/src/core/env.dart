/// Build-time configuration.
///
/// Pass with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Only the anon key belongs here. The service role key and the PayWay API key
/// live in Supabase Edge Function secrets and are never shipped in the app.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase's current name for the client-safe key. The legacy
  /// SUPABASE_ANON_KEY name is still accepted so existing setup keeps working.
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static const supabaseFunctionsUrl = String.fromEnvironment(
    'SUPABASE_FUNCTIONS_URL',
    defaultValue: '',
  );

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Edge Function endpoints. Derived from the project URL when not overridden.
  static String get functionsBase {
    if (supabaseFunctionsUrl.isNotEmpty) return supabaseFunctionsUrl;
    return '$supabaseUrl/functions/v1';
  }

  static Uri function(String name) => Uri.parse('$functionsBase/$name');

  /// Public bucket for product imagery.
  static const productImageBucket = 'product-images';
}
