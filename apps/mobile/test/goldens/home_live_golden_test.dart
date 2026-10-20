// KL-033 screen goldens: the Home feed and the Live hub with the shell's
// bottom nav, in ar and en at 393×852 and 360×800 @3x, dark theme.
//
// KL-047: no search control in the header; states are composed blocks
// (88 dp disc, title, body, primary action) placed in the space under the
// header; LIVE badge and category name on cards; an offline state.
//
// Live hub states run the real controller against a fake repository
// (KL-038, contract v1.3); `live_hub.populated` renders the pure hub body
// with designed fixture covers. Data comes from test fixtures only (D35). The phone viewport carries iPhone-class insets (59 / 34, the
// wireframe convention) so the first viewport can be judged (VG-01); the
// Android viewport uses none.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../fixtures/live/live_fixtures.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_posts_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';

/// Home is shell branch 0, Live is branch 3.
// D48: Home (index 0) is the live hub; Reels (index 3) is the feed.
const _liveIndex = 0;
const _reelsIndex = 3;

Future<void> _pumpShellTab(
  WidgetTester tester, {
  required Widget screen,
  required int navIndex,
  required AppLanguage language,
  required GoldenViewport viewport,
  List<Override> overrides = const [],
}) async {
  if (viewport == GoldenViewport.phone) {
    tester.view.padding = const FakeViewPadding(
      top: 59 * GoldenViewport.pixelRatio,
      bottom: 34 * GoldenViewport.pixelRatio,
    );
    addTearDown(tester.view.resetPadding);
  }
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      // KL-060: posts read the posts API; here a server with no posts.
      overrides: [
        postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
        // The feeds are scoped to the signed-in user: no platform storage.
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ...overrides,
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: screen,
          bottomNavigationBar: KBottomNav(
            items: shellNavItems(context.l10n),
            currentIndex: navIndex,
            onSelect: (_) {},
          ),
        ),
      ),
    ),
    language: language,
    viewport: viewport,
    bare: true,
  );
}

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final viewport in GoldenViewport.values) {
        final vp = viewport.name;

        Future<void> golden(
          WidgetTester tester,
          String name, {
          required Widget screen,
          required int navIndex,
          List<Override> overrides = const [],
          Duration extraPump = Duration.zero,
          bool scrollToEnd = false,
        }) => withClock(Clock.fixed(fixtureNow), () async {
          await _pumpShellTab(
            tester,
            screen: screen,
            navIndex: navIndex,
            language: language,
            viewport: viewport,
            overrides: overrides,
          );
          if (extraPump > Duration.zero) {
            await tester.pump(extraPump);
            await precacheImages(tester);
          }
          if (scrollToEnd) {
            // D50: the last stream of the full-screen pager.
            tester
                .widget<PageView>(
                  find.byKey(
                    const PageStorageKey<String>('live.pager.popular'),
                  ),
                )
                .controller!
                .jumpToPage(1000);
            // The load-more progress line animates: pump, never settle.
            await tester.pump(const Duration(milliseconds: 500));
          }
          await expectScreenGolden(
            name,
            language: language,
            viewport: viewport,
          );
        });

        // KL-060: was `reels_tab.unavailable`; posts now have an API, so
        // with no posts the Posts mode shows its empty state.
        testWidgets('reels_tab.posts_empty ($vp)', (tester) async {
          await golden(
            tester,
            'reels_tab.posts_empty',
            screen: const FeedScreen(),
            navIndex: _reelsIndex,
          );
        });

        testWidgets('reels_tab.populated ($vp)', (tester) async {
          await golden(
            tester,
            'reels_tab.populated',
            screen: const FeedScreen(),
            navIndex: _reelsIndex,
            overrides: [
              homePostsProvider.overrideWith(
                (ref, _) => FeedItems<FeedPostData>(feedPosts(language)),
              ),
              homeStoriesProvider.overrideWith(
                (ref) => FeedItems<FeedStoryData>(feedStories(language)),
              ),
            ],
          );
        });

        testWidgets('reels_tab.posts ($vp)', (tester) async {
          await golden(
            tester,
            'reels_tab.posts',
            // Posts without a stories source: no tray.
            screen: const FeedScreen(),
            navIndex: _reelsIndex,
            overrides: [
              homePostsProvider.overrideWith(
                (ref, _) => FeedItems<FeedPostData>(feedPosts(language)),
              ),
            ],
          );
        });

        testWidgets('reels_tab.reels ($vp)', (tester) async {
          await golden(
            tester,
            'reels_tab.reels',
            screen: const FeedScreen(initialTab: HomeTab.reels),
            navIndex: _reelsIndex,
            overrides: [
              homeReelsProvider.overrideWith(
                (ref, _) => FeedItems<FeedReelData>(feedReels(language)),
              ),
            ],
          );
        });

        testWidgets('reels_tab.reels.unavailable ($vp)', (tester) async {
          await golden(
            tester,
            'reels_tab.reels.unavailable',
            screen: const FeedScreen(initialTab: HomeTab.reels),
            navIndex: _reelsIndex,
          );
        });

        testWidgets('live_hub.unavailable ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.unavailable',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(
              FakeLiveRepository(hostingEnabled: false),
              language: language,
            ),
          );
        });

        // Layout review with designed fixture covers (D35): the pure hub
        // body, as in the debug gallery.
        testWidgets('live_hub.populated ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.populated',
            screen: Theme(
              data: buildAppTheme(
                brightness: Brightness.dark,
                locale: language.locale,
              ),
              child: FeedTabsScaffold(
                overlayHeader: true,
                centerTabs: true,
                pageBuilder: (context, tab, selectTab) => LiveHubBody(
                  tab: tab,
                  content: AsyncData(FeedItems(hubRooms(language))),
                  onRefresh: () async {},
                  onRetry: () {},
                  onSelectTab: (_) {},
                ),
              ),
            ),
            navIndex: _liveIndex,
          );
        });

        // KL-038: what the v1.3 API returns today when hosting is on —
        // server categories, viewerCount 0 ("New"), no covers (host avatar
        // fallback), more pages to come.
        testWidgets('live_hub.categories ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.categories',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(
              FakeLiveRepository(
                categories: apiCategories(ar: language == AppLanguage.ar),
                rooms: (request) => request.cursor == null
                    ? apiPage(
                        apiRooms(
                          6,
                          ar: language == AppLanguage.ar,
                          categories: apiCategories(
                            ar: language == AppLanguage.ar,
                          ),
                        ),
                        nextCursor: 'c1',
                      )
                    : Completer<LiveRoomPage>().future,
              ),
              language: language,
            ),
          );
        });

        testWidgets('live_hub.loading ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.loading',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(
              FakeLiveRepository(configGate: Completer<void>()),
              language: language,
            ),
            // Skeletons appear after the 300 ms reveal delay.
            extraPump: const Duration(milliseconds: 400),
          );
        });

        // QA-003: the client-only NETWORK_OFFLINE has its own state.
        testWidgets('live_hub.offline ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.offline',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(
              FakeLiveRepository()
                ..configFailure = const NetworkFailure.offline(),
              language: language,
            ),
          );
        });

        testWidgets('live_hub.empty ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.empty',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(FakeLiveRepository(), language: language),
          );
        });

        // Load-more states (HL-H5) on the last full-screen stream (D50).
        for (final (name, next) in <(String, RoomsHandler)>[
          // The next page is still loading: a progress line (D50).
          ('live_hub.footer_loading', (_) => Completer<LiveRoomPage>().future),
          // The next page failed: inline "Couldn't load more · Retry".
          (
            'live_hub.footer_error',
            (_) => throw const NetworkFailure.offline(),
          ),
        ]) {
          testWidgets('$name ($vp)', (tester) async {
            await golden(
              tester,
              name,
              screen: const LiveScreen(),
              navIndex: _liveIndex,
              overrides: liveOverrides(
                FakeLiveRepository(
                  rooms: (request) => request.cursor == null
                      ? apiPage(
                          apiRooms(6, ar: language == AppLanguage.ar),
                          nextCursor: 'c1',
                        )
                      : next(request),
                ),
                language: language,
              ),
              scrollToEnd: true,
            );
          });
        }

        testWidgets('live_hub.end ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.end',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(
              FakeLiveRepository(
                rooms: (_) =>
                    apiPage(apiRooms(6, ar: language == AppLanguage.ar)),
              ),
              language: language,
            ),
            scrollToEnd: true,
          );
        });
      }
    });
  });
}
