import 'package:flutter_test/flutter_test.dart';
import 'package:ycp_store/src/data/auth_repository.dart';

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
}
