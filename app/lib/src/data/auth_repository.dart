import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

/// Which sign-in methods the project actually has switched on.
///
/// Read from Supabase's public `/auth/v1/settings` endpoint rather than
/// hard-coded, so enabling Google in the dashboard makes the button appear
/// without shipping a new build. It also means we never show a button that
/// fails with "provider is not enabled".
class AuthCapabilities {
  const AuthCapabilities({
    required this.email,
    required this.google,
    required this.facebook,
    required this.apple,
  });

  final bool email;
  final bool google;
  final bool facebook;
  final bool apple;

  static const fallback = AuthCapabilities(
    email: true,
    google: false,
    facebook: false,
    apple: false,
  );

  bool get hasSocial => google || facebook || apple;
}

/// Deliberately permissive. We only catch the obvious mistakes, like a missing
/// `@` — the one that actually happened — and let Supabase be the authority.
/// Over-strict client regexes reject addresses that are perfectly valid.
final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isLikelyEmail(String value) => _emailShape.hasMatch(value.trim());

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Public endpoint: no key beyond the publishable one, no user required.
  Future<AuthCapabilities> capabilities() async {
    try {
      final res = await http.get(
        Uri.parse('${Env.supabaseUrl}/auth/v1/settings'),
        headers: {'apikey': Env.supabaseKey},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return AuthCapabilities.fallback;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final external = (body['external'] as Map?)?.cast<String, dynamic>() ?? {};

      bool on(String key) => external[key] == true;

      return AuthCapabilities(
        email: on('email'),
        google: on('google'),
        facebook: on('facebook'),
        apple: on('apple'),
      );
    } catch (_) {
      return AuthCapabilities.fallback;
    }
  }

  /// Web/desktop redirects in the same tab; on mobile Supabase opens a browser
  /// and returns via the `sela://` scheme registered in the native projects.
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Env.oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
      scopes: 'email profile',
    );
  }

  Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      // Deep link straight back into the app so the code can be auto-filled.
      emailRedirectTo: Env.oauthRedirectUrl,
    );
  }

  Future<void> verifyOtp({required String email, required String token}) async {
    await _client.auth.verifyOTP(
      type: OtpType.email,
      email: email,
      token: token,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
