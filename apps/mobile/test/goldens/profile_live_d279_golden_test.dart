// D279 (owner): the profile's «في بث الآن» card under the tall cover.
//
//   profile.live.other  someone else's profile while live (light): «في بث
//                       الآن», «مباشر منذ 1س 17د», 93 viewers · 41.9K
//                       points, «انضم» in Kabso red
//   profile.live.own    the own profile while live (dark): «أنت في بث الآن»,
//                       «عودة للبث»
//
// 393 × 852 with the status bar 59 and the home indicator 34. The clock is
// fixed (the live started 1 h 17 min before it), so nothing depends on
// today's date.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/profile_live_d279_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_live_card.dart';
import 'package:material_ui/material_ui.dart';

import '../features/profile/profile_cover_d278_test.dart'
    show coverBytes, pumpOther, pumpOwn;
import '../features/profile/profile_live_card_d279_test.dart'
    show atNow, d279Other, d279Own;
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
    testWidgets('profile.live.other ${language.name}', (tester) async {
      await atNow(() async {
        await pumpOther(tester, d279Other(ar: ar), language: language);
        await precacheImages(tester);
        expect(find.byType(ProfileLiveCard), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/profile.live.other.${language.name}.phone.png',
          ),
        );
      });
    });

    testWidgets('profile.live.own ${language.name}', (tester) async {
      await atNow(() async {
        await pumpOwn(
          tester,
          language: language,
          brightness: Brightness.dark,
          stats: d279Own(ar: ar),
        );
        await precacheImages(tester);
        expect(find.byType(ProfileLiveCard), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/profile.live.own.${language.name}.phone.png'),
        );
      });
    });
  });
}
