// v1.78-live (D288): «بلاغات» — the shared report queue.
//
//   staff.reports.me.none     the staff Me tab (a moderator) with the
//                             «بلاغات» row and no badge (nothing open)
//   staff.reports.me.badge    the same row with 12 unresolved at its end
//   staff.reports.open        the queue: «غير محلولة» with «تم حله»
//   staff.reports.resolved    «تم حلها»: who resolved it, when, the note
//
// 393 × 852 with the status bar 59 and the home indicator 34. Regenerate on
// Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/staff_reports_d288_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:material_ui/material_ui.dart';

import '../features/staff/staff_d283_test.dart';
import '../features/staff/staff_reports_d288_test.dart';
import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;

    testWidgets('staff.reports.me.none $name', (tester) async {
      await pumpStaffHub(tester, language: language);
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.reports.me.none.$name.phone.png'),
      );
    });

    testWidgets('staff.reports.me.badge $name', (tester) async {
      await pumpStaffHub(tester, language: language, openReports: 12);
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.reports.me.badge.$name.phone.png'),
      );
    });

    testWidgets('staff.reports.open $name', (tester) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 6, 12)), () async {
        await pumpReportsScreen(
          tester,
          language: language,
          repo: FakeReportsRepository(),
        );
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.reports.open.$name.phone.png'),
      );
    });

    testWidgets('staff.reports.resolved $name', (tester) async {
      await pumpReportsScreen(
        tester,
        language: language,
        repo: FakeReportsRepository(),
      );
      await tester.tap(
        find.text(language == AppLanguage.ar ? 'تم حلها' : 'Resolved'),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.reports.resolved.$name.phone.png'),
      );
    });
  });
}
