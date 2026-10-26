// KL-047: owner-directed polish of Home (social feed) and Live (discovery).
//
// - Home: per-tab composed state with a real primary action that opens the
//   Live tab (the real `/live` route) on the matching segment; loading,
//   error/offline with a retry that re-runs the load.
// - Live: owner empty copy, hosting-unavailable, loading, error and offline
//   (QA-003); every retry re-requests (repository call counts); the empty
//   state never shows while loading or after an error.
// - Cards: LIVE badge, viewer-count rule, category name, RTL, long labels.
// - Search hidden, navigation regression, text scale 1.3 / 2.0 in Arabic,
//   and no development phases in any string these screens render.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/component_harness.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

Finder _tab(String label) =>
    find.descendant(of: find.byType(KPrimaryTabs), matching: find.text(label));

bool _selected(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData().flagsCollection.isSelected ==
    Tristate.isTrue;

String _tabLabel(AppLocalizations l10n, FeedTab tab) => switch (tab) {
  FeedTab.following => l10n.feedTabFollowing,
  FeedTab.popular => l10n.feedTabPopular,
  FeedTab.latest => l10n.feedTabNew,
};

/// D52: shows [tab] on the Reels shell tab with the header switch.
Future<void> _showHomeMode(WidgetTester tester, HomeTab tab) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(FeedScreen)));
  final word = find.descendant(
    of: find.byKey(FeedScreen.switchKey),
    matching: find.text(l10n.homeTabReels),
  );
  final showing = word.evaluate().isNotEmpty ? HomeTab.posts : HomeTab.reels;
  if (showing != tab) {
    await tester.ensureVisible(find.byKey(FeedScreen.switchKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FeedScreen.switchKey));
    await tester.pumpAndSettle();
  }
}

/// D124: the Popular tab's skeleton grid (loading).
final Finder _liveSkeleton = find.descendant(
  of: find.byKey(const PageStorageKey<String>('live.popular')),
  matching: find.byKey(LiveHubGrid.skeletonKey),
);

/// D124: how many cards the Popular tab's grid shows.
int _streams(WidgetTester tester) => find
    .descendant(
      of: find.byKey(const PageStorageKey<String>('live.popular')),
      matching: find.byType(KLiveGridCard),
    )
    .evaluate()
    .length;

/// A button inside the region's state with [label].
Finder _action(String label) =>
    find.descendant(of: find.byType(KButton), matching: find.text(label));

Future<void> _pumpLive(
  WidgetTester tester,
  FakeLiveRepository live, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const LiveScreen(),
    language: language,
    overrides: liveOverrides(live, language: language),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHome(
  WidgetTester tester, {
  List<Override> overrides = const [],
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const FeedScreen(),
    language: language,
    overrides: overrides,
  );
}

Future<void> _pumpApp(WidgetTester tester, {String language = 'en'}) async {
  await pumpKabsoApp(
    tester,
    language: language,
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  await tester.pumpAndSettle();
}

String _location(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KabsoApp)))
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

