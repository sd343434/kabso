import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';

const _required = ValidationError(ValidationIssue.required);
const _format = ValidationError(ValidationIssue.invalidFormat);

void main() {
  group('username (D146: 6–30, letters and digits, a–z 0–9 _)', () {
    for (final ok in [
      'user_123',
      'abc123',
      'layla_k9',
      'a1b2c3',
      '0ab_c9',
      'a1${'bc' * 14}',
    ]) {
      test('accepts "$ok"', () => expect(AuthValidators.username(ok), isNull));
    }

    test('requires a value', () {
      expect(AuthValidators.username(''), _required);
      expect(AuthValidators.username(null), _required);
    });

    test('enforces length bounds', () {
      expect(
        AuthValidators.username('ab_1'),
        const ValidationError(ValidationIssue.tooShort, 6),
      );
      expect(
        AuthValidators.username('a1${'bc' * 15}'),
        const ValidationError(ValidationIssue.tooLong, 30),
      );
    });

    for (final bad in [
      '.abc12',
      'abc12.',
      '_abc12',
      'abc12_',
      'Abc123',
      'ab c12',
      'ab-c12',
      'لیلى123',
      'ab@c12',
      'layla.k9',
      'abcdef',
      'abc_def',
      '777777',
    ]) {
      test('rejects "$bad"', () {
        expect(AuthValidators.username(bad), _format);
      });
    }
  });

  group('password (8–128)', () {
    test('bounds', () {
      expect(AuthValidators.password(''), _required);
      expect(
        AuthValidators.password('1234567'),
        const ValidationError(ValidationIssue.tooShort, 8),
      );
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('x' * 128), isNull);
      expect(
        AuthValidators.password('x' * 129),
        const ValidationError(ValidationIssue.tooLong, 128),
      );
    });

    test('login password only needs to be non-empty and ≤ 128', () {
      expect(AuthValidators.loginPassword(''), _required);
      expect(AuthValidators.loginPassword('1'), isNull);
      expect(
        AuthValidators.loginPassword('x' * 129),
        const ValidationError(ValidationIssue.tooLong, 128),
      );
    });
  });

  group('email', () {
    test('valid addresses (trimmed, case-insensitive)', () {
      expect(AuthValidators.email('layla@example.com'), isNull);
      expect(AuthValidators.email('  Layla@Example.COM '), isNull);
    });

    test('invalid addresses', () {
      expect(AuthValidators.email(''), _required);
      expect(AuthValidators.email('   '), _required);
      for (final bad in ['layla', 'layla@', '@example.com', 'a b@c.d']) {
        expect(AuthValidators.email(bad), _format, reason: bad);
      }
    });

    test('max 254 chars', () {
      final long = '${'a' * 250}@b.co';
      expect(
        AuthValidators.email(long),
        const ValidationError(ValidationIssue.tooLong, 254),
      );
    });

    test('normalizeEmail trims and lowercases (CONVENTIONS.md §6)', () {
      expect(AuthValidators.normalizeEmail('  A@B.Com '), 'a@b.com');
    });
  });

  group('identifier and display name', () {
    test('identifier 1–254 (D146: 1-character premium usernames)', () {
      expect(AuthValidators.identifier(''), _required);
      expect(AuthValidators.identifier('  '), _required);
      expect(AuthValidators.identifier('7'), isNull);
      expect(AuthValidators.identifier('abc'), isNull);
      expect(
        AuthValidators.identifier('a' * 255),
        const ValidationError(ValidationIssue.tooLong, 254),
      );
    });

    test('display name: required after trimming; 50 graphemes is the limit '
        '(v1.2 replaces the old 50 UTF-16 units check)', () {
      expect(AuthValidators.displayNameIssue('  '), DisplayNameIssue.required);
      expect(AuthValidators.displayNameIssue('ليلى'), isNull);
      expect(AuthValidators.displayNameIssue('x' * 50), isNull);
      expect(
        AuthValidators.displayNameIssue('x' * 51),
        DisplayNameIssue.tooLong,
      );
    });
  });
}
