// v1.93-social (D296): a report opened by the staff — its content and actions.
//
//   staff.report.post      a hidden post opened from «بلاغات» by a moderator:
//                          the «محتوى مُبلّغ عنه» banner with its state, the
//                          post, the report and the action bar (every action)
//   staff.report.dm        a reported DM opened by SUPPORT: the whole
//                          conversation frozen by the report (owner: «مثل
//                          طريقة نزاع وكيل الشحن»), read only, the reported
//                          message outlined; only the role's actions
//   staff.report.delete    «حذف نهائي»: the reason and the typed word
//   staff.report.delete_account  «حذف الحساب» (OWNER)
//   staff.report.ban       the «حظر دائم» confirmation with its reason
//   staff.report.restrict  «تقييد»: the restriction, the duration, the reason
//
// 393 × 852. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/staff_report_d296_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/features/staff/domain/staff_report_view.dart';
import 'package:kabso_live/features/staff/presentation/staff_report_detail_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/staff/staff_report_detail_d296_test.dart';
import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final name = language.name;

    testWidgets('staff.report.post $name', (tester) async {
      await pumpReportRoutes(
        tester,
        language: language,
        repo: FakeReportViewRepository(),
        initial: AppRoutes.staffReport('rep-post'),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.report.post.$name.phone.png'),
      );
    });

    testWidgets('staff.report.dm $name', (tester) async {
      await pumpReportRoutes(
        tester,
        language: language,
        repo: FakeReportViewRepository(),
        initial: AppRoutes.staffReport('rep-dm'),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.report.dm.$name.phone.png'),
      );
    });

    testWidgets('staff.report.ban $name', (tester) async {
      await pumpReportRoutes(
        tester,
        language: language,
        repo: FakeReportViewRepository(),
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(
        find.byKey(StaffReportDetailScreen.action(StaffReportAction.ban)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.report.ban.$name.phone.png'),
      );
    });

    for (final (key, action) in [
      ('delete', StaffReportAction.deleteContent),
      ('delete_account', StaffReportAction.deleteAccount),
    ]) {
      testWidgets('staff.report.$key $name', (tester) async {
        await pumpReportRoutes(
          tester,
          language: language,
          repo: FakeReportViewRepository(),
          initial: AppRoutes.staffReport('rep-post'),
        );
        await tester.tap(find.byKey(StaffReportDetailScreen.action(action)));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/staff.report.$key.$name.phone.png'),
        );
      });
    }

    testWidgets('staff.report.restrict $name', (tester) async {
      await pumpReportRoutes(
        tester,
        language: language,
        repo: FakeReportViewRepository(),
        initial: AppRoutes.staffReport('rep-post'),
      );
      await tester.tap(
        find.byKey(StaffReportDetailScreen.action(StaffReportAction.restrict)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff.report.restrict.$name.phone.png'),
      );
    });
  });
}
