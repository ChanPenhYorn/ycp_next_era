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

/// Matches `auth.minimum_password_length` in `supabase/config.toml`, and the
/// `passwordMinLength` wording in the form. Supabase is still the authority:
/// this only lets the form explain the rule before a round trip.
const passwordMinLength = 8;

enum PasswordProblem { tooShort, needsLower, needsUpper, needsDigit }

/// The first rule [value] breaks, or null when it satisfies all of them.
///
/// One at a time on purpose: a list of four red lines for one typed password
/// reads as a scolding, while the next single fix is actionable.
PasswordProblem? passwordProblem(String value) {
  if (value.length < passwordMinLength) return PasswordProblem.tooShort;
  if (!RegExp(r'[a-z]').hasMatch(value)) return PasswordProblem.needsLower;
  if (!RegExp(r'[A-Z]').hasMatch(value)) return PasswordProblem.needsUpper;
  if (!RegExp(r'[0-9]').hasMatch(value)) return PasswordProblem.needsDigit;
  return null;
}

/// 0 to 3, for the strength bar: length, then two kinds of variety.
///
/// Deliberately not a "real" strength meter. Scoring entropy needs a breach
/// list and a dictionary, and a bar that lies about `password123` being strong
/// is worse than an honest coarse one.
int passwordScore(String value) {
  if (value.isEmpty) return 0;
  var score = value.length >= passwordMinLength ? 1 : 0;
  if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
    score++;
  }
  if (RegExp(r'[0-9]').hasMatch(value) || RegExp(r'[^\w\s]').hasMatch(value)) {
    score++;
  }
  return score.clamp(0, 3);
}

/// Referral codes are the first eight characters of the user id, uppercased, so
/// they are always hex. Checked client-side only to catch a pasted link or a
/// truncated code before the RPC does.
final _referralShape = RegExp(r'^[0-9A-F]{8}$');

bool isLikelyReferralCode(String value) =>
    _referralShape.hasMatch(value.trim().toUpperCase());

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Public endpoint: no key beyond the publishable one, no user required.
  Future<AuthCapabilities> capabilities() async {
    try {
      final res = await http
          .get(
            Uri.parse('${Env.supabaseUrl}/auth/v1/settings'),
            headers: {'apikey': Env.supabaseKey},
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return AuthCapabilities.fallback;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final external =
          (body['external'] as Map?)?.cast<String, dynamic>() ?? {};

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
  /// and returns via the `chanpenh://` scheme registered in the native projects.
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

  // ---------------------------------------------------------------------------
  // Email + password accounts
  //
  // Passwords are one of three ways in; the emailed code above stays available
  // as a fallback, because the project's mailer is the only thing that can
  // deliver a reset and it is rate limited until custom SMTP exists.
  // ---------------------------------------------------------------------------

  /// Registers an email + password account.
  ///
  /// The name travels in the user metadata because `private.handle_new_user`
  /// reads it when it creates the `public.profiles` row; the client never
  /// inserts into that table at signup, and RLS would refuse it if it tried.
  ///
  /// An empty session means the project still requires email confirmation — the
  /// caller then shows the six-digit confirmation step, which is why the
  /// confirmation template must print `{{ .Token }}`.
  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: Env.oauthRedirectUrl,
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Confirms a password signup with the code from the confirmation email.
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );
  }

  /// Asks for a reset. The mail carries a code (see `templates/recovery.html`),
  /// not just a link, so the reset works in the app.
  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: Env.oauthRedirectUrl,
    );
  }

  /// Exchanges the recovery code for the one-shot session that may set a new
  /// password.
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  /// Attributes the new account to whoever owns [code].
  ///
  /// Server-side on purpose: `profiles.referred_by` is not client-writable, and
  /// `apply_referral_code` enforces the rules (code must exist, no self-referral,
  /// first code wins). Failure is not fatal to signup — the account exists
  /// either way — so the caller reports it and moves on.
  Future<void> applyReferralCode(String code) async {
    await _client.rpc(
      'apply_referral_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
  }

  /// Sandbox sign-in (see [Env.devAuthEnabled]).
  ///
  /// Asks dev-signin for a token hash and exchanges it for a real session, so
  /// the rest of the app cannot tell this apart from a genuine email OTP and
  /// every RLS policy still applies. The wording of the messages thrown here
  /// matches what [AuthPage] already knows how to translate.
  Future<void> devSignIn({required String email, required String token}) async {
    final res = await http
        .post(
          Env.function('dev-signin'),
          headers: {
            'apikey': Env.supabaseKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email, 'code': token}),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      // Read the body when it parses: "invalid code" is a user mistake, and
      // anything else is a broken sandbox.
      String detail = '';
      try {
        detail =
            (jsonDecode(res.body) as Map<String, dynamic>)['error']
                as String? ??
            '';
      } catch (_) {
        detail = '';
      }
      if (detail == 'invalid_code') {
        throw AuthException('invalid code', statusCode: '401');
      }
      throw AuthException(
        'dev sign-in failed: ${detail.isEmpty ? res.statusCode : detail}',
        statusCode: res.statusCode.toString(),
      );
    }

    final tokenHash =
        (jsonDecode(res.body) as Map<String, dynamic>)['token_hash'] as String?;
    if (tokenHash == null) {
      throw const AuthException('dev sign-in returned no token');
    }

    await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
  }

  Future<void> signOut() => _client.auth.signOut();
}
