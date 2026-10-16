// KL-033: Home feed and Live hub behaviour (tabs, swipe, search, states,
// provider honesty).

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
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
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_fixtures.dart';
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

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  AppLanguage language = AppLanguage.en,
  List<Override> overrides = const [],
}) async {
  await pumpScreen(tester, screen, language: language, overrides: overrides);
  await tester.pumpAndSettle();
}

void main() {
  group('production providers are honest (D35)', () {
    test('every Home and Live tab is unavailable, never sample data', () {
      final container = ProviderContainer.test();
      for (final tab in FeedTab.values) {
        expect(
          container.read(homeFeedProvider(tab)).value,
          isA<FeedUnavailable<FeedPostData>>(),
          reason: 'home $tab',
        );
        expect(
          container.read(liveRoomsProvider(tab)).value,
          isA<FeedUnavailable<LiveRoomCardData>>(),
          reason: 'live $tab',
        );
      }
    });
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
        // VG-05: header is 48 dp with the tabs and the search button only.
        expect(
          tester.getSize(find.byType(KPrimaryTabs)).height,
          KMetrics.topBarHeight,
        );
        expect(find.byType(IconButton), findsOneWidget);
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
          final following = tester.getCenter(_tab(l10n.feedTabFollowing)).dx;
          final popular = tester.getCenter(_tab(l10n.feedTabPopular)).dx;
          final search = tester
              .getCenter(find.byKey(FeedTabsScaffold.searchKey))
              .dx;
          if (language == AppLanguage.ar) {
            expect(following, greaterThan(popular));
            expect(search, lessThan(popular));
          } else {
            expect(following, lessThan(popular));
            expect(search, greaterThan(popular));
          }
        });
      }

      testWidgets('search: 48 dp target with a label', (tester) async {
        await _pump(tester, screen);
        final search = find.byKey(FeedTabsScaffold.searchKey);
        expect(tester.getSize(search), const Size.square(48));
        expect(find.byTooltip('Search'), findsOneWidget);
      });

      testWidgets('VG-03: the unavailable state is compact, under the '
          'header, not centred, and has no pull-to-refresh', (tester) async {
        await loadAppFonts();
        setViewport(tester, GoldenViewport.phone);
        await _pump(tester, screen);
        final state = find.byKey(const Key('feed.unavailable'));
        // The visual block (icon → body) at real fonts, 393×852.
        final block = tester.getRect(
          find.descendant(of: state, matching: find.byType(Column)).first,
        );
        expect(block.height, lessThanOrEqualTo(160));
        final header = tester.getRect(find.byType(KPrimaryTabs));
        expect(block.top, greaterThan(header.bottom));
        // Top third of the region below the header, not centred.
        final region = 852 - header.bottom;
        expect(block.center.dy - header.bottom, lessThan(region / 3));
        expect(find.byType(RefreshIndicator), findsNothing);
      });
    });
  }

  group('search opens Discover (full app)', () {
    for (final (nav, key) in const [
      ('home', Key('nav.home')),
      ('live', Key('nav.live')),
    ]) {
      testWidgets('from $nav', (tester) async {
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
        await tester.tap(find.byKey(FeedTabsScaffold.searchKey));
        await tester.pumpAndSettle();
        expect(find.byType(DiscoverScreen), findsOneWidget);
      });
    }
  });

  group('Live hub', () {
    testWidgets('chip row: Popular only, a single non-interactive "All"', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pump(tester, const LiveScreen());
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
          overrides: [
            liveRoomsProvider.overrideWith(
              (ref, tab) =>
                  FeedItems<LiveRoomCardData>(hubRooms(AppLanguage.en)),
            ),
          ],
        );
        final size = tester.getSize(find.byType(KLiveCoverCard).first);
        expect(size.width, closeTo(cardWidth, 0.01));
        expect(size.height, closeTo(cardHeight, 0.01));
        // Grid cards carry no LIVE badge (VG-10).
        expect(
          find.byWidgetPredicate(
            (w) => w is KBadge && w.variant == KBadgeVariant.live,
          ),
          findsNothing,
        );
      });
    }

    testWidgets('loading: skeletons only after 300 ms', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveScreen(),
        overrides: [
          liveRoomsProvider.overrideWith(
            (ref, tab) => Completer<FeedLoad<LiveRoomCardData>>().future,
          ),
        ],
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
      await _pump(
        tester,
        const LiveScreen(),
        overrides: [
          liveRoomsProvider.overrideWith(
            (ref, tab) => const FeedItems<LiveRoomCardData>([]),
          ),
        ],
      );
      expect(find.text(l10n.liveHubEmptyTitle), findsOneWidget);
      expect(find.text(l10n.feedSeePopular), findsNothing);

      await tester.tap(_tab(l10n.feedTabFollowing));
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveHubFollowingEmptyTitle), findsOneWidget);
      await tester.tap(find.text(l10n.feedSeePopular));
      await tester.pumpAndSettle();
      expect(_selected(tester, l10n.feedTabPopular), isTrue);
    });

    testWidgets('error: compact error with Try again that re-runs the load', (
      tester,
    ) async {
      final l10n = l10nFor(AppLanguage.en);
      var calls = 0;
      await _pump(
        tester,
        const LiveScreen(),
        overrides: [
          liveRoomsProvider.overrideWith((ref, tab) {
            if (tab == FeedTab.popular) calls++;
            throw const NetworkFailure.offline();
          }),
        ],
      );
      expect(find.text(l10n.liveHubErrorTitle), findsOneWidget);
      expect(find.text(l10n.errorNetworkOffline), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final before = calls;
      await tester.tap(find.text(l10n.actionRetry));
      await tester.pumpAndSettle();
      expect(calls, before + 1);
    });

    testWidgets('populated: pull-to-refresh reloads the tab', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        const LiveScreen(),
        overrides: [
          liveRoomsProvider.overrideWith((ref, tab) {
            if (tab == FeedTab.popular) calls++;
            return FeedItems<LiveRoomCardData>(hubRooms(AppLanguage.en));
          }),
        ],
      );
      final before = calls;
      await tester.fling(
        find.byType(KLiveCoverCard).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(calls, before + 1);
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