void main() {
  group('Home (KL-047, D47 tabs)', () {
    // KL-060: posts come from the posts API, so with no posts the Posts
    // mode shows its empty state (with pull-to-refresh: there is a data
    // source); Reels has no API yet and stays unavailable.
    testWidgets('posts: no posts yet → empty state with one primary action '
        'and pull-to-refresh', (tester) async {
      await _pumpHome(tester);
      await tester.pumpAndSettle();
      await _showHomeMode(tester, HomeTab.posts);
      final state = find.byKey(FeedRegion.emptyKey);
      expect(
        find.descendant(of: state, matching: find.text(_en.homeEmptyTitle)),
        findsOneWidget,
      );
      expect(find.byKey(FeedRegion.unavailableKey), findsNothing);
      final buttons = find.descendant(
        of: state,
        matching: find.byType(KButton),
      );
      expect(buttons, findsOneWidget);
      final button = tester.widget<KButton>(buttons);
      expect(button.label, _en.homeWatchLive);
      expect(button.onPressed, isNotNull);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    for (final (tab, title, body) in [
      (
        HomeTab.reels,
        _en.homeReelsUnavailableTitle,
        _en.homeReelsUnavailableBody,
      ),
    ]) {
      testWidgets('${tab.name}: title, supporting line and one primary '
          'action', (tester) async {
        await _pumpHome(tester);
        await tester.pumpAndSettle();
        await _showHomeMode(tester, tab);
        final state = find.byKey(FeedRegion.unavailableKey);
        expect(
          find.descendant(of: state, matching: find.text(title)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: state, matching: find.text(body)),
          findsOneWidget,
        );
        final buttons = find.descendant(
          of: state,
          matching: find.byType(KButton),
        );
        expect(buttons, findsOneWidget);
        final button = tester.widget<KButton>(buttons);
        expect(button.label, _en.homeWatchLive);
        expect(button.variant, KButtonVariant.primary);
        expect(button.onPressed, isNotNull);
        // Honest: no pull-to-refresh where there is no data source, and no
        // fake skeletons.
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(find.byType(FeedPostSkeleton), findsNothing);
      });

      testWidgets('${tab.name}: "Watch live streams" opens Home, the live '
          'hub (real /home route), on Popular', (tester) async {
        await _pumpApp(tester);
        expect(_location(tester), AppRoutes.home);
        await tester.tap(find.byKey(const Key('nav.reels')));
        await tester.pumpAndSettle();
        expect(_location(tester), AppRoutes.reels);
        await _showHomeMode(tester, tab);
        await tester.tap(_action(_en.homeWatchLive));
        await tester.pumpAndSettle();
        expect(_location(tester), AppRoutes.home);
        expect(find.byType(LiveScreen), findsOneWidget);
        expect(_selected(tester, find.byKey(const Key('nav.home'))), isTrue);
        expect(_selected(tester, find.byKey(const Key('nav.reels'))), isFalse);
        final popular = find.descendant(
          of: find.byType(LiveScreen),
          matching: _tab(_en.feedTabPopular),
        );
        expect(_selected(tester, popular), isTrue);
      });
    }

    testWidgets('a request reaches a live hub that is already built', (
      tester,
    ) async {
      await _pumpApp(tester);
      // The hub (Home) is built on launch: move it to Following, open Reels,
      // then "Watch live streams" brings Home back on Popular.
      await tester.tap(_tab(_en.feedTabFollowing));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
      await tester.tap(_action(_en.homeWatchLive));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.home);
      final popular = find.descendant(
        of: find.byType(LiveScreen),
        matching: _tab(_en.feedTabPopular),
      );
      expect(_selected(tester, popular), isTrue);
    });

    testWidgets('loading: skeleton posts after 300 ms; no empty or '
        'unavailable state', (tester) async {
      await _pumpHome(
        tester,
        overrides: [
          homePostsProvider.overrideWith(
            (ref, _) => Completer<FeedLoad<FeedPostData>>().future,
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FeedPostSkeleton), findsWidgets);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      expect(find.byKey(FeedRegion.unavailableKey), findsNothing);
    });

    for (final (name, failure, key) in <(String, AppFailure, Key)>[
      (
        'error',
        const ServerFailure(
          code: ErrorCode.internalError,
          rawCode: 'INTERNAL_ERROR',
          debugMessage: 'x',
          statusCode: 500,
          requestId: 'req-7',
        ),
        FeedRegion.errorKey,
      ),
      ('offline', const NetworkFailure.offline(), FeedRegion.offlineKey),
    ]) {
      testWidgets('$name: Try again re-runs the load, then shows posts', (
        tester,
      ) async {
        var calls = 0;
        var fail = true;
        await _pumpHome(
          tester,
          overrides: [
            homePostsProvider.overrideWith((ref, _) {
              calls++;
              if (fail) throw failure;
              return FeedItems<FeedPostData>(feedPosts(AppLanguage.en));
            }),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(key), findsOneWidget);
        expect(find.byKey(FeedRegion.emptyKey), findsNothing);
        if (key == FeedRegion.errorKey) {
          expect(find.text(_en.homeErrorTitle), findsOneWidget);
          expect(find.text(_en.errorIdLabel('req-7')), findsOneWidget);
        } else {
          expect(find.text(_en.feedOfflineTitle), findsOneWidget);
        }
        final before = calls;
        fail = false;
        await tester.tap(_action(_en.actionRetry));
        await tester.pumpAndSettle();
        expect(calls, before + 1);
        expect(find.byType(FeedPostTile), findsWidgets);
        expect(find.byKey(key), findsNothing);
      });
    }

    testWidgets('empty: every tab offers "Watch live streams"', (tester) async {
      await _pumpHome(
        tester,
        overrides: [
          homePostsProvider.overrideWith(
            (ref, _) => const FeedItems<FeedPostData>([]),
          ),
          homeReelsProvider.overrideWith(
            (ref, _) => const FeedItems<FeedReelData>([]),
          ),
        ],
      );
      await tester.pumpAndSettle();
      for (final (tab, title) in [
        (HomeTab.posts, _en.homeEmptyTitle),
        (HomeTab.reels, _en.homeReelsEmptyTitle),
      ]) {
        await _showHomeMode(tester, tab);
        expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(_action(_en.homeWatchLive), findsOneWidget);
      }
    });

    testWidgets('no live rooms on the Reels tab (D39)', (tester) async {
      await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGridCard), findsNothing);
      expect(find.byType(KLiveCoverCard), findsNothing);
    });
  });

  group('Live empty state (KL-047, owner copy)', () {
    test('owner copy, exactly', () {
      final ar = l10nFor(AppLanguage.ar);
      expect(ar.liveHubEmptyTitle, 'لا توجد بثوث مباشرة الآن');
      expect(
        ar.liveHubEmptyBody,
        'تفقّد البثوث الجديدة أو حاول مرة أخرى لاحقًا.',
      );
      expect(ar.actionRetry, 'إعادة المحاولة');
      expect(_en.liveHubEmptyTitle, 'No live streams right now');
      expect(_en.liveHubEmptyBody, 'Explore new streams or check back later.');
      expect(_en.actionRetry, 'Try again');
    });

    for (final language in AppLanguage.values) {
      testWidgets('Popular: title, body, Try again + See new streams '
          '(${language.name})', (tester) async {
        final l10n = l10nFor(language);
        await _pumpLive(tester, FakeLiveRepository(), language: language);
        final state = find.byKey(FeedRegion.emptyKey);
        for (final text in [
          l10n.liveHubEmptyTitle,
          l10n.liveHubEmptyBody,
          l10n.actionRetry,
          l10n.liveHubSeeNew,
        ]) {
          expect(
            find.descendant(of: state, matching: find.text(text)),
            findsOneWidget,
            reason: text,
          );
        }
      });
    }

    testWidgets('Try again re-requests config and the first page, showing '
        'loading (not the empty state) meanwhile', (tester) async {
      final live = FakeLiveRepository();
      await _pumpLive(tester, live);
      final configs = live.configCalls;
      final lists = live.requests.length;
      live.configGate = Completer<void>();
      await tester.tap(_action(_en.actionRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(live.configCalls, configs + 1);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      expect(_liveSkeleton, findsOneWidget);
      live.configGate!.complete();
      live.configGate = null;
      await tester.pumpAndSettle();
      expect(live.requests, hasLength(lists + 1));
      expect(live.requests.last.tab, LiveRoomsTab.popular);
      expect(live.requests.last.cursor, isNull);
      expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
    });

    testWidgets('Try again shows rooms that started meanwhile', (tester) async {
      final live = FakeLiveRepository();
      await _pumpLive(tester, live);
      live.rooms = (_) => apiPage(apiRooms(2));
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(_streams(tester), 2);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
    });

    testWidgets('"See new streams" switches to New; New has no such action', (
      tester,
    ) async {
      final live = FakeLiveRepository();
      await _pumpLive(tester, live);
      await tester.tap(_action(_en.liveHubSeeNew));
      await tester.pumpAndSettle();
      expect(_selected(tester, _tab(_en.feedTabNew)), isTrue);
      expect(live.requests.last.tab, LiveRoomsTab.latest);
      expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
      expect(_action(_en.liveHubSeeNew), findsNothing);
      expect(_action(_en.actionRetry), findsOneWidget);
    });

    testWidgets('Following keeps "See popular"; its Try again re-requests '
        'Following', (tester) async {
      final live = FakeLiveRepository();
      await _pumpLive(tester, live);
      await tester.tap(_tab(_en.feedTabFollowing));
      await tester.pumpAndSettle();
      expect(find.text(_en.liveHubFollowingEmptyTitle), findsOneWidget);
      expect(find.text(_en.liveHubFollowingEmptyBody), findsOneWidget);
      int following() =>
          live.requests.where((r) => r.tab == LiveRoomsTab.following).length;
      final before = following();
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(following(), before + 1);
      await tester.tap(_action(_en.feedSeePopular));
      await tester.pumpAndSettle();
      expect(_selected(tester, _tab(_en.feedTabPopular)), isTrue);
    });
  });

  group('Live hosting-unavailable (KL-047)', () {
    testWidgets('composed explanation; Try again re-checks GET /live/config '
        'and lists nothing while hosting is off', (tester) async {
      final live = FakeLiveRepository(hostingEnabled: false);
      await _pumpLive(tester, live);
      final state = find.byKey(FeedRegion.unavailableKey);
      expect(
        find.descendant(
          of: state,
          matching: find.text(_en.liveHubPopularUnavailableTitle),
        ),
        findsOneWidget,
      );
      final calls = live.configCalls;
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(live.configCalls, calls + 1);
      expect(live.requests, isEmpty);
      expect(state, findsOneWidget);

      // The server switched hosting on: the next Try again lists rooms.
      live
        ..hostingEnabled = true
        ..rooms = (_) => apiPage(apiRooms(3));
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(live.configCalls, calls + 2);
      expect(_streams(tester), 3);
    });

    testWidgets('while re-checking it shows loading, not the old state', (
      tester,
    ) async {
      final live = FakeLiveRepository(hostingEnabled: false);
      await _pumpLive(tester, live);
      live.configGate = Completer<void>();
      await tester.tap(_action(_en.actionRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(FeedRegion.unavailableKey), findsNothing);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      expect(_liveSkeleton, findsOneWidget);
      live.configGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(FeedRegion.unavailableKey), findsOneWidget);
    });

    testWidgets('every tab has its own copy, none with phases', (tester) async {
      await _pumpLive(tester, FakeLiveRepository(hostingEnabled: false));
      for (final (tab, title) in [
        (FeedTab.following, _en.liveHubFollowingUnavailableTitle),
        (FeedTab.latest, _en.liveHubNewUnavailableTitle),
        (FeedTab.popular, _en.liveHubPopularUnavailableTitle),
      ]) {
        await tester.tap(_tab(_tabLabel(_en, tab)));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(_action(_en.actionRetry), findsOneWidget);
      }
    });
  });

  group('Live error and offline (KL-047, QA-003)', () {
    const internal = ServerFailure(
      code: ErrorCode.internalError,
      rawCode: 'INTERNAL_ERROR',
      debugMessage: 'x',
      statusCode: 500,
      requestId: 'req-9',
    );

    testWidgets('error on the first load: error state, never the empty '
        'state; Try again re-runs config and the first page', (tester) async {
      final live = FakeLiveRepository()..configFailure = internal;
      await _pumpLive(tester, live);
      expect(find.byKey(FeedRegion.errorKey), findsOneWidget);
      expect(find.text(_en.liveHubErrorTitle), findsOneWidget);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      expect(find.byKey(FeedRegion.offlineKey), findsNothing);
      expect(live.requests, isEmpty);

      final configs = live.configCalls;
      live
        ..configFailure = null
        ..configGate = Completer<void>();
      await tester.tap(_action(_en.actionRetry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Loading, not empty and not the old error.
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      expect(find.byKey(FeedRegion.errorKey), findsNothing);
      expect(_liveSkeleton, findsOneWidget);
      live.configGate!.complete();
      live.configGate = null;
      await tester.pumpAndSettle();
      expect(live.configCalls, configs + 1);
      expect(live.requests, hasLength(1));
      expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
    });

    testWidgets('a failed first page is an error, not "no streams"', (
      tester,
    ) async {
      var fail = true;
      final live = FakeLiveRepository(
        rooms: (_) => fail ? throw internal : apiPage(apiRooms(2)),
      );
      await _pumpLive(tester, live);
      expect(find.byKey(FeedRegion.errorKey), findsOneWidget);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      final lists = live.requests.length;
      fail = false;
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(live.requests, hasLength(lists + 1));
      expect(_streams(tester), 2);
    });

    testWidgets('a failed category reload retries only that first page', (
      tester,
    ) async {
      var fail = true;
      final live = FakeLiveRepository(
        categories: apiCategories(),
        rooms: (r) => r.category == 'music' && fail
            ? throw const NetworkFailure.offline()
            : apiPage(apiRooms(2)),
      );
      await _pumpLive(tester, live);
      await tester.tap(find.byKey(const ValueKey('live.chip.music')));
      await tester.pumpAndSettle();
      // Offline gets its own state (QA-003).
      expect(find.byKey(FeedRegion.offlineKey), findsOneWidget);
      expect(find.text(_en.feedOfflineTitle), findsOneWidget);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
      final configs = live.configCalls;
      final lists = live.requests.length;
      fail = false;
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(live.configCalls, configs);
      expect(live.requests, hasLength(lists + 1));
      expect(live.requests.last.category, 'music');
      expect(_streams(tester), 2);
    });

    testWidgets('offline vs other failures: own copy only for '
        'NETWORK_OFFLINE', (tester) async {
      final live = FakeLiveRepository()
        ..configFailure = const NetworkFailure.timeout();
      await _pumpLive(tester, live);
      expect(find.byKey(FeedRegion.errorKey), findsOneWidget);
      expect(find.text(_en.errorNetworkTimeout), findsOneWidget);
      expect(find.byKey(FeedRegion.offlineKey), findsNothing);

      live.configFailure = const NetworkFailure.offline();
      await tester.tap(_action(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(find.byKey(FeedRegion.offlineKey), findsOneWidget);
      expect(find.byKey(FeedRegion.errorKey), findsNothing);
    });
  });

  group('cards (KL-047)', () {
    Finder badge(KBadgeVariant variant) =>
        find.byWidgetPredicate((w) => w is KBadge && w.variant == variant);

    Finder inCard(int i, Finder f) =>
        find.descendant(of: find.byKey(LiveHubGrid.cardKey(i)), matching: f);

    testWidgets('the live mark on every card; viewer count only when > 0, '
        'otherwise "New" (never invented)', (tester) async {
      final rooms = apiRooms(2);
      final live = FakeLiveRepository(
        rooms: (_) => apiPage([rooms[0], rooms[1].copyWith(viewerCount: 7)]),
      );
      await _pumpLive(tester, live);
      expect(_streams(tester), 2);
      for (final i in [0, 1]) {
        expect(inCard(i, find.byType(KLiveEqualizer)), findsOneWidget);
      }
      expect(inCard(0, find.text(_en.liveCardNew)), findsOneWidget);
      expect(
        inCard(0, find.byIcon(Icons.person_outline_rounded)),
        findsNothing,
      );
      expect(inCard(1, find.text(_en.liveCardNew)), findsNothing);
      expect(inCard(1, find.text('7')), findsOneWidget);
    });

    testWidgets('category name when present, nothing when absent; '
        'announced', (tester) async {
      final live = FakeLiveRepository(
        rooms: (_) => apiPage(apiRooms(2, categories: apiCategories())),
      );
      await _pumpLive(tester, live);
      expect(inCard(0, find.text('Music')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Sara, live, New, Arabic music night, Video, Music',
        ),
        findsOneWidget,
      );
      expect(inCard(1, find.byKey(KLiveGridCard.categoryKey)), findsNothing);
      expect(
        find.bySemanticsLabel('Omar, live, New, Evening chat, Video'),
        findsOneWidget,
      );
    });

    testWidgets('hierarchy: host above title above category, one line each', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        Center(
          child: SizedBox(
            width: 170,
            child: KLiveCoverCard(room: liveRooms(AppLanguage.en).first),
          ),
        ),
      );
      final host = tester.getRect(find.text('Sara'));
      final title = tester.getRect(find.text('Arabic music night'));
      final category = tester.getRect(find.text('Music'));
      expect(host.bottom, lessThanOrEqualTo(title.top));
      expect(title.bottom, lessThanOrEqualTo(category.top));
      for (final text in ['Sara', 'Arabic music night', 'Music']) {
        expect(tester.widget<Text>(find.text(text)).maxLines, 1);
      }
      TextStyle style(String t) => tester.widget<Text>(find.text(t)).style!;
      expect(style('Sara').fontSize, greaterThan(style('Music').fontSize!));
    });

    testWidgets('RTL: LIVE badge at the top-right, then the chip; category '
        'at the reading start', (tester) async {
      await pumpComponent(
        tester,
        Center(
          child: SizedBox(
            width: 170,
            child: KLiveCoverCard(room: hubRooms(AppLanguage.ar)[5]),
          ),
        ),
        language: AppLanguage.ar,
      );
      final card = tester.getRect(find.byType(KLiveCoverCard));
      final liveBadge = tester.getRect(badge(KBadgeVariant.live));
      final viewers = tester.getRect(find.byType(KViewerCountChip));
      expect(liveBadge.center.dx, greaterThan(viewers.center.dx));
      expect(card.right - liveBadge.right, closeTo(KSpacing.sm, 0.5));
      // The text column starts after the host avatar (at the right): the
      // category line is right-aligned with the host name.
      final host = tester.getRect(find.text('يوسف'));
      final avatar = tester.getRect(
        find.descendant(
          of: find.byType(KLiveCoverCard),
          matching: find.byType(KAvatar),
        ),
      );
      expect(avatar.center.dx, greaterThan(host.center.dx));
      final categoryIcon = tester.getRect(find.byIcon(Icons.tag_rounded));
      final category = tester.getRect(find.text('ألعاب'));
      expect(categoryIcon.right, closeTo(host.right, 0.5));
      expect(categoryIcon.center.dx, greaterThan(category.center.dx));
    });

    for (final language in AppLanguage.values) {
      testWidgets('long labels at 360 dp: no overflow, PK tag kept '
          '(${language.name})', (tester) async {
        await loadAppFonts();
        final ar = language == AppLanguage.ar;
        await pumpComponent(
          tester,
          Center(
            child: SizedBox(
              width: 170,
              child: KLiveCoverCard(
                room: LiveRoomCardData(
                  hostName: ar
                      ? 'نور الهدى عبد الرحمن الهاشمي'
                      : 'Nour Al-Huda Abdulrahman Al-Hashimi',
                  title: ar
                      ? 'دردشة مفتوحة عن السفر والطبخ والكتب وكل شيء'
                      : 'Open chat about travel, cooking, books and more',
                  viewerCount: 1234567,
                  inPk: true,
                  categoryName: ar
                      ? 'موسيقى وأغانٍ عربية كلاسيكية وحديثة'
                      : 'Classic and modern Arabic music and songs',
                ),
              ),
            ),
          ),
          language: language,
        );
        expect(tester.takeException(), isNull);
        final card = tester.getRect(find.byType(KLiveCoverCard));
        final pk = tester.getRect(badge(KBadgeVariant.pk));
        final liveBadge = tester.getRect(badge(KBadgeVariant.live));
        expect(card.contains(pk.center), isTrue);
        expect(pk.overlaps(liveBadge), isFalse);
      });
    }
  });

  group('text scale 1.3 / 2.0, Arabic, 360 dp (KL-047)', () {
    Future<void> pumpScaled(
      WidgetTester tester,
      Widget screen,
      double scale, {
      List<Override> overrides = const [],
    }) async {
      await loadAppFonts();
      setViewport(tester, GoldenViewport.android);
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: screen,
              bottomNavigationBar: KBottomNav(
                items: shellNavItems(context.l10n),
                currentIndex: 3,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
        language: AppLanguage.ar,
        overrides: overrides,
      );
      await tester.pumpAndSettle();
    }

    final ar = l10nFor(AppLanguage.ar);
    for (final scale in [1.3, 2.0]) {
      testWidgets('Home unavailable ($scale): no overflow, action reachable', (
        tester,
      ) async {
        await pumpScaled(tester, const FeedScreen(), scale);
        expect(tester.takeException(), isNull);
        final action = _action(ar.homeWatchLive);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(action).bottom, lessThan(800 - 64));
      });

      for (final (name, live, key) in [
        (
          'unavailable',
          FakeLiveRepository(hostingEnabled: false),
          FeedRegion.unavailableKey,
        ),
        ('empty', FakeLiveRepository(), FeedRegion.emptyKey),
        (
          'offline',
          FakeLiveRepository()..configFailure = const NetworkFailure.offline(),
          FeedRegion.offlineKey,
        ),
        (
          'error',
          FakeLiveRepository()
            ..configFailure = const ServerFailure(
              code: ErrorCode.internalError,
              rawCode: 'INTERNAL_ERROR',
              debugMessage: 'x',
              statusCode: 500,
              requestId: '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
            ),
          FeedRegion.errorKey,
        ),
      ]) {
        testWidgets('Live $name ($scale): no overflow; Try again reachable and '
            're-requests', (tester) async {
          await pumpScaled(
            tester,
            const LiveScreen(),
            scale,
            overrides: liveOverrides(live, language: AppLanguage.ar),
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(key), findsOneWidget);
          final retry = _action(ar.actionRetry);
          await tester.ensureVisible(retry);
          await tester.pumpAndSettle();
          final calls = live.configCalls;
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(live.configCalls, calls + 1);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('Live populated with categories ($scale): no overflow', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          const LiveScreen(),
          scale,
          overrides: liveOverrides(
            FakeLiveRepository(
              categories: apiCategories(ar: true),
              rooms: (_) => apiPage(
                apiRooms(6, ar: true, categories: apiCategories(ar: true)),
              ),
            ),
            language: AppLanguage.ar,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(KLiveGridCard), findsWidgets);
      });
    }
  });

  group('KEmptyState embedded + actions (KL-047)', () {
    testWidgets('88 dp disc, no own scroll view; primary + ghost actions', (
      tester,
    ) async {
      var primary = 0;
      var secondary = 0;
      await pumpComponent(
        tester,
        KEmptyState(
          embedded: true,
          icon: Icons.sensors_outlined,
          title: 'T',
          message: 'M',
          actionLabel: 'A',
          onAction: () => primary++,
          actionVariant: KButtonVariant.primary,
          actionIcon: Icons.sensors_rounded,
          secondaryActionLabel: 'B',
          onSecondaryAction: () => secondary++,
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      final disc = find.ancestor(
        of: find.byIcon(Icons.sensors_outlined),
        matching: find.byType(Container),
      );
      expect(tester.getSize(disc.first), const Size.square(KSizes.avatarLg));
      final buttons = tester.widgetList<KButton>(find.byType(KButton));
      expect(buttons.map((b) => b.variant), [
        KButtonVariant.primary,
        KButtonVariant.ghost,
      ]);
      expect(
        tester.getCenter(find.text('A')).dy,
        lessThan(tester.getCenter(find.text('B')).dy),
      );
      await tester.tap(find.text('A'));
      await tester.tap(find.text('B'));
      expect((primary, secondary), (1, 1));
    });

    testWidgets('an action without a callback is not drawn', (tester) async {
      await pumpComponent(
        tester,
        const KEmptyState(
          embedded: true,
          icon: Icons.sensors_outlined,
          title: 'T',
          message: 'M',
          actionLabel: 'A',
          secondaryActionLabel: 'B',
        ),
      );
      expect(find.byType(KButton), findsNothing);
    });
  });

  group('navigation regression (KL-047)', () {
    test('routes and branch order (D48, D86)', () {
      expect(AppRoutes.shellBranches, [
        '/home',
        '/reels',
        '/create',
        '/messages',
        '/profile',
      ]);
    });

    const keys = [
      Key('nav.home'),
      Key('nav.reels'),
      Key('nav.create'),
      Key('nav.messages'),
      Key('nav.profile'),
    ];

    for (final language in ['en', 'ar']) {
      testWidgets('$language: order mirrors, 48 dp targets, icon sizes, '
          'Create pill', (tester) async {
        setViewport(tester, GoldenViewport.phone);
        await _pumpApp(tester, language: language);
        final xs = [for (final k in keys) tester.getCenter(find.byKey(k)).dx];
        final sorted = [...xs]..sort();
        // ar: Home is at the right (the project's RTL convention).
        expect(xs, language == 'ar' ? sorted.reversed.toList() : sorted);
        for (final k in keys) {
          final size = tester.getSize(find.byKey(k));
          expect(size.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
          expect(size.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
        }
        final nav = find.byType(KBottomNav);
        final icons = find.descendant(
          of: nav,
          matching: find.byType(SvgPicture),
        );
        // D49: four 28 dp icons and the 54×36 Create pill.
        expect(icons, findsNWidgets(5));
        for (final k in keys) {
          final icon = find.descendant(
            of: find.byKey(k),
            matching: find.byType(SvgPicture),
          );
          expect(
            tester.getSize(icon),
            k == const Key('nav.create')
                ? KNavIcons.createSize
                : const Size.square(KNavIcons.iconSize),
            reason: '$k',
          );
        }
        expect(_selected(tester, find.byKey(keys.first)), isTrue);
      });
    }

    testWidgets('content stays clear of the nav and the safe areas', (
      tester,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      tester.view.padding = const FakeViewPadding(
        top: 59 * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await _pumpApp(tester);
      for (final key in [const Key('nav.home'), const Key('nav.reels')]) {
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        final nav = tester.getRect(find.byType(KBottomNav));
        expect(nav.bottom, 852);
        final visible = find.byWidgetPredicate((w) => w is CustomScrollView);
        final region = tester.getRect(visible.first);
        expect(region.bottom, lessThanOrEqualTo(nav.top));
        final header = tester.getRect(
          key == const Key('nav.reels')
              ? find.byKey(FeedScreen.tabsKey)
              : find.byType(KPrimaryTabs).first,
        );
        expect(header.top, greaterThanOrEqualTo(59));
        // KL-060: Posts has an API (empty here); the live hub is off.
        final state = tester.getRect(
          find
              .byKey(
                key == const Key('nav.reels')
                    ? FeedRegion.emptyKey
                    : FeedRegion.unavailableKey,
              )
              .first,
        );
        expect(state.bottom, lessThanOrEqualTo(nav.top));
        // Home indicator inset under the nav items.
        expect(
          tester.getRect(find.byKey(const Key('nav.home'))).bottom,
          lessThanOrEqualTo(852 - 34),
        );
      }
    });
  });

  group('no development phases in Home and Live (KL-047)', () {
    final phase = RegExp(
      r'phase|المرحلة|مرحلة|sprint|coming in v\d',
      caseSensitive: false,
    );

    Iterable<String> texts(WidgetTester tester) => [
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        w.data ?? w.textSpan?.toPlainText() ?? '',
      for (final w in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        w.message ?? '',
    ];

    for (final language in AppLanguage.values) {
      testWidgets('every rendered Home/Live state (${language.name})', (
        tester,
      ) async {
        final l10n = l10nFor(language);
        final seen = <String>{};
        Future<void> visitTabs() async {
          for (final tab in FeedTab.values) {
            await tester.tap(_tab(_tabLabel(l10n, tab)).first);
            await tester.pumpAndSettle();
            seen.addAll(texts(tester));
          }
        }

        await _pumpHome(tester, language: language);
        await tester.pumpAndSettle();
        for (final tab in HomeTab.values) {
          await _showHomeMode(tester, tab);
          seen.addAll(texts(tester));
        }
        for (final live in [
          FakeLiveRepository(hostingEnabled: false),
          FakeLiveRepository(),
          FakeLiveRepository()..configFailure = const NetworkFailure.offline(),
          FakeLiveRepository()
            ..configFailure = const ServerFailure(
              code: ErrorCode.internalError,
              rawCode: 'INTERNAL_ERROR',
              debugMessage: 'x',
            ),
          FakeLiveRepository(
            categories: apiCategories(ar: language == AppLanguage.ar),
            rooms: (_) => apiPage(apiRooms(4)),
          ),
        ]) {
          // A fresh scope (the override list changes size).
          await tester.pumpWidget(const SizedBox());
          await _pumpLive(tester, live, language: language);
          await visitTabs();
        }
        expect(seen, isNotEmpty);
        for (final text in seen) {
          expect(text, isNot(contains(phase)), reason: text);
          expect(text, isNot(contains(RegExp(r'\bv\d+\.\d'))), reason: text);
        }
      });
    }
  });
}
