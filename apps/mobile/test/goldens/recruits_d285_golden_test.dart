// D285 (owner): recruitment by staff «الاستقطاب».
//
//   recruits.field.found      the recruiter field «إن كنت تابعاً لمشرف…»
//                             naming BD «نور» (Kabso05): the name and badge
//   recruits.field.not_found  an ID naming nobody: «غير موجود» and, after a
//                             send attempt, the fix-it error
//   recruits.mine             «استقطاباتي»: the counts by type, the rows with
//                             status and commissions
//   recruits.earnings         «أرباحي»: the balance, shares, breakdown and
//                             the daily history, «سحب الأرباح»
//   recruits.me_bd            the BD staff Me tab with «استقطاباتي» / «أرباحي»
//
// 393 × 852 with the status bar 59 and the home indicator 34; a fixed
// clock. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/recruits_d285_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/recruits/data/recruits_repository.dart';
import 'package:kabso_live/features/recruits/presentation/recruiter_field.dart';
import 'package:kabso_live/features/recruits/presentation/staff_recruits_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../features/recruits/recruits_d285_test.dart';
import '../features/staff/staff_d283_test.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _phone(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

/// A form section like the applications' (a title, a field, the recruiter).
class _Form extends StatelessWidget {
  const new({required this.showError});

  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hostApplyFormTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(labelText: l10n.hostApplyName),
            controller: TextEditingController(text: 'Layla'),
          ),
          const SizedBox(height: 12),
          RecruiterField(showError: showError, onChanged: (_) {}),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;

    for (final (label, text, error) in [
      ('found', 'Kabso05', false),
      ('not_found', 'Kabso77', true),
    ]) {
      testWidgets('recruits.field.$label $name', (tester) async {
        await _phone(tester);
        await withClock(Clock.fixed(d285Now), () async {
          await pumpScreen(
            tester,
            _Form(showError: error),
            language: language,
            overrides: [
              recruitsRepositoryProvider.overrideWithValue(
                FakeRecruitsRepository(),
              ),
            ],
          );
          await tester.enterText(find.byKey(RecruiterField.fieldKey), text);
          await tester.pump(const Duration(milliseconds: 450));
          await tester.pumpAndSettle();
        });
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/recruits.field.$label.$name.phone.png'),
        );
      });
    }

    testWidgets('recruits.mine $name', (tester) async {
      await _phone(tester);
      await withClock(Clock.fixed(d285Now), () async {
        await pumpScreen(
          tester,
          const StaffRecruitsScreen(),
          language: language,
          overrides: [
            recruitsRepositoryProvider.overrideWithValue(
              FakeRecruitsRepository(recruits: recruitsFixture(ar: ar)),
            ),
          ],
        );
        await precacheImages(tester);
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/recruits.mine.$name.phone.png'),
      );
    });

    testWidgets('recruits.earnings $name', (tester) async {
      await _phone(tester);
      await withClock(Clock.fixed(d285Now), () async {
        await pumpScreen(
          tester,
          const StaffEarningsScreen(),
          language: language,
          overrides: [
            recruitsRepositoryProvider.overrideWithValue(
              FakeRecruitsRepository(earnings: earningsFixture(ar: ar)),
            ),
          ],
        );
        await precacheImages(tester);
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/recruits.earnings.$name.phone.png'),
      );
    });

    testWidgets('recruits.me_bd $name', (tester) async {
      await pumpStaffHub(tester, language: language, staff: bdIdentity);
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/recruits.me_bd.$name.phone.png'),
      );
    });
  });
}
