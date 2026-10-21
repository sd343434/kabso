import 'dart:ui' show TextDirection;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';

import '../helpers/pump_app.dart';

final _arabicIndic = RegExp('[٠-٩۰-۹]');

void main() {
  // Date symbols for `ar` are normally loaded by the Material localizations
  // delegate; load them directly for these pure unit tests.
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  group('KFormat.date (DESIGN_SYSTEM §3.3: Latin digits)', () {
    final date = DateTime(2026, 10, 15, 12, 30);

    test('en', () => expect(KFormat.date(date, 'en'), '15 Oct 2026'));

    test('ar uses Latin digits', () {
      final text = KFormat.date(date, 'ar');
      expect(text, contains('15'));
      expect(text, contains('2026'));
      expect(text, isNot(contains(_arabicIndic)));
      expect(text, contains('أكتوبر'));
    });
  });

  group('KFormat.countdown (m:ss, h:mm:ss)', () {
    test('formats', () {
      expect(KFormat.countdown(Duration.zero), '0:00');
      expect(KFormat.countdown(const Duration(seconds: 5)), '0:05');
      expect(KFormat.countdown(const Duration(minutes: 4, seconds: 5)), '4:05');
      expect(KFormat.countdown(const Duration(minutes: 15)), '15:00');
      expect(
        KFormat.countdown(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(KFormat.countdown(const Duration(seconds: -3)), '0:00');
    });
  });

  group('KFormat.relative', () {
    final now = DateTime.utc(2026, 10, 15, 12);

    for (final language in AppLanguage.values) {
      test(language.name, () {
        final l10n = l10nFor(language);
        String? rel(Duration ago) =>
            KFormat.relative(now.subtract(ago), now, l10n, language.name);

        expect(rel(const Duration(seconds: 30)), isNull, reason: 'just now');
        expect(rel(const Duration(minutes: 5)), l10n.relativeMinutesAgo(5));
        expect(rel(const Duration(hours: 3)), l10n.relativeHoursAgo(3));
        expect(rel(const Duration(days: 7)), l10n.relativeDaysAgo(7));
        // Beyond 7 days: absolute date.
        expect(
          rel(const Duration(days: 8)),
          KFormat.date(now.subtract(const Duration(days: 8)), language.name),
        );
        for (final d in [
          const Duration(minutes: 5),
          const Duration(hours: 3),
          const Duration(days: 30),
        ]) {
          expect(rel(d), isNot(contains(_arabicIndic)));
        }
      });
    }

    test('copy matches PHASE1_SCREENS §9.3', () {
      expect(l10nFor(AppLanguage.en).relativeMinutesAgo(5), '5 minutes ago');
      expect(l10nFor(AppLanguage.en).relativeDaysAgo(1), '1 day ago');
      expect(l10nFor(AppLanguage.ar).relativeHoursAgo(3), 'منذ 3 ساعات');
      expect(l10nFor(AppLanguage.ar).relativeDaysAgo(2), 'منذ يومين');
      expect(l10nFor(AppLanguage.ar).relativeMinutesAgo(11), 'منذ 11 دقيقة');
    });
  });

  group('KFormat.compact (DESIGN_SYSTEM §3.3)', () {
    final en = l10nFor(AppLanguage.en);
    final ar = l10nFor(AppLanguage.ar);

    test('exact with grouping below 10,000', () {
      for (final (value, text) in const [
        (0, '0'),
        (987, '987'),
        (1234, '1,234'),
        (9999, '9,999'),
      ]) {
        expect(KFormat.compact(value, en), text);
        expect(KFormat.compact(value, ar), text);
      }
    });

    test('one decimal, floored, trailing .0 dropped', () {
      for (final (value, enText, arText) in const [
        (10000, '10K', '10 ألف'),
        (12345, '12.3K', '12.3 ألف'),
        (12399, '12.3K', '12.3 ألف'),
        (120000, '120K', '120 ألف'),
        (999999, '999.9K', '999.9 ألف'),
        (1000000, '1M', '1 مليون'),
        (1234567, '1.2M', '1.2 مليون'),
        (1999999, '1.9M', '1.9 مليون'),
        (999999999, '999.9M', '999.9 مليون'),
        (2000000000, '2B', '2 مليار'),
        (1234567890123, '1,234.5B', '1,234.5 مليار'),
      ]) {
        expect(KFormat.compact(value, en), enText, reason: '$value en');
        expect(KFormat.compact(value, ar), arText, reason: '$value ar');
        expect(KFormat.compact(value, ar), isNot(contains(_arabicIndic)));
      }
    });

    test('negative counts show 0', () {
      expect(KFormat.compact(-5, en), '0');
    });

    test('grouped keeps every digit', () {
      expect(KFormat.grouped(0), '0');
      expect(KFormat.grouped(12500), '12,500');
      expect(KFormat.grouped(1234567), '1,234,567');
      expect(KFormat.grouped(-1234), '-1,234');
    });

    test('bidiIsolate wraps in FSI … PDI', () {
      expect(KFormat.bidiIsolate('sara'), '\u2068sara\u2069');
    });

    test('firstStrongDirection: the first letter decides; none → null', () {
      expect(KFormat.firstStrongDirection('@omar مرحبا'), TextDirection.ltr);
      expect(KFormat.firstStrongDirection('مرحبا @omar'), TextDirection.rtl);
      expect(KFormat.firstStrongDirection('  12 #שלום'), TextDirection.rtl);
      expect(KFormat.firstStrongDirection('😀 123 @'), isNull);
      expect(KFormat.firstStrongDirection(''), isNull);
    });

    test('inputDirection: tags aside; tags alone follow their letter', () {
      expect(KFormat.inputDirection('@sara شكراً'), TextDirection.rtl);
      expect(KFormat.inputDirection('@sara thanks'), TextDirection.ltr);
      expect(KFormat.inputDirection('@sara '), TextDirection.ltr);
      expect(KFormat.inputDirection('#البتراء'), TextDirection.rtl);
      expect(KFormat.inputDirection('#petra مرحبا'), TextDirection.rtl);
      expect(KFormat.inputDirection('🙂'), isNull);
    });
  });
}
