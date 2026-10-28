// KL-033: Home feed and Live hub behaviour (tabs, swipe, search, states,
// provider honesty). KL-047: search hidden until it exists, composed states
// with real actions, LIVE badge on grid cards.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/app/shell/feed_tabs_scaffold.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

typedef _Screen = ({String name, Widget screen});

// Home has its own tabs since D47: test/features/home/home_tabs_test.dart.
const List<_Screen> _screens = [(name: 'live', screen: LiveScreen())];

/// The unavailable title each screen shows per tab.
String _unavailableTitle(AppLocalizations l10n, String screen, FeedTab tab) =>
    switch ((screen, tab)) {
      (_, FeedTab.following) => l10n.liveHubFollowingUnavailableTitle,
      (_, FeedTab.popular) => l10n.liveHubPopularUnavailableTitle,
      (_, FeedTab.latest) => l10n.liveHubNewUnavailableTitle,
    };

/// The header tab with [label] (the New tab label equals the card "New"
/// chip text, so look inside the header only).
Finder _tab(String label) =>
    find.descendant(of: find.byType(KPrimaryTabs), matching: find.text(label));

/// D131: a Live hub filter pill.
Finder _pill(LiveHubFilter f) => find.byKey(LiveHubFilterBar.pillKey(f));

bool _pillSelected(WidgetTester tester, LiveHubFilter f) =>
    tester
        .getSemantics(_pill(f))
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

/// D131: Popular ▾ Following (Popular's menu).
Future<void> _showFollowing(WidgetTester tester) async {
  if (!_pillSelected(tester, LiveHubFilter.popular)) {
    await tester.tap(_pill(LiveHubFilter.popular));
    await tester.pumpAndSettle();
  }
  await tester.tap(_pill(LiveHubFilter.popular));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(LiveHubFilterBar.menuFollowingKey));
  await tester.pumpAndSettle();
}

