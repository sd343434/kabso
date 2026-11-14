// D375 (owner «واجعل الستوري تظهر بالخارج بنفس طريقة هذه ١٠٠٪» and «واجعل
// القصص في صفحة اللحظات في الاعلى وليس في صفحة الرسائل»): «اللحظات» with
// the stories tray as cards at its top, under the Posts · Reels tabs, then
// the posts.
//
//   moments.tray.<ar|en>.<dark|light>.phone
//
// «قصتك» (no story yet, the red «+»), five accounts (one seen: dimmed with
// a grey border; one live: «LIVE»), the row cut at the screen's edge.
// 393 × 852 with the status bar 59 and the home indicator 34; the clock is
// pinned (fixtureNow). Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/stories_tray_d375_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_fixtures.dart';
import '../fixtures/stories/story_carousel_d375_fixtures.dart';
import '../helpers/fake_posts_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';

void main() {
  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      final name = 'moments.tray.${language.name}.${brightness.name}.phone.png';
      testWidgets('moments with the tray (${language.name} '
          '${brightness.name})', (tester) async {
        await withClock(Clock.fixed(fixtureNow), () async {
          tester.view.padding = const FakeViewPadding(
            top: 59 * GoldenViewport.pixelRatio,
            bottom: 34 * GoldenViewport.pixelRatio,
          );
          addTearDown(tester.view.resetPadding);
          final ar = language == AppLanguage.ar;
          await pumpGolden(
            tester,
            ProviderScope(
              retry: (_, _) => null,
              overrides: [
                postsRepositoryProvider.overrideWithValue(
                  FakePostsRepository(),
                ),
                secureTokenStoreProvider.overrideWithValue(
                  InMemoryTokenStore(),
                ),
                homeMixedPostsProvider.overrideWith(
                  (ref) => FeedItems<FeedPostData>(feedPosts(language)),
                ),
                homeStoriesProvider.overrideWith(
                  (ref) => FeedItems<FeedStoryData>(d375TrayCards(ar: ar)),
                ),
              ],
              child: Builder(
                builder: (context) => Scaffold(
                  body: const FeedScreen(),
                  bottomNavigationBar: shellNavBar(
                    context.l10n,
                    currentIndex: 2,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
            language: language,
            brightness: brightness,
            bare: true,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('png/$name'),
          );
        });
      });
    }
  }
}
