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
      expect(l10nFor(AppLanguage.en).relativeMinutesAgo(5), '5m ago');
      expect(l10nFor(AppLanguage.ar).relativeHoursAgo(3), 'منذ 3 س');
    });
  });
}
