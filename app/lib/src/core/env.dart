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

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const supabaseFunctionsUrl = String.fromEnvironment(
    'SUPABASE_FUNCTIONS_URL',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Edge Function endpoints. Derived from the project URL when not overridden.
  static String get functionsBase {
    if (supabaseFunctionsUrl.isNotEmpty) return supabaseFunctionsUrl;
    return '$supabaseUrl/functions/v1';
  }

  static Uri function(String name) => Uri.parse('$functionsBase/$name');

  /// Public bucket for product imagery.
  static const productImageBucket = 'product-images';
}