/// Pumps [screen]; live discovery answers from [live] (default: hosting
/// switched off, the production state today).
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AppLanguage language = AppLanguage.en,
  List<Override> overrides = const [],
  FakeLiveRepository? live,
}) async {
  await pumpScreen(
    tester,
    screen,
    language: language,
    overrides: [
      ...liveOverrides(
        live ?? FakeLiveRepository(hostingEnabled: false),
        language: language,
      ),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (:name, :screen) in _screens) {
    group(name, () {
      testWidgets('defaults to Popular; D124: a top bar with the Kabso '
          'title, search and the bell, no app bar; D131: the filter row '
          'under it', (tester) async {
        final l10n = l10nFor(AppLanguage.en);
        await _pump(tester, screen);
        expect(_pillSelected(tester, LiveHubFilter.popular), isTrue);
        expect(_pillSelected(tester, LiveHubFilter.nearby), isFalse);
        expect(
          find.text(_unavailableTitle(l10n, name, FeedTab.popular)),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(KLogo), findsNothing);
        // No tab header any more (D131), the filter row is 48 dp.
        expect(find.byType(KPrimaryTabs), findsNothing);
        expect(
          tester.getSize(find.byType(LiveHubFilterBar)).height,
          KSizes.minTouchTarget,
        );
        expect(find.byKey(FeedTabsScaffold.searchKey), findsNothing);
        expect(find.byKey(LiveHubTopBar.titleKey), findsOneWidget);
        expect(find.text(l10n.liveHubBrand), findsOneWidget);
        expect(find.byKey(LiveHubTopBar.searchKey), findsOneWidget);
        expect(find.byKey(NotificationsBell.bellKey), findsOneWidget);
        expect(
          tester.getRect(find.byKey(LiveHubTopBar.titleKey)).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(LiveHubFilterBar)).top),
        );
      });

      testWidgets('a filter switches the list and its copy', (tester) async {
        final l10n = l10nFor(AppLanguage.en);
        await _pump(tester, screen);
        await _showFollowing(tester);
        expect(
          find.text(_unavailableTitle(l10n, name, FeedTab.following)),
          findsOneWidget,
        );
        await tester.tap(_pill(LiveHubFilter.featured));
        await tester.pumpAndSettle();
        expect(_pillSelected(tester, LiveHubFilter.featured), isTrue);
        expect(
          find.text(_unavailableTitle(l10n, name, FeedTab.popular)),
          findsOneWidget,
        );
      });

      for (final language in AppLanguage.values) {
        testWidgets('the filter row mirrors in ${language.name}: Nearby at '
            'the reading start, 14.5 pt in', (tester) async {
          await _pump(tester, screen, language: language);
          final nearby = tester.getRect(
            find.descendant(
              of: _pill(LiveHubFilter.nearby),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final popular = tester.getRect(_pill(LiveHubFilter.popular));
          final width =
              tester.view.physicalSize.width / tester.view.devicePixelRatio;
          if (language == AppLanguage.ar) {
            expect(nearby.center.dx, greaterThan(popular.center.dx));
            expect(width - nearby.right, closeTo(14.5, 0.5));
          } else {
            expect(nearby.center.dx, lessThan(popular.center.dx));
            expect(nearby.left, closeTo(14.5, 0.5));
          }
        });
      }

      testWidgets('KL-047: the unavailable state is a composed block with a '
          'primary action, placed in the space under the header', (
        tester,
      ) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await _pump(tester, screen);
        final state = find.byKey(const Key('feed.unavailable'));
        final block = tester.getRect(
          find.descendant(of: state, matching: find.byType(Column)).first,
        );
        final header = tester.getRect(find.byType(LiveHubFilterBar));
        expect(block.top, greaterThan(header.bottom));
        final region = 852 - header.bottom;
        final centre = (block.center.dy - header.bottom) / region;
        expect(centre, inInclusiveRange(0.3, 0.5));
        expect(block.center.dx, closeTo(393 / 2, 1));
        expect(block.bottom, lessThan(852));
        expect(
          find.descendant(of: state, matching: find.byType(KButton)),
          findsOneWidget,
        );
        expect(
          tester
              .widget<KButton>(
                find.descendant(of: state, matching: find.byType(KButton)),
              )
              .variant,
          KButtonVariant.primary,
        );
        // The unavailable state comes from GET /live/config, which can
        // change: pull-to-refresh re-checks it (KL-038).
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });
  }

  group('search (KL-047)', () {
    // The Reels tab shows Search by owner decision (D55,
    // test/features/home/home_tabs_test.dart); the live hub keeps KL-047.
    for (final (nav, key) in const [('home', Key('nav.home'))]) {
      testWidgets('not in the tab header on $nav in the full app', (
        tester,
      ) async {
        await pumpKabsoApp(
          tester,
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(storedUser: testUser()),
            ),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        // The tab header has none; D124: the hub's top bar has one.
        expect(find.byKey(FeedTabsScaffold.searchKey), findsNothing);
        expect(find.byKey(LiveHubTopBar.searchKey), findsOneWidget);
      });
    }

    // The one switch (searchAvailable) re-enables it: the control is then
    // a labelled 48 dp target at the reading end that opens Discover.
    for (final language in AppLanguage.values) {
      testWidgets('when enabled: 48 dp, labelled, at the reading end, opens '
          'Discover (${language.name})', (tester) async {
        final l10n = l10nFor(language);
        final router = GoRouter(
          initialLocation: AppRoutes.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => FeedTabsScaffold(
                showSearch: true,
                pageBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
            GoRoute(
              path: AppRoutes.discover,
              builder: (_, _) => const DiscoverScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          // D147: the search home reads trends and lives (fakes, empty).
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
              liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: language.locale,
              supportedLocales: KabsoApp.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              theme: buildAppTheme(
                brightness: Brightness.dark,
                locale: language.locale,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final search = find.byKey(FeedTabsScaffold.searchKey);
        expect(tester.getSize(search), const Size.square(48));
        expect(find.byTooltip(l10n.feedSearch), findsOneWidget);
        final popular = tester.getCenter(_tab(l10n.feedTabPopular)).dx;
        expect(
          tester.getCenter(search).dx,
          language == AppLanguage.ar ? lessThan(popular) : greaterThan(popular),
        );
        await tester.tap(search);
        await tester.pumpAndSettle();
        expect(find.byType(DiscoverScreen), findsOneWidget);
      });
    }
  });

  group('Live hub', () {
    for (final width in const [393.0, 360.0]) {
      testWidgets('D124: a 2-column grid at $width dp with the live mark '
          'on every card', (tester) async {
        tester.view
          ..physicalSize = Size(width, 852)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pump(
          tester,
          const LiveScreen(),
          live: FakeLiveRepository(rooms: (_) => apiPage(apiRooms(8))),
        );
        // D131 (ref 165): 13 dp sides, 7.2 dp apart, 0.894 cards.
        final cardWidth = (width - 2 * 13 - 7.2) / 2;
        final first = tester.getRect(find.byKey(LiveHubGrid.cardKey(0)));
        final second = tester.getRect(find.byKey(LiveHubGrid.cardKey(1)));
        expect(first.width, moreOrLessEquals(cardWidth));
        expect(first.height, moreOrLessEquals(cardWidth / 0.894));
        expect(first.top, second.top);
        expect(second.left - first.right, moreOrLessEquals(7.2));
        for (final card in [first, second]) {
          expect(card.left, greaterThanOrEqualTo(13));
          expect(card.right, lessThanOrEqualTo(width - 13));
        }
        expect(
          find.descendant(
            of: find.byKey(LiveHubGrid.cardKey(0)),
            matching: find.byType(KLiveEqualizer),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('loading: a skeleton grid only after 300 ms', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveScreen(),
        overrides: liveOverrides(
          FakeLiveRepository(configGate: Completer<void>()),
        ),
      );
      final page = find.byKey(const PageStorageKey('live.popular'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.descendant(of: page, matching: find.byType(KLiveGridCardSkeleton)),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 100));
      final skeleton = find.descendant(
        of: page,
        matching: find.byType(KLiveGridCardSkeleton),
      );
      expect(skeleton, findsWidgets);
      expect(
        tester.getSize(skeleton.first).width,
        moreOrLessEquals((393 - 26 - 7.2) / 2),
      );
    });

    testWidgets('empty Following offers "See popular", which switches tab', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(tester, const LiveScreen(), live: FakeLiveRepository());
      expect(find.text(l10n.liveHubEmptyTitle), findsOneWidget);
      expect(find.text(l10n.feedSeePopular), findsNothing);

      await _showFollowing(tester);
      expect(find.text(l10n.liveHubFollowingEmptyTitle), findsOneWidget);
      await tester.tap(find.text(l10n.feedSeePopular));
      await tester.pumpAndSettle();
      expect(_pillSelected(tester, LiveHubFilter.popular), isTrue);
      expect(
        find.descendant(
          of: _pill(LiveHubFilter.popular),
          matching: find.text(l10n.liveHubFilterPopular),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offline (QA-003): its own state with Try again that re-runs '
        'the load', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final live = FakeLiveRepository()
        ..configFailure = const NetworkFailure.offline();
      await _pump(tester, const LiveScreen(), live: live);
      expect(find.byKey(FeedRegion.offlineKey), findsOneWidget);
      expect(find.text(l10n.feedOfflineTitle), findsOneWidget);
      expect(find.text(l10n.feedOfflineBody), findsOneWidget);
      expect(find.text(l10n.liveHubErrorTitle), findsNothing);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final before = live.configCalls;
      live.configFailure = null;
      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();
      expect(live.configCalls, before + 1);
      expect(find.text(l10n.liveHubEmptyTitle), findsOneWidget);
    });

    testWidgets('populated: pull-to-refresh reloads the tab', (tester) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6)));
      await _pump(tester, const LiveScreen(), live: live);
      int popularCalls() =>
          live.requests.where((r) => r.tab == LiveRoomsTab.popular).length;
      final before = popularCalls();
      final configBefore = live.configCalls;
      // Pull down on the first card.
      await tester.fling(
        find.byType(KLiveGridCard).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(popularCalls(), before + 1);
      // Refresh re-checks the hosting switch.
      expect(live.configCalls, greaterThan(configBefore));
      expect(live.requests.last.cursor, isNull);
    });
  });

  group('primary tabs reduce motion', () {
    testWidgets('a tab tap jumps without animation', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: FeedTabsScaffold(
              pageBuilder: (_, tab, _) => Center(child: Text(tab.name)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(_tab(l10n.feedTabFollowing));
      await tester.pump();
      // The pager jumped: it is already exactly on the first page.
      final pager = tester.widget<PageView>(
        find.byKey(FeedTabsScaffold.pagerKey),
      );
      expect(pager.controller!.page, 0);
      expect(find.text(FeedTab.following.name), findsOneWidget);
    });
  });
}
