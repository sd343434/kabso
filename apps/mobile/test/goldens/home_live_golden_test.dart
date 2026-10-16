// KL-033 screen goldens: the Home feed and the Live hub with the shell's
// bottom nav, in ar and en at 393×852 and 360×800 @3x, dark theme.
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
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/home_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../fixtures/live/live_fixtures.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/golden.dart';

/// Home is shell branch 0, Live is branch 3.
const _homeIndex = 0;
const _liveIndex = 3;

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
      overrides: overrides,
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
            await tester.drag(
              find.byType(KLiveCoverCard).first,
              const Offset(0, -3000),
            );
            await tester.pumpAndSettle();
          }
          await expectScreenGolden(
            name,
            language: language,
            viewport: viewport,
          );
        });

        testWidgets('home.unavailable ($vp)', (tester) async {
          await golden(
            tester,
            'home.unavailable',
            screen: const HomeScreen(),
            navIndex: _homeIndex,
          );
        });

        testWidgets('home.populated ($vp)', (tester) async {
          await golden(
            tester,
            'home.populated',
            screen: const HomeScreen(),
            navIndex: _homeIndex,
            overrides: [
              homeFeedProvider.overrideWith(
                (ref, tab) => FeedItems<FeedPostData>(feedPosts(language)),
              ),
            ],
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
            screen: FeedTabsScaffold(
              pageBuilder: (context, tab, selectTab) => LiveHubBody(
                tab: tab,
                content: AsyncData(FeedItems(hubRooms(language))),
                onRefresh: () async {},
                onRetry: () {},
                onSeePopular: () {},
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
                        apiRooms(6, ar: language == AppLanguage.ar),
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

        testWidgets('live_hub.empty ($vp)', (tester) async {
          await golden(
            tester,
            'live_hub.empty',
            screen: const LiveScreen(),
            navIndex: _liveIndex,
            overrides: liveOverrides(FakeLiveRepository(), language: language),
          );
        });

        // Footer states (HL-H5), scrolled to the end of the list.
        for (final (name, next) in <(String, RoomsHandler)>[
          // The next page is still loading: 2 footer skeletons.
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
