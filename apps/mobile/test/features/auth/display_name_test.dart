// KL-017: displayName rules (contract v1.2 §6, PHASE1_1_SCREENS §2).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/domain/auth_failures.dart';
import 'package:kabso_live/features/auth/domain/validators.dart';
import 'package:kabso_live/features/auth/presentation/widgets/auth_widgets.dart';

import '../../helpers/pump_app.dart';

const _zwnj = '\u200C';
const _zwj = '\u200D';

void main() {
  group('valid names (client accepts; server decides the rest)', () {
    final samples = {
      'Persian with ZWNJ': 'می$_zwnjخواهم',
      'Urdu': 'عائشہ صدیقی',
      'Kurdish Sorani with ZWNJ': 'ڕێ$_zwnjژان',
      'family emoji (ZWJ sequence)': 'Layla 👨\u200D👩\u200D👧',
      'flag': 'Omar 🇯🇴',
      'skin tone': 'Sara 👋🏽',
      'emoji only': '👨\u200D👩\u200D👧',
      'Arabic': 'ليلى عبد الرحمن',
      // 50 graphemes and 50 code points (≤ 100).
      'exactly 50 graphemes of emoji': '😀' * 50,
      'exactly 50 Latin letters': 'x' * 50,
    };
    for (final MapEntry(key: name, :value) in samples.entries) {
      test(name, () {
        expect(AuthValidators.displayNameIssue(value), isNull, reason: value);
      });
    }

    test('ZWJ sequences count as one grapheme each', () {
      expect(AuthValidators.displayNameLength('👨\u200D👩\u200D👧'), 1);
      expect(AuthValidators.displayNameLength('🇯🇴'), 1);
      expect(AuthValidators.displayNameLength('👋🏽'), 1);
      expect(AuthValidators.displayNameLength('می$_zwnjخواهم'), 7);
      expect(AuthValidators.displayNameLength('  Layla  '), 5);
    });
  });

  group('invalid names', () {
    test('51 graphemes → too long', () {
      expect(
        AuthValidators.displayNameIssue('x' * 51),
        DisplayNameIssue.tooLong,
      );
      expect(
        AuthValidators.displayNameIssue('👋🏽' * 51),
        DisplayNameIssue.tooLong,
      );
    });

    test('more than 100 code points → too long even under 50 graphemes', () {
      // 20 graphemes × 8 code points (family emoji = 5 + skin tones…)
      final heavy = '👨🏽\u200D👩🏽\u200D👧🏽' * 20;
      expect(AuthValidators.displayNameLength(heavy), 20);
      expect(heavy.runes.length, greaterThan(100));
      expect(AuthValidators.displayNameIssue(heavy), DisplayNameIssue.tooLong);
    });

    final invalid = {
      'leading ZWNJ': '${_zwnj}Layla',
      'trailing ZWJ': 'Layla$_zwj',
      'double joiners': 'لی$_zwnj$_zwnjلا',
      'joiner next to a space': 'Lay $_zwnj la',
      'only joiners and marks': '$_zwnj\u064B',
      'zero-width space': 'Lay\u200Bla',
      'word joiner': 'Lay\u2060la',
      // A leading BOM is removed by trimming (client and server); inside the
      // name it is rejected.
      'BOM inside': 'Lay\uFEFFla',
      'RLO bidi override': 'admin\u202Egnp.exe',
      'control character': 'Lay\u0007la',
      'zalgo (4 combining marks)': 'a\u0301\u0302\u0303\u0304',
    };
    for (final MapEntry(key: name, :value) in invalid.entries) {
      test(name, () {
        expect(
          AuthValidators.displayNameIssue(value),
          DisplayNameIssue.invalidFormat,
          reason: name,
        );
      });
    }

    test('3 combining marks are still fine', () {
      expect(AuthValidators.displayNameIssue('a\u0301\u0302\u0303'), isNull);
    });

    test('empty and whitespace-only → required', () {
      expect(AuthValidators.displayNameIssue(''), DisplayNameIssue.required);
      expect(
        AuthValidators.displayNameIssue(' \t '),
        DisplayNameIssue.required,
      );
    });
  });

  group('server issues map to the §2 copy', () {
    for (final language in AppLanguage.values) {
      test(language.name, () {
        final l10n = l10nFor(language);
        String msg(String issue) => serverIssueMessage(
          l10n,
          AuthField.displayName,
          ValidationIssueCode.fromWire(issue),
        );
        expect(msg('invalid_format'), l10n.displayNameInvalid);
        expect(msg('too_long'), l10n.displayNameTooLong);
        expect(msg('reserved_term'), l10n.displayNameReserved);
        expect(msg('required'), l10n.validationRequired);
      });
    }

    test('reserved_term is part of the issue vocabulary', () {
      expect(
        ValidationIssueCode.fromWire('reserved_term'),
        ValidationIssueCode.reservedTerm,
      );
    });

    test('no reserved term ships in the copy', () {
      for (final language in AppLanguage.values) {
        final copy = l10nFor(language).displayNameReserved.toLowerCase();
        for (final term in ['kabso', 'admin', 'support', 'official']) {
          expect(copy, isNot(contains(term)));
        }
      }
    });
  });
}
