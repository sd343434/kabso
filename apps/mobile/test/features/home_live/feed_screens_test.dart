// KL-033: Home feed and Live hub behaviour (tabs, swipe, search, states,
// provider honesty). KL-047: search hidden until it exists, composed states
// with real actions, LIVE badge on grid cards.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
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
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/home_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

typedef _Screen = ({String name, Widget screen});

const List<_Screen> _screens = [
  (name: 'home', screen: HomeScreen()),
  (name: 'live', screen: LiveScreen()),
];

/// The unavailable title each screen shows per tab.
String _unavailableTitle(AppLocalizations l10n, String screen, FeedTab tab) =>
    switch ((screen, tab)) {
      ('home', FeedTab.following) => l10n.homeFollowingUnavailableTitle,
      ('home', FeedTab.popular) => l10n.homePopularUnavailableTitle,
      ('home', FeedTab.latest) => l10n.homeNewUnavailableTitle,
      (_, FeedTab.following) => l10n.liveHubFollowingUnavailableTitle,
      (_, FeedTab.popular) => l10n.liveHubPopularUnavailableTitle,
      (_, FeedTab.latest) => l10n.liveHubNewUnavailableTitle,
    };

String _tabLabel(AppLocalizations l10n, FeedTab tab) => switch (tab) {
  FeedTab.following => l10n.feedTabFollowing,
  FeedTab.popular => l10n.feedTabPopular,
  FeedTab.latest => l10n.feedTabNew,
};

/// The header tab with [label] (the New tab label equals the card "New"
/// chip text, so look inside the header only).
Finder _tab(String label) =>
    find.descendant(of: find.byType(KPrimaryTabs), matching: find.text(label));

