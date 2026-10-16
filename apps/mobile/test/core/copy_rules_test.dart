// KL-015 copy rules (PHASE1_1_SCREENS §5): T1 "Log in/Log out", T2 brand in
// Latin script, T3 no exclamation marks, T4 Arabic plurals; retired v1.2
// strings are gone.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';

import '../helpers/pump_app.dart';

Map<String, String> _values(String file) {
  final json = jsonDecode(
    File('lib/l10n/$file').readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: '${e.value}',
  };
}

void main() {
  final en = _values('app_en.arb');
  final ar = _values('app_ar.arb');

  test('T1: no "Sign in" / "Sign out" in English UI copy', () {
    for (final MapEntry(:key, :value) in en.entries) {
      expect(
        value,
        isNot(contains(RegExp('sign (in|out)', caseSensitive: false))),
        reason: key,
      );
    }
    expect(en['loginSubmit'], 'Log in');
    expect(en['logout'], 'Log out');
  });

  test('T2: the brand is "Kabso Live" in Latin script in Arabic copy', () {
    for (final MapEntry(:key, :value) in ar.entries) {
      expect(value, isNot(contains('كابسو')), reason: key);
    }
    expect(ar['appTitle'], 'Kabso Live');
    expect(ar['codeWelcome'], contains('Kabso Live'));
  });

  test('T3: no exclamation marks', () {
    for (final entry in [...en.entries, ...ar.entries]) {
      expect(entry.value, isNot(contains('!')), reason: entry.key);
    }
  });

  test('T4: Arabic count-dependent copy uses ICU plurals', () {
    final l10n = l10nFor(AppLanguage.ar);
    expect(l10n.validationTooShort(3), 'استخدم 3 أحرف على الأقل');
    expect(l10n.validationTooShort(8), 'استخدم 8 أحرف على الأقل');
    expect(l10n.validationTooLong(30), 'استخدم 30 حرفًا أو أقل');
    // CLDR Arabic: n % 100 in 11..99 → many (128 → حرفًا); 100 → other.
    expect(l10n.validationTooLong(128), 'استخدم 128 حرفًا أو أقل');
    expect(l10n.validationTooLong(100), 'استخدم 100 حرف أو أقل');
    final enL10n = l10nFor(AppLanguage.en);
    expect(enL10n.validationTooShort(8), 'Use at least 8 characters');
  });

  test('v1.2 retired strings are gone (verify-email UI, EMAIL_TAKEN copy, '
      'combined username rule)', () {
    for (final key in [
      'verifyTitle',
      'verifyBody',
      'verifyResend',
      'verifyResent',
      'verifyContinue',
      'profileEmailVerified',
      'profileEmailNotVerified',
      'profileResendVerification',
      'errorEmailTaken',
      'validationUsernameFormat',
    ]) {
      expect(en.containsKey(key), isFalse, reason: key);
      expect(ar.containsKey(key), isFalse, reason: key);
    }
  });

  test('suspended copy tells the user to contact support', () {
    expect(en['accountSuspendedBanner'], contains('contact support'));
    expect(ar['accountSuspendedBanner'], contains('تواصل مع الدعم'));
  });

  test('Create empty state lists phases 3, 4, 5 and 6', () {
    for (final copy in [en['createComingBody']!, ar['createComingBody']!]) {
      for (final phase in ['3', '4', '5', '6']) {
        expect(copy, contains(phase));
      }
    }
  });
}
