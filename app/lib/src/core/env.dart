/// Build-time configuration.
///
/// Prefer `./scripts/run-app.sh`, which reads these from the gitignored
/// .env.local. Passing them by hand works too:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// Only the client-safe key belongs here. The secret key and the PayWay API key
/// live in Supabase Edge Function secrets and never ship in the app.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'brand.dart';

class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase's current name for the client-safe key. The legacy
  /// SUPABASE_ANON_KEY name is still accepted so an existing setup keeps working.
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  static const supabaseFunctionsUrl = String.fromEnvironment(
    'SUPABASE_FUNCTIONS_URL',
    defaultValue: '',
  );

  /// Public bucket for product imagery.
  static const productImageBucket = 'product-images';

  /// OAuth returns here after the provider round trip.
  ///
  /// On web the browser lands back on the site. On mobile there is no origin,
  /// so it uses the `sela://` scheme registered in the native projects.
  static String get oauthRedirectUrl {
    if (!kIsWeb) return '${Brand.urlScheme}://auth-callback';
    const site = String.fromEnvironment('SITE_URL', defaultValue: '');
    return site.isEmpty ? 'http://localhost:8080' : site;
  }

  /// Values that appear in the committed launch configs. Treating these as
  /// "configured" produces a 401 on every request, which reads as a broken
  /// backend rather than an unset variable, so they are rejected explicitly.
  static const _placeholders = <String>{
    '',
    'REPLACE_WITH_PUBLISHABLE_KEY',
    'YOUR-PUBLISHABLE-KEY',
    'YOUR_PUBLISHABLE_KEY',
  };

  static bool get isConfigured => configurationProblem == null;

  /// Null when the app can talk to Supabase, otherwise a message to show the
  /// developer. Kept as a pure function of its inputs so it can be unit tested.
  static String? configurationProblemFor({
    required String url,
    required String key,
  }) {
    if (url.trim().isEmpty) {
      return 'SUPABASE_URL is not set.';
    }
    if (url.contains('YOUR-REF') || url.contains('<ref>')) {
      return 'SUPABASE_URL still holds the placeholder "$url".';
    }
    if (key.trim().isEmpty) {
      return 'SUPABASE_PUBLISHABLE_KEY is not set.';
    }
    if (_placeholders.contains(key)) {
      return 'SUPABASE_PUBLISHABLE_KEY still holds the placeholder "$key". '
          'Replace it, or run ./scripts/run-app.sh which reads .env.local.';
    }
    // A privileged key compiled into the bundle hands a full RLS bypass to
    // anyone who extracts it, so refuse rather than start.
    if (key.startsWith('sb_secret_') || key.contains('service_role')) {
      return 'SUPABASE_PUBLISHABLE_KEY looks like a secret key. '
          'It bypasses every RLS policy and must never ship in the app.';
    }
    return null;
  }

  static String? get configurationProblem =>
      configurationProblemFor(url: supabaseUrl, key: supabaseKey);

  /// Edge Function endpoints. Derived from the project URL when not overridden.
  static String get functionsBase {
    if (supabaseFunctionsUrl.isNotEmpty) return supabaseFunctionsUrl;
    return '$supabaseUrl/functions/v1';
  }

  static Uri function(String name) => Uri.parse('$functionsBase/$name');
}
