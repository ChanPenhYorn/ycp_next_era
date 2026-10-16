import 'auth_models.dart';

/// Everything the app asks of authentication. Implementations throw
/// [AuthFailure] for every refused or failed operation.
abstract class AuthRepository {
  AppUser? get currentUser;

  /// Emits on sign-in, sign-out and token refresh.
  Stream<AppUser?> authChanges();

  Future<AuthCapabilities> capabilities();

  Future<void> signInWithGoogle();

  Future<void> signInWithOtp(String email);

  Future<void> verifyOtp({required String email, required String token});

  /// Returns true when the account still needs the emailed confirmation code
  /// before it has a session.
  Future<bool> signUpWithPassword({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> verifySignupOtp({required String email, required String token});

  Future<void> sendPasswordReset(String email);

  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  });

  Future<void> updatePassword(String password);

  Future<void> applyReferralCode(String code);

  /// Sandbox sign-in. Only reachable when the dev sandbox is enabled.
  Future<void> devSignIn({required String email, required String token});

  Future<void> signOut();
}