bool _selected(WidgetTester tester, String label) =>
    tester
        .getSemantics(_tab(label))
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

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
  group('production providers are honest (D35)', () {
    test('every Home tab is unavailable, never sample data', () {
      final container = ProviderContainer.test();
      for (final tab in FeedTab.values) {
        expect(
          container.read(homeFeedProvider(tab)).value,
          isA<FeedUnavailable<FeedPostData>>(),
          reason: 'home $tab',
        );
      }
    });
    // Live tabs: test/features/live/live_rooms_controller_test.dart.
  });

  for (final (:name, :screen) in _screens) {
    group(name, () {
      testWidgets('defaults to Popular; no title, wordmark or app bar', (
        tester,
      ) async {
        final l10n = l10nFor(AppLanguage.en);
        await _pump(tester, screen);
        expect(_selected(tester, l10n.feedTabPopular), isTrue);
        expect(_selected(tester, l10n.feedTabFollowing), isFalse);
        expect(
          find.text(_unavailableTitle(l10n, name, FeedTab.popular)),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(KLogo), findsNothing);
        // VG-05: header is 48 dp with the tabs only. KL-047: no search
        // control while there is no search capability.
        expect(
          tester.getSize(find.byType(KPrimaryTabs)).height,
          KMetrics.topBarHeight,
        );
        expect(FeedTabsScaffold.searchAvailable, isFalse);
        expect(find.byKey(FeedTabsScaffold.searchKey), findsNothing);
        expect(find.byType(IconButton), findsNothing);
      });

      testWidgets('tapping a tab switches the page and its copy', (
        tester,
      ) async {
        final l10n = l10nFor(AppLanguage.en);
        await _pump(tester, screen);
        for (final tab in [
          FeedTab.following,
          FeedTab.latest,
          FeedTab.popular,
        ]) {
          await tester.tap(_tab(_tabLabel(l10n, tab)));
          await tester.pumpAndSettle();
          expect(_selected(tester, _tabLabel(l10n, tab)), isTrue);
          expect(
            find.text(_unavailableTitle(l10n, name, tab)),
            findsOneWidget,
            reason: '$tab',
          );
        }
      });

      for (final language in AppLanguage.values) {
        testWidgets(
          'swiping follows the reading direction (${language.name})',
          (tester) async {
            final l10n = l10nFor(language);
            await _pump(tester, screen, language: language);
            // The next tab (New) is towards the reading end: drag the page
            // towards the reading start (left in LTR, right in RTL).
            final towardsStart = language == AppLanguage.ar ? 300.0 : -300.0;
            await tester.fling(
              find.byKey(FeedTabsScaffold.pagerKey),
              Offset(towardsStart, 0),
              1000,
            );
            await tester.pumpAndSettle();
            expect(_selected(tester, l10n.feedTabNew), isTrue);
            expect(
              find.text(_unavailableTitle(l10n, name, FeedTab.latest)),
              findsOneWidget,
            );

            await tester.fling(
              find.byKey(FeedTabsScaffold.pagerKey),
              Offset(-towardsStart, 0),
              1000,
            );
            await tester.pumpAndSettle();
            expect(_selected(tester, l10n.feedTabPopular), isTrue);
          },
        );

        testWidgets('header mirrors in ${language.name}', (tester) async {
          final l10n = l10nFor(language);
          await _pump(tester, screen, language: language);
          final following = tester.getRect(_tab(l10n.feedTabFollowing));
          final popular = tester.getCenter(_tab(l10n.feedTabPopular)).dx;
          final width =
              tester.view.physicalSize.width / tester.view.devicePixelRatio;
          // Following sits at the reading start (RTL: the right edge).
          if (language == AppLanguage.ar) {
            expect(following.center.dx, greaterThan(popular));
            expect(following.right, greaterThan(width - KSpacing.xxl));
          } else {
            expect(following.center.dx, lessThan(popular));
            expect(following.left, lessThan(KSpacing.xxl));
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
        // The visual block (disc → actions) at real fonts, 393×852.
        final block = tester.getRect(
          find.descendant(of: state, matching: find.byType(Column)).first,
        );
        final header = tester.getRect(find.byType(KPrimaryTabs));
        expect(block.top, greaterThan(header.bottom));
        // Not a line at the top of a void: the block's centre sits in the
        // middle band of the region (a little above its centre), and it is
        // horizontally centred.
        final region = 852 - header.bottom;
        final centre = (block.center.dy - header.bottom) / region;
        expect(centre, inInclusiveRange(0.3, 0.5));
        expect(block.center.dx, closeTo(393 / 2, 1));
        expect(block.bottom, lessThan(852));
        // 88 dp icon disc and one primary (filled) action.
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
        // Home has no feed API, so nothing to refresh. The Live hub's
        // unavailable state comes from GET /live/config, which can change:
        // pull-to-refresh re-checks it (KL-038).
        expect(
          find.byType(RefreshIndicator),
          name == 'live' ? findsOneWidget : findsNothing,
        );
      });
    });
  }

  group('search (KL-047)', () {
    for (final (nav, key) in const [
      ('home', Key('nav.home')),
      ('live', Key('nav.live')),
    ]) {
      testWidgets('hidden on $nav in the full app', (tester) async {
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
        expect(find.byKey(FeedTabsScaffold.searchKey), findsNothing);
        expect(find.byTooltip('Search'), findsNothing);
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
          MaterialApp.router(
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
    testWidgets('chip row: Popular only, a single non-interactive "All"; '
        'none while live streaming is unavailable', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(tester, const LiveScreen());
      // KL-047: nothing to filter while hosting is off.
      expect(find.byKey(FeedRegion.unavailableKey), findsOneWidget);
      expect(find.byType(KChip), findsNothing);

      await _pump(tester, const LiveScreen(), live: FakeLiveRepository());
      expect(find.byType(KChip), findsOneWidget);
      expect(find.text(l10n.liveHubChipAll), findsOneWidget);
      expect(
        find.descendant(of: find.byType(KChip), matching: find.byType(InkWell)),
        findsNothing,
      );
      final chip = tester.getSemantics(find.text(l10n.liveHubChipAll));
      expect(
        chip.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );

      await tester.tap(_tab(l10n.feedTabFollowing));
      await tester.pumpAndSettle();
      expect(find.byType(KChip), findsNothing);
    });

    for (final (width, cardWidth, cardHeight) in const [
      (393.0, 186.5, 248.67),
      (360.0, 170.0, 226.67),
    ]) {
      testWidgets('VG-09: cards are $cardWidth × $cardHeight at $width dp', (
        tester,
      ) async {
        tester.view
          ..physicalSize = Size(width, 852)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pump(
          tester,
          const LiveScreen(),
          live: FakeLiveRepository(rooms: (_) => apiPage(apiRooms(8))),
        );
        final size = tester.getSize(find.byType(KLiveCoverCard).first);
        expect(size.width, closeTo(cardWidth, 0.01));
        expect(size.height, closeTo(cardHeight, 0.01));
        // KL-047 (owner, reverses VG-10): every grid card has a LIVE badge.
        final cards = find.byType(KLiveCoverCard).evaluate().length;
        expect(cards, greaterThan(0));
        expect(
          find.byWidgetPredicate(
            (w) => w is KBadge && w.variant == KBadgeVariant.live,
          ),
          findsNWidgets(cards),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('loading: skeletons only after 300 ms', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveScreen(),
        overrides: liveOverrides(
          FakeLiveRepository(configGate: Completer<void>()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(KLiveCoverCardSkeleton), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(KLiveCoverCardSkeleton),
        findsNWidgets(KMetrics.liveGridSkeletonCount),
      );
    });

    testWidgets('empty Following offers "See popular", which switches tab', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(tester, const LiveScreen(), live: FakeLiveRepository());
      expect(find.text(l10n.liveHubEmptyTitle), findsOneWidget);
      expect(find.text(l10n.feedSeePopular), findsNothing);

      await tester.tap(_tab(l10n.feedTabFollowing));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveHubFollowingEmptyTitle), findsOneWidget);
      await tester.tap(find.text(l10n.feedSeePopular));
      await tester.pumpAndSettle();
      expect(_selected(tester, l10n.feedTabPopular), isTrue);
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
      await tester.fling(
        find.byType(KLiveCoverCard).first,
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

  group('Home feed', () {
    testWidgets('populated: flat items with author, time and text', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      await withClock(Clock.fixed(fixtureNow), () async {
        await _pump(
          tester,
          const HomeScreen(),
          overrides: [
            homeFeedProvider.overrideWith(
              (ref, tab) => FeedItems<FeedPostData>(feedPosts(AppLanguage.en)),
            ),
          ],
        );
        expect(find.byType(FeedPostTile), findsWidgets);
        expect(find.text('Sara'), findsOneWidget);
        expect(find.text('12m ago'), findsOneWidget);
        expect(find.text('3h ago'), findsOneWidget);
        // No outlined card container around items (VG-25).
        expect(find.byType(Card), findsNothing);
      });
    });

    testWidgets('empty Following offers "See popular"', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(
        tester,
        const HomeScreen(),
        overrides: [
          homeFeedProvider.overrideWith(
            (ref, tab) => const FeedItems<FeedPostData>([]),
          ),
        ],
      );
      await tester.tap(_tab(l10n.feedTabFollowing));
      await tester.pumpAndSettle();
      expect(find.text(l10n.homeFollowingEmptyTitle), findsOneWidget);
      await tester.tap(find.text(l10n.feedSeePopular));
      await tester.pumpAndSettle();
      expect(_selected(tester, l10n.feedTabPopular), isTrue);
      expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
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
            child: const HomeScreen(),
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
      expect(find.text(l10n.homeFollowingUnavailableTitle), findsOneWidget);
    });
  });
}
