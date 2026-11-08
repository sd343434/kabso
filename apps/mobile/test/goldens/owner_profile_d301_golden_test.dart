// D301 (owner, §10.112): the app owner's profile «صفحة صاحب البرنامج».
//
//   owner.visitor  a visitor: the video cover's poster with the sound button
//                  (D307: no «فيديو» pill; the round play button shows only
//                  because goldens run with reduce motion), the photo centred
//                  with the name and seal under it, no «فريق كابسو»
//                  badge, the default bilingual bio, «متابعة المؤسس» (no
//                  shadow) / «اقترح ميزة / أبلغ» (outline only), «إعلانات
//                  رسمية», the start of «رحلة Kabso»
//   owner.own      the owner himself: «تعديل الملف», the default bio and
//                  «لوحة المؤسس» (خاص, the income blurred), «إعلانات رسمية»
//   owner.feedTop  D301 follow-up: the posts feed starts with the owner's
//                  latest announcement («رسمي»), in the app's language
//   owner.composer D301 follow-up: the bilingual announcement composer
//   owner.profit   §10.112.10: «الربح» in the dashboard's details — «الدخل
//                  قبل» opened with its parts, each deduction, «بعد»
//   owner.costs    §10.112.10: «تكاليف ثابتة», the owner's fixed costs (D307:
//                  the details behind sit at a different scroll offset, as
//                  «بايو المؤسس» now ends them)
//   owner.search   §10.112.9: the founder always in search — the card before
//                  anything is typed and the row pinned above the results
//
// Each in light and dark, Arabic and English; 393 × 852 with the status bar
// 59 and the home indicator 34. The poster is painted by the test (no
// third-party picture).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/owner_profile_d301_golden_test.dart
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_sections.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:material_ui/material_ui.dart';

import '../features/owner_profile/founder_search_d301_test.dart'
    show pumpFounderSearch, typeSearch;
import '../features/owner_profile/owner_profile_d301_test.dart'
    show pumpComposer, pumpFeedTop, pumpOwnerOwn, pumpOwnerVisitor, testD301;
import '../features/owner_profile/owner_profit_d301_test.dart'
    show pumpCostsEditor, pumpProfitDetails;
import '../features/profile/profile_cover_d278_test.dart' show coverBytes;
import '../fixtures/owner/owner_fixtures.dart';
import '../helpers/golden.dart';

void main() {
  late final poster = paintOwnerPoster();
  setUpAll(loadAppFonts);
  setUp(() async {
    final bytes = await poster;
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
    ownerPosterImageFor = (_) => MemoryImage(bytes);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
    ownerPosterImageFor = NetworkImage.new;
  });

  forEachLanguage((language) {
    for (final brightness in Brightness.values) {
      final tag = '${brightness.name}.${language.name}';
      testD301('owner.profit $tag', (tester) async {
        await pumpProfitDetails(
          tester,
          language: language,
          brightness: brightness,
        );
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/owner.profit.$tag.phone.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
      testD301('owner.costs $tag', (tester) async {
        await pumpCostsEditor(
          tester,
          language: language,
          brightness: brightness,
        );
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/owner.costs.$tag.phone.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final brightness in Brightness.values) {
      final tag = '${brightness.name}.${language.name}';
      testD301('owner.search $tag', (tester) async {
        await pumpFounderSearch(
          tester,
          language: language,
          brightness: brightness,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/owner.search.card.$tag.phone.png'),
        );
        await typeSearch(tester, '@k');
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/owner.search.typing.$tag.phone.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testD301('owner.feedTop ${language.name}', (tester) async {
      await pumpFeedTop(tester, language: language);
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('png/owner.feedTop.light.${language.name}.phone.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testD301('owner.composer ${language.name}', (tester) async {
      await pumpComposer(tester, language: language);
      await precacheImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'png/owner.composer.light.${language.name}.phone.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
    });

    for (final brightness in Brightness.values) {
      final tag = '${brightness.name}.${language.name}';
      testD301('owner.visitor $tag', (tester) async {
        await pumpOwnerVisitor(
          tester,
          language: language,
          brightness: brightness,
        );
        await precacheImages(tester);
        expect(find.byKey(OwnerCoverVideoLayer.layerKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/owner.visitor.$tag.phone.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });

      testD301('owner.own $tag', (tester) async {
        await pumpOwnerOwn(tester, language: language, brightness: brightness);
        await precacheImages(tester);
        expect(find.byKey(FounderDashboardCard.cardKey), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/owner.own.$tag.phone.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
