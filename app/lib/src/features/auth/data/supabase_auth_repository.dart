import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser => _toUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> authChanges() => _client.auth.onAuthStateChange.map(
    (state) => _toUser(state.session?.user),
  );

  /// Public endpoint: no key beyond the publishable one, no user required.
  @override
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
  @override
  Future<void> signInWithGoogle() => _guard(
    () => _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Env.oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
      scopes: 'email profile',
    ),
  );

  @override
  Future<void> signInWithOtp(String email) => _guard(
    () => _client.auth.signInWithOtp(
      email: email,
      // Deep link straight back into the app so the code can be auto-filled.
      emailRedirectTo: Env.oauthRedirectUrl,
    ),
  );

  @override
  Future<void> verifyOtp({required String email, required String token}) =>
      _guard(
        () => _client.auth.verifyOTP(
          type: OtpType.email,
          email: email,
          token: token,
        ),
      );

  // ---------------------------------------------------------------------------
  // Email + password accounts
  //
  // Passwords are one of three ways in; the emailed code above stays available
  // as a fallback, because the project's mailer is the only thing that can
  // deliver a reset and it is rate limited until custom SMTP exists.
  // ---------------------------------------------------------------------------

  /// The name travels in the user metadata because `private.handle_new_user`
  /// reads it when it creates the `public.profiles` row; the client never
  /// inserts into that table at signup, and RLS would refuse it if it tried.
  ///
  /// An empty session means the project still requires email confirmation.
  @override
  Future<bool> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _guard(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
        emailRedirectTo: Env.oauthRedirectUrl,
      ),
    );
    return res.session == null;
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => _guard(
    () => _client.auth.signInWithPassword(email: email, password: password),
  );

  @override
  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) => _guard(
    () => _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    ),
  );

  /// The mail carries a code (see `templates/recovery.html`), not just a link,
  /// so the reset works in the app.
  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _client.auth.resetPasswordForEmail(
      email,
      redirectTo: Env.oauthRedirectUrl,
    ),
  );

  @override
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) => _guard(
    () => _client.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    ),
  );

  @override
  Future<void> updatePassword(String password) =>
      _guard(() => _client.auth.updateUser(UserAttributes(password: password)));

  /// Server-side on purpose: `profiles.referred_by` is not client-writable, and
  /// `apply_referral_code` enforces the rules (code must exist, no self-referral,
  /// first code wins).
  @override
  Future<void> applyReferralCode(String code) => _guard(
    () => _client.rpc(
      'apply_referral_code',
      params: {'p_code': code.trim().toUpperCase()},
    ),
  );

  /// Asks dev-signin for a token hash and exchanges it for a real session, so
  /// the rest of the app cannot tell this apart from a genuine email OTP and
  /// every RLS policy still applies.
  @override
  Future<void> devSignIn({
    required String email,
    required String token,
  }) => _guard(() async {
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
        throw const AuthFailure('invalid code', statusCode: '401');
      }
      throw AuthFailure(
        'dev sign-in failed: ${detail.isEmpty ? res.statusCode : detail}',
        statusCode: res.statusCode.toString(),
      );
    }

    final tokenHash =
        (jsonDecode(res.body) as Map<String, dynamic>)['token_hash'] as String?;
    if (tokenHash == null) {
      throw const AuthFailure('dev sign-in returned no token');
    }

    await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  AppUser? _toUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);

  /// Translates SDK exceptions at the boundary so the rest of the app only ever
  /// handles [AuthFailure].
  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthException catch (error) {
      throw AuthFailure(error.message, statusCode: error.statusCode);
    } on PostgrestException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
