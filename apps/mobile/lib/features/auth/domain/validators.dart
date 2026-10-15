/// Client-side validation mirroring docs/contracts (openapi.yaml schemas and
/// CONVENTIONS.md §6). The server stays authoritative.
library;

import 'package:flutter/foundation.dart' show immutable;

enum ValidationIssue { required, tooShort, tooLong, invalidFormat }

/// A failed validation with the bound that was violated (if any).
@immutable
class ValidationError {
  const new(this.issue, [this.limit]);

  final ValidationIssue issue;
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is ValidationError && other.issue == issue && other.limit == limit;

  @override
  int get hashCode => Object.hash(issue, limit);

  @override
  String toString() => 'ValidationError($issue, $limit)';
}

abstract final class AuthRules {
  static const usernameMin = 3;
  static const usernameMax = 30;
  static final usernamePattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9._]{1,28}[a-z0-9])?$',
  );

  static const passwordMin = 8;
  static const passwordMax = 128;

  /// Login accepts any non-empty password up to 128 chars (`LoginRequest`).
  static const loginPasswordMax = 128;

  static const emailMax = 254;
  static final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const identifierMin = 3;
  static const identifierMax = 254;

  static const displayNameMin = 1;
  static const displayNameMax = 50;
}

abstract final class AuthValidators {
  static ValidationError? username(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return const ValidationError(ValidationIssue.required);
    if (v.length < AuthRules.usernameMin) {
      return const ValidationError(
        ValidationIssue.tooShort,
        AuthRules.usernameMin,
      );
    }
    if (v.length > AuthRules.usernameMax) {
      return const ValidationError(
        ValidationIssue.tooLong,
        AuthRules.usernameMax,
      );
    }
    if (!AuthRules.usernamePattern.hasMatch(v)) {
      return const ValidationError(ValidationIssue.invalidFormat);
    }
    return null;
  }

  static ValidationError? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return const ValidationError(ValidationIssue.required);
    if (v.length < AuthRules.passwordMin) {
      return const ValidationError(
        ValidationIssue.tooShort,
        AuthRules.passwordMin,
      );
    }
    if (v.length > AuthRules.passwordMax) {
      return const ValidationError(
        ValidationIssue.tooLong,
        AuthRules.passwordMax,
      );
    }
    return null;
  }

  static ValidationError? loginPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return const ValidationError(ValidationIssue.required);
    if (v.length > AuthRules.loginPasswordMax) {
      return const ValidationError(
        ValidationIssue.tooLong,
        AuthRules.loginPasswordMax,
      );
    }
    return null;
  }

  static ValidationError? email(String? value) {
    final v = normalizeEmail(value ?? '');
    if (v.isEmpty) return const ValidationError(ValidationIssue.required);
    if (v.length > AuthRules.emailMax) {
      return const ValidationError(ValidationIssue.tooLong, AuthRules.emailMax);
    }
    if (!AuthRules.emailPattern.hasMatch(v)) {
      return const ValidationError(ValidationIssue.invalidFormat);
    }
    return null;
  }

  static ValidationError? identifier(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return const ValidationError(ValidationIssue.required);
    if (v.length < AuthRules.identifierMin) {
      return const ValidationError(
        ValidationIssue.tooShort,
        AuthRules.identifierMin,
      );
    }
    if (v.length > AuthRules.identifierMax) {
      return const ValidationError(
        ValidationIssue.tooLong,
        AuthRules.identifierMax,
      );
    }
    return null;
  }

  static ValidationError? displayName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return const ValidationError(ValidationIssue.required);
    if (v.length > AuthRules.displayNameMax) {
      return const ValidationError(
        ValidationIssue.tooLong,
        AuthRules.displayNameMax,
      );
    }
    return null;
  }

  /// The server enforces the username pattern strictly (contract v1.0.3):
  /// the client sends usernames trimmed and lowercased.
  static String normalizeUsername(String value) => value.trim().toLowerCase();

  /// CONVENTIONS.md §6: emails are trimmed and lowercased.
  static String normalizeEmail(String value) => value.trim().toLowerCase();
}
