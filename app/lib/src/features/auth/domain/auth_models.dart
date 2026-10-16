/// The signed-in user, as far as the app needs to know.
class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String? email;
}

/// Which sign-in methods the project actually has switched on.
///
/// Read from the project's public auth settings rather than hard-coded, so
/// enabling Google in the dashboard makes the button appear without shipping a
/// new build. It also means we never show a button that fails with "provider is
/// not enabled".
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

/// An auth or account operation the server refused or could not complete.
///
/// Data sources translate their own exceptions into this, so presentation never
/// sees a backend SDK type. [statusCode] is the HTTP-ish code when one exists.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.statusCode});

  final String message;
  final String? statusCode;

  @override
  String toString() => message;
}
