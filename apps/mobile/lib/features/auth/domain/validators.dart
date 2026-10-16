/// Client-side validation mirroring docs/contracts (openapi.yaml schemas and
/// CONVENTIONS.md §6). The server stays authoritative.
library;

import 'package:flutter/foundation.dart' show immutable;
// `String.characters` (grapheme clusters) from package:characters, which
// Flutter re-exports; no extra dependency.
import 'package:flutter/widgets.dart' show StringCharacters;

enum ValidationIssue { required, tooShort, tooLong, invalidFormat }

/// Specific reason a username is invalid (PHASE1_SCREENS §4.2), in the
/// spec's precedence order: bad characters → too short → too long → bad
/// edges.
enum UsernameIssue { required, badChars, tooShort, tooLong, badEdges }

/// Client-side displayName problems (PHASE1_1_SCREENS §2).
enum DisplayNameIssue { required, tooLong, invalidFormat }

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

  /// Grapheme clusters (v1.2).
  static const displayNameMax = 50;

  /// Unicode code points (v1.2).
  static const displayNameMaxCodePoints = 100;
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

  /// Number of user-perceived characters (grapheme clusters) in a display
  /// name, after trimming. This is what the `{count}/50` counter shows.
  static int displayNameLength(String value) => value.trim().characters.length;

  /// Client-side mirror of the v1.2 displayName rules (CONVENTIONS §6,
  /// PHASE1_1_SCREENS §2). The server stays authoritative: it also NFC-
  /// normalizes and checks reserved terms (`reserved_term`), which the app
  /// never ships.
  static DisplayNameIssue? displayNameIssue(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return DisplayNameIssue.required;
    if (v.characters.length > AuthRules.displayNameMax ||
        v.runes.length > AuthRules.displayNameMaxCodePoints) {
      return DisplayNameIssue.tooLong;
    }
    if (_displayNameBanned.hasMatch(v)) return DisplayNameIssue.invalidFormat;
    if (_tooManyMarks.hasMatch(v)) return DisplayNameIssue.invalidFormat;
    if (!_hasJoinersInPlace(v)) return DisplayNameIssue.invalidFormat;
    if (!_hasVisibleBase.hasMatch(v)) return DisplayNameIssue.invalidFormat;
    return null;
  }

  /// C0/C1 controls, bidi overrides/isolates, U+200B, U+2060, U+FEFF.
  static final _displayNameBanned = RegExp(
    '[\u0000-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069'
    '\u200B\u2060\uFEFF]',
  );

  /// More than 3 consecutive combining marks ("zalgo").
  static final _tooManyMarks = RegExp(r'\p{M}{4,}', unicode: true);

  /// v1.2.1: at least one letter, digit or emoji (`Extended_Pictographic`).
  /// Emoji-only names are valid; punctuation/symbol-only names are not.
  static final _hasVisibleBase = RegExp(
    // The Dart VM's regexp engine supports the Extended_Pictographic binary
    // property (exercised by display_name_test); the analyzer's static
    // checker does not know it yet.
    // ignore: valid_regexps
    r'[\p{L}\p{N}\p{Extended_Pictographic}]',
    unicode: true,
  );

  static const _zwnj = 0x200C;
  static const _zwj = 0x200D;

  /// ZWNJ/ZWJ must sit between two characters that are neither joiners nor
  /// whitespace (not leading/trailing, never doubled, never next to a space).
  static bool _hasJoinersInPlace(String v) {
    final cps = v.runes.toList(growable: false);
    bool isJoiner(int cp) => cp == _zwnj || cp == _zwj;
    bool isSpace(int cp) => String.fromCharCode(cp).trim().isEmpty;
    for (var i = 0; i < cps.length; i++) {
      if (!isJoiner(cps[i])) continue;
      if (i == 0 || i == cps.length - 1) return false;
      final before = cps[i - 1];
      final after = cps[i + 1];
      if (isJoiner(before) || isJoiner(after)) return false;
      if (isSpace(before) || isSpace(after)) return false;
    }
    return true;
  }

  /// The specific [UsernameIssue] for [value], or `null` when it matches
  /// the contract pattern and length.
  static UsernameIssue? usernameIssue(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return UsernameIssue.required;
    if (RegExp('[^a-z0-9._]').hasMatch(v)) return UsernameIssue.badChars;
    if (v.length < AuthRules.usernameMin) return UsernameIssue.tooShort;
    if (v.length > AuthRules.usernameMax) return UsernameIssue.tooLong;
    if (!AuthRules.usernamePattern.hasMatch(v)) return UsernameIssue.badEdges;
    return null;
  }

  /// The server enforces the username pattern strictly (contract v1.0.3):
  /// the client sends usernames trimmed and lowercased.
  static String normalizeUsername(String value) => value.trim().toLowerCase();

  /// CONVENTIONS.md §6: emails are trimmed and lowercased.
  static String normalizeEmail(String value) => value.trim().toLowerCase();
}
