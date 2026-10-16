/// Deliberately permissive. We only catch the obvious mistakes, like a missing
/// `@` — the one that actually happened — and let the backend be the authority.
/// Over-strict client regexes reject addresses that are perfectly valid.
final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isLikelyEmail(String value) => _emailShape.hasMatch(value.trim());

/// Matches `auth.minimum_password_length` in `supabase/config.toml`, and the
/// `passwordMinLength` wording in the form. The backend is still the authority:
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
/// truncated code before the server does.
final _referralShape = RegExp(r'^[0-9A-F]{8}$');

bool isLikelyReferralCode(String value) =>
    _referralShape.hasMatch(value.trim().toUpperCase());
