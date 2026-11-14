// D297 (owner: «مهام خاصة بصناع المحتوى، وقيمتها كمهام المضيف»; follow-up:
// the generated catalogue «حسب المستوى وتدريجياً», by the charm level): the
// Task Center fed with REAL `GET /me/tasks` responses of the API with the
// generator on (test/fixtures/programs):
//
//   task_center.creator_d297   a creator at charm level 25, scrolled to the
//                              creator cards «مهام صانع المحتوى» (2 generated
//                              daily tasks) and the 6 generated weekly ones
//   task_center.host_d297      a host at charm level 40, scrolled to the
//                              weekly host card (4 generated weekly tasks)
//
// Arabic and English, dark and light, on the phone (393 × 852). Regenerate on
// Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/task_center_creator_d297_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/programs/programs_d297_test.dart';
import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    for (final (who, key) in const [
      ('creator', TaskCenterScreen.creatorWeeklyKey),
      ('host', TaskCenterScreen.weeklyKey),
    ]) {
      for (final (label, brightness) in const [
        ('phone', Brightness.dark),
        ('phone.light', Brightness.light),
      ]) {
        testWidgets('task_center.${who}_d297 ${language.name} $label', (
          tester,
        ) async {
          await pumpD297TaskCenter(
            tester,
            programs: D297Programs(d297Fixture(who, language)),
            language: language,
            brightness: brightness,
          );
          await tester.scrollUntilVisible(
            find.byKey(key),
            100,
            scrollable: find
                .descendant(
                  of: find.byType(RefreshIndicator),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/task_center.${who}_d297.${language.name}.$label.png',
            ),
          );
        });
      }
    }
  });
}
