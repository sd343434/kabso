// D335: the cover is back (the photo at the reading start over its edge,
// §10.73.7); D316 had removed it. The names are kept so the history of the
// set stays readable.
//
// D278 (owner: «اظهر ملف شخصي بغلاف بهذا الحجم ويغطي للاعلى وايقونات دردشة
// والشات»; «استخدم ازراري»): the profile with the tall full-bleed cover.
//
//   profile.cover.other  someone else's profile with a cover photo (light):
//                        the VIP frame, the name with the VIP badge, the
//                        @username, the counts, «متابعة» / chat / more
//   profile.cover.own    the own profile with a cover (dark): «تعديل الملف»,
//                        back / drafts / settings
//   profile.cover.other.dark / profile.cover.own.light  the other mode (D278c:
//                        the block under the picture is the page colour)
//
// 393 × 852 with the status bar 59 and the home indicator 34. The cover is
// a neutral sample picture (test/fixtures/profile/cover_sample.jpg).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/profile_cover_d278_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/profile_cover_d278_test.dart'
    show coverBytes, otherProfile, pumpOther, pumpOwn;
import '../helpers/golden.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
  });

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    testWidgets('profile.cover.other ${language.name}', (tester) async {
      await pumpOther(tester, otherProfile(ar: ar), language: language);
      await precacheImages(tester);
      // D335 (owner 1): the profile's cover is shown again.
      expect(find.byKey(ProfileCoverHeader.coverKey), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/profile.cover.other.${language.name}.phone.png'),
      );
    });

    testWidgets('profile.cover.own ${language.name}', (tester) async {
      await pumpOwn(tester, language: language, brightness: Brightness.dark);
      await precacheImages(tester);
      // D335 (owner 1): the profile's cover is shown again.
      expect(find.byKey(ProfileCoverHeader.coverKey), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/profile.cover.own.${language.name}.phone.png'),
      );
    });

    // D278c: the block under the picture follows the theme — the other
    // mode of each page too.
    testWidgets('profile.cover.other.dark ${language.name}', (tester) async {
      await pumpOther(
        tester,
        otherProfile(ar: ar),
        language: language,
        brightness: Brightness.dark,
      );
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'png/profile.cover.other.dark.${language.name}.phone.png',
        ),
      );
    });

    testWidgets('profile.cover.own.light ${language.name}', (tester) async {
      await pumpOwn(tester, language: language);
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'png/profile.cover.own.light.${language.name}.phone.png',
        ),
      );
    });
  });
}
