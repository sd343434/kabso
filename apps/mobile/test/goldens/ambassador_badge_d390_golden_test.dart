// D390 follow-up (owner 2026-11-13): the exclusive ambassador badge shown to
// everyone — on the public profile's badge row and on the live person card —
// while the membership is ACTIVE (`PublicProfile.ambassador`).
//
//   ambassador_badge_d390.profile       another person's profile, a
//                                       Constellation ambassador
//   ambassador_badge_d390.person_card   the person card in an audio room,
//                                       a Star ambassador
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/ambassador_badge_d390_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/profile_cover_d278_test.dart'
    show coverBytes, otherProfile, pumpOther;
import '../helpers/golden.dart';
import 'live_person_card_golden_test.dart'
    show personCardProfile, pumpPersonCardRoom;

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

    testWidgets('ambassador_badge_d390.profile ${language.name}', (
      tester,
    ) async {
      await pumpOther(
        tester,
        otherProfile(ar: ar).copyWith(ambassadorLevel: 'CONSTELLATION'),
        language: language,
      );
      await precacheImages(tester);
      expect(find.byKey(ProfileHeaderView.ambassadorBadgeKey), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'png/ambassador_badge_d390.profile.${language.name}.phone.png',
        ),
      );
    });

    testWidgets('ambassador_badge_d390.person_card ${language.name}', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 13, 12)), () async {
        await pumpPersonCardRoom(
          tester,
          language: language,
          profile: personCardProfile(ar: ar).copyWith(ambassadorLevel: 'STAR'),
        );
        // The level's medal (an asset image) drawn in the capture.
        await precacheImages(tester);
        expect(find.byKey(LivePersonSheet.ambassadorBadgeKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/ambassador_badge_d390.person_card.${language.name}.phone.png',
          ),
        );
      });
    });
  });
}
