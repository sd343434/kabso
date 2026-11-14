// D283c (owner: «ايدي للمشرفين والادارة بحيث ايدي الموظفين يبدأ Kabso01»):
// the official staff ID where the @username was.
//
//   staff_id.profile   a moderator's profile: «ID: Kabso01» under the name
//                      (the region cover, team frame, badge and line stay)
//   staff_id.me        the staff-only Me tab: «ID: Kabso01» under the name
//   staff_id.card      the OWNER's person card over a live: «ID: Kabso01»
//
// 393 × 852 with the status bar 59 and the home indicator 34; a fixed
// clock. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/staff_ids_d283c_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/profile_cover_d278_test.dart' show pumpOther;
import '../features/staff/staff_d283_test.dart';
import '../features/staff/staff_ids_d283c_test.dart';
import '../helpers/golden.dart';
import 'live_person_card_golden_test.dart' show pumpPersonCardRoom;

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language.name == 'ar';
    final name = language.name;

    testWidgets('staff_id.profile $name', (tester) async {
      await withClock(Clock.fixed(d283Now), () async {
        await pumpOther(tester, staffIdProfile(ar: ar), language: language);
        await precacheImages(tester);
        await tester.pumpAndSettle();
      });
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff_id.profile.$name.phone.png'),
      );
    });

    testWidgets('staff_id.me $name', (tester) async {
      await pumpStaffHub(tester, language: language, staffId: 'Kabso01');
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff_id.me.$name.phone.png'),
      );
    });

    testWidgets('staff_id.card $name', (tester) async {
      await pumpPersonCardRoom(
        tester,
        language: language,
        profile: ownerCardProfile(ar: ar),
      );
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff_id.card.$name.phone.png'),
      );
    });
  });
}
