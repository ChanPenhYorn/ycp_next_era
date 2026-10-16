import 'package:flutter_test/flutter_test.dart';
import 'package:ycp_store/src/features/auth/domain/auth_rules.dart';

/// The exact mistake that produced an unhelpful error: a missing `@`.
/// `yornchanpenh81gmail.com` was rejected, but the UI said only "Email address",
/// which told the user nothing about what was wrong.
void main() {
  group('isLikelyEmail', () {
    test('accepts ordinary addresses', () {
      expect(isLikelyEmail('someone@gmail.com'), isTrue);
      expect(isLikelyEmail('first.last@sub.domain.co.uk'), isTrue);
      expect(isLikelyEmail('user+tag@example.com'), isTrue);
    });

    test('rejects the missing @ that started this', () {
      expect(isLikelyEmail('yornchanpenh81gmail.com'), isFalse);
    });

    test('rejects other obvious mistakes', () {
      expect(isLikelyEmail(''), isFalse);
      expect(isLikelyEmail('@example.com'), isFalse);
      expect(isLikelyEmail('user@'), isFalse);
      expect(isLikelyEmail('user@localhost'), isFalse);
      expect(isLikelyEmail('two@@example.com'), isFalse);
      expect(isLikelyEmail('has space@example.com'), isFalse);
    });

    test('tolerates surrounding whitespace from a paste', () {
      expect(isLikelyEmail('  someone@gmail.com  '), isTrue);
    });
  });

  group('passwordProblem', () {
    test('asks for length first, and only length', () {
      expect(passwordProblem('Ab1'), PasswordProblem.tooShort);
      expect(passwordProblem(''), PasswordProblem.tooShort);
      // Eight characters, but no digit: length is no longer the complaint.
      expect(passwordProblem('Abcdefgh'), PasswordProblem.needsDigit);
    });

    test('names the next missing kind of character', () {
      expect(passwordProblem('abcdefg1'), PasswordProblem.needsUpper);
      expect(passwordProblem('ABCDEFG1'), PasswordProblem.needsLower);
      expect(passwordProblem('Abcdefgh'), PasswordProblem.needsDigit);
    });

    test('accepts a password that satisfies every rule', () {
      expect(passwordProblem('Chanpenh1'), isNull);
      expect(passwordProblem('aB3defgh'), isNull);
    });

    test('length matches the value pushed to Supabase', () {
      expect(passwordMinLength, 8);
      expect(passwordProblem('aB3defg'), PasswordProblem.tooShort);
      expect(passwordProblem('aB3defgh'), isNull);
    });
  });

  group('passwordScore', () {
    test('is zero before anything is typed', () {
      expect(passwordScore(''), 0);
    });

    test('rewards length, case mixing and a digit or symbol', () {
      expect(passwordScore('abcdefgh'), 1);
      expect(passwordScore('Abcdefgh'), 2);
      expect(passwordScore('Abcdefg1'), 3);
      expect(passwordScore('Abcdefg!'), 3);
    });

    test('never exceeds the three bars the UI draws', () {
      expect(passwordScore('Abcdefgh1!XyZ2345'), 3);
    });
  });

  group('isLikelyReferralCode', () {
    test('accepts the eight hex characters profiles.referral_code holds', () {
      expect(isLikelyReferralCode('A1B2C3D4'), isTrue);
      expect(isLikelyReferralCode('  a1b2c3d4 '), isTrue);
    });

    test('rejects a truncated or non-hex code', () {
      expect(isLikelyReferralCode('A1B2C3D'), isFalse);
      expect(isLikelyReferralCode('A1B2C3D45'), isFalse);
      expect(isLikelyReferralCode('ZZZZZZZZ'), isFalse);
      expect(isLikelyReferralCode(''), isFalse);
    });
  });
}
