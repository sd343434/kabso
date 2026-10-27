// KL-033 screen goldens: the Home feed and the Live hub with the shell's
// bottom nav, in ar and en at 393×852 and 360×800 @3x, dark theme (D124:
// the live hub also in the light theme).
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
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_kind_switch.dart';
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
  Brightness brightness = Brightness.dark,
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
    brightness: brightness,
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
          Brightness brightness = Brightness.dark,
        }) => withClock(Clock.fixed(fixtureNow), () async {
          await _pumpShellTab(
            tester,
            screen: screen,
            navIndex: navIndex,
            language: language,
            viewport: viewport,
            overrides: overrides,
            brightness: brightness,
          );
          if (extraPump > Duration.zero) {
            await tester.pump(extraPump);
            await precacheImages(tester);
          }
          if (scrollToEnd) {
            // D124: the bottom of the grid (the footer under it).
            for (var i = 0; i < 4; i++) {
              await tester.drag(
                find.byType(CustomScrollView).first,
                const Offset(0, -1500),
              );
              // The load-more progress animates: pump, never settle.
              await tester.pump(const Duration(milliseconds: 500));
            }
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
        // body, as in the debug gallery. D124: the 2-column grid with the
        // banner carousel after the 4th card (its pictures are network
        // images: the placeholder surface here), in the dark and the light
        // app theme (the hub follows the app theme).
        for (final brightness in Brightness.values) {
          final suffix = brightness == Brightness.light ? '.light' : '';
          testWidgets('live_hub.populated$suffix ($vp)', (tester) async {
            await golden(
              tester,
              'live_hub.populated$suffix',
              brightness: brightness,
              screen: FeedTabsScaffold(
                centerTabs: true,
                // D129: the fixture rooms are video lives (PK, multi-guest).
                topBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LiveHubTopBar(showNotifications: false),
                    LiveHubKindSwitch(
                      selected: LiveRoomsKind.video,
                      onSelected: (_) {},
                    ),
                  ],
                ),
                pageBuilder: (context, tab, selectTab) => LiveHubBody(
                  tab: tab,
                  content: AsyncData(FeedItems(hubRooms(language))),
                  banners: [
                    for (var i = 0; i < 3; i++)
                      HomeBanner(
                        id: 'banner-$i',
                        imageUrl: 'https://media.example.test/$i.webp',
                        link: '/families',
                      ),
                  ],
                  onRefresh: () async {},
                  onRetry: () {},
                  onSelectTab: (_) {},
                ),
              ),
              navIndex: _liveIndex,
            );
          });
        }

        // D129: the real hub on each side of the voice rooms · live switch,
        // the server answering `kind` (rooms 0–5 voice, 6–11 video), in the
        // dark and the light theme.
        for (final kind in LiveRoomsKind.values) {
          for (final brightness in Brightness.values) {
            final suffix = brightness == Brightness.light ? '.light' : '';
            final name = 'live_hub.kind_${kind.wire}$suffix';
            testWidgets('$name ($vp)', (tester) async {
              final ar = language == AppLanguage.ar;
              final rooms = [
                for (final (i, room) in apiRooms(
                  12,
                  ar: ar,
                  categories: apiCategories(ar: ar),
                ).indexed)
                  room.copyWith(
                    mode: i < 6
                        ? LiveRoomMode.audio
                        : const [
                            LiveRoomMode.solo,
                            LiveRoomMode.multi,
                            LiveRoomMode.pk,
                          ][i % 3],
                    viewerCount: const [
                      128,
                      0,
                      2400,
                      37,
                      910,
                      5,
                      15300,
                      0,
                      642,
                      88,
                      1200,
                      9,
                    ][i],
                  ),
              ];
              await golden(
                tester,
                name,
                brightness: brightness,
                screen: const LiveScreen(),
                navIndex: _liveIndex,
                overrides: liveOverrides(
                  FakeLiveRepository(
                    categories: apiCategories(ar: ar),
                    rooms: (request) => apiPage([
                      for (final room in rooms)
                        if (request.kind == null ||
                            LiveRoomsKind.of(room.mode) == request.kind)
                          room,
                    ]),
                  ),
                  language: language,
                  kind: kind,
                ),
              );
            });
          }
        }

        // KL-038: what the v1.3 API returns today when hosting is on —
        // server categories, viewerCount 0 ("New"), no covers (host avatar
        // fallback), more pages to come.
        for (final brightness in Brightness.values) {
          final suffix = brightness == Brightness.light ? '.light' : '';
          testWidgets('live_hub.categories$suffix ($vp)', (tester) async {
            await golden(
              tester,
              'live_hub.categories$suffix',
              brightness: brightness,
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
        }

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

        // Load-more states (HL-H5) under the grid (D124).
        for (final (name, next) in <(String, RoomsHandler)>[
          // The next page is still loading: a progress footer.
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
