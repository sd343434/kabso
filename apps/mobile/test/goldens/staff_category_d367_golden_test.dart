// D367 (owner: «في صفحة الموظفين يظهر تصنيف مثل شاعر، يجب إلغاؤه من صفحة
// المشرفين»): a Kabso Team profile never shows the account category, even
// when an older server still sends one.
//
//   staff_category.profile  a moderator's profile seen by a visitor; the
//                           payload carries «شاعر» (an older server's)
//   staff_category.own      the same staff member's own profile
//   staff_category.founder  the founder's page with a category in the payload
//
// 393 × 852 with the status bar 59 and the home indicator 34; a fixed
// clock. Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/staff_category_d367_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:material_ui/material_ui.dart';

import '../features/owner_profile/owner_profile_d301_test.dart'
    show pumpOwnerVisitor, testD301;
import '../features/profile/profile_cover_d278_test.dart'
    show coverBytes, me, pumpOther, pumpOwn;
import '../features/staff/staff_d283_test.dart';
import '../features/staff/staff_ids_d283c_test.dart';
import '../fixtures/owner/owner_fixtures.dart';
import '../helpers/golden.dart';

void main() {
  late final poster = paintOwnerPoster();
  setUpAll(loadAppFonts);

  testWidgets('staff_category.profile ar', (tester) async {
    await withClock(Clock.fixed(d283Now), () async {
      await pumpOther(
        tester,
        staffIdProfile(ar: true).copyWith(category: AccountCategory.poet),
        language: AppLanguage.ar,
      );
      await precacheImages(tester);
      await tester.pumpAndSettle();
    });
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/staff_category.profile.ar.phone.png'),
    );
  });

  testWidgets('staff_category.own ar', (tester) async {
    await withClock(Clock.fixed(d283Now), () async {
      await pumpOwn(
        tester,
        language: AppLanguage.ar,
        user: me(ar: true).copyWith(
          kabsoTeam: true,
          staffId: 'Kabso01',
          category: AccountCategory.poet,
        ),
      );
      await precacheImages(tester);
      await tester.pumpAndSettle();
    });
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/staff_category.own.ar.phone.png'),
    );
  });

  group('founder', () {
    setUp(() async {
      final bytes = await poster;
      profileCoverImageFor = (_) => MemoryImage(coverBytes);
      ownerPosterImageFor = (_) => MemoryImage(bytes);
    });
    tearDown(() {
      profileCoverImageFor = NetworkImage.new;
      ownerPosterImageFor = NetworkImage.new;
    });

    testD301('staff_category.founder ar', (tester) async {
      await pumpOwnerVisitor(
        tester,
        language: AppLanguage.ar,
        profile: ownerProfile(ar: true)
            .copyWith(category: AccountCategory.poet),
      );
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/staff_category.founder.ar.phone.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
