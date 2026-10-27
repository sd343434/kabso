// D124: the live hub as a 2-column grid with the promo banner carousel
// after the 4th card, banner links, and the in-room swipe through the
// tab's rooms.

import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/live_room_swipe.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_notifications_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<void> _pumpHub(
  WidgetTester tester, {
  int rooms = 8,
  List<HomeBanner> banners = const [],
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  AppFailure? bannerFailure,
}) async {
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: const LiveScreen(),
      ),
    ),
    language: language,
    homeBannersRepository: FakeHomeBannersRepository(
      banners: banners,
      failure: bannerFailure,
    ),
    overrides: liveOverrides(
      FakeLiveRepository(
        rooms: (_) => apiPage(apiRooms(rooms, ar: language == AppLanguage.ar)),
      ),
      language: language,
    ),
  );
  await tester.pumpAndSettle();
}

/// Which banner the carousel shows (the one whose page fills it).
String? _visibleBanner(WidgetTester tester) {
  final carousel = tester.getRect(
    find.descendant(
      of: find.byKey(KHomeBannerCarousel.carouselKey),
      matching: find.byType(PageView),
    ),
  );
  for (final id in ['banner-0', 'banner-1', 'banner-2']) {
    final page = find.byKey(KHomeBannerCarousel.pageKey(id));
    for (final e in page.evaluate()) {
      final box = e.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if ((rect.left - carousel.left).abs() < 1) return id;
    }
  }
  return null;
}

void main() {
  group('grid (D124)', () {
    for (final language in AppLanguage.values) {
      testWidgets('2 columns from the reading start (${language.name})', (
        tester,
      ) async {
        await _pumpHub(tester, language: language);
        final first = tester.getRect(find.byKey(LiveHubGrid.cardKey(0)));
        final second = tester.getRect(find.byKey(LiveHubGrid.cardKey(1)));
        final third = tester.getRect(find.byKey(LiveHubGrid.cardKey(2)));
        expect(first.width, moreOrLessEquals((393 - 40) / 2));
        expect(first.height, moreOrLessEquals(first.width / 0.75));
        expect(first.top, second.top);
        expect(third.top - first.bottom, moreOrLessEquals(8));
        if (language == AppLanguage.ar) {
          expect(first.right, moreOrLessEquals(393 - 16));
          expect(first.left - second.right, moreOrLessEquals(8));
        } else {
          expect(first.left, moreOrLessEquals(16));
          expect(second.left - first.right, moreOrLessEquals(8));
        }
        // Title at the reading start of the top bar.
        final title = tester.getRect(find.byKey(LiveHubTopBar.titleKey));
        expect(
          language == AppLanguage.ar ? title.right > 300 : title.left < 100,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('room type next to the live mark', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      await _pumpHub(tester, rooms: 1);
      expect(
        find.descendant(
          of: find.byKey(LiveHubGrid.cardKey(0)),
          matching: find.text(l10n.liveGridVideo),
        ),
        findsOneWidget,
      );
    });
  });

  group('banners (D124)', () {
    testWidgets('full width after the 4th card, 3:1, with page dots', (
      tester,
    ) async {
      await _pumpHub(tester, banners: sampleBanners());
      final carousel = find.byKey(KHomeBannerCarousel.carouselKey);
      expect(carousel, findsOneWidget);
      final pager = tester.getRect(
        find.descendant(of: carousel, matching: find.byType(PageView)),
      );
      expect(pager.left, moreOrLessEquals(16));
      expect(pager.width, moreOrLessEquals(393 - 32));
      expect(pager.height, moreOrLessEquals((393 - 32) / 3));
      final fourth = tester.getRect(find.byKey(LiveHubGrid.cardKey(3)));
      expect(pager.top - fourth.bottom, moreOrLessEquals(8));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      final fifth = tester.getRect(find.byKey(LiveHubGrid.cardKey(4)));
      final dots = tester.getRect(find.byKey(KHomeBannerCarousel.dotsKey));
      expect(fifth.top, greaterThan(dots.bottom));
    });

    testWidgets('after the last card when there are fewer than 4', (
      tester,
    ) async {
      await _pumpHub(tester, rooms: 2, banners: sampleBanners(count: 1));
      final pager = tester.getRect(
        find.descendant(
          of: find.byKey(KHomeBannerCarousel.carouselKey),
          matching: find.byType(PageView),
        ),
      );
      expect(
        pager.top,
        greaterThan(tester.getRect(find.byKey(LiveHubGrid.cardKey(1))).bottom),
      );
      // One banner: no dots.
      expect(find.byKey(KHomeBannerCarousel.dotsKey), findsNothing);
    });

    testWidgets('hidden with no active banner, on a failed request and on '
        'the empty state', (tester) async {
      await _pumpHub(tester);
      expect(find.byKey(KHomeBannerCarousel.carouselKey), findsNothing);
      await _pumpHub(
        tester,
        banners: sampleBanners(),
        bannerFailure: const NetworkFailure.offline(),
      );
      expect(find.byKey(KHomeBannerCarousel.carouselKey), findsNothing);
      expect(find.byType(KLiveGridCard), findsWidgets);
      await _pumpHub(tester, rooms: 0, banners: sampleBanners());
      expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
      expect(find.byKey(KHomeBannerCarousel.carouselKey), findsNothing);
    });

    testWidgets('auto-advances every 4 s, wraps forwards, pauses while '
        'touched', (tester) async {
      await _pumpHub(tester, banners: sampleBanners());
      expect(_visibleBanner(tester), 'banner-0');
      await tester.pump(const Duration(milliseconds: 3900));
      expect(_visibleBanner(tester), 'banner-0');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(_visibleBanner(tester), 'banner-1');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_visibleBanner(tester), 'banner-2');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_visibleBanner(tester), 'banner-0');

      // A finger on it: no advance.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(KHomeBannerCarousel.carouselKey)),
      );
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(_visibleBanner(tester), 'banner-0');
      // Lifted without a tap (a tap would open the banner's link).
      await gesture.cancel();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(_visibleBanner(tester), 'banner-1');
    });

    testWidgets('no auto-advance with reduce motion', (tester) async {
      await _pumpHub(tester, banners: sampleBanners());
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(_visibleBanner(tester), 'banner-0');
    });

    test('links: the allowlist maps to app routes; others are ignored', () {
      expect(
        HomeBannerTarget.parse('/families'),
        const HomeBannerRoute('/families'),
      );
      expect(
        HomeBannerTarget.parse('/cp/space'),
        const HomeBannerRoute('/cp/space'),
      );
      expect(
        HomeBannerTarget.parse('/live?tab=trending'),
        const HomeBannerLiveTab(FeedTab.popular),
      );
      expect(
        HomeBannerTarget.parse('/live?tab=new'),
        const HomeBannerLiveTab(FeedTab.latest),
      );
      expect(
        HomeBannerTarget.parse(
          '/home/room/0193A4B2-7c1d-7e2f-8a3b-4c5d6e7f8091',
        ),
        const HomeBannerRoute(
          '/home/room/0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091',
        ),
      );
      expect(
        HomeBannerTarget.parse('/users/sara.k'),
        const HomeBannerRoute('/users/sara.k'),
      );
      for (final link in [
        'https://kabso.app/x',
        '/settings',
        '/live?tab=popular',
        '/home/room/x',
        'javascript:alert(1)',
      ]) {
        expect(HomeBannerTarget.parse(link), isNull, reason: link);
      }
    });

    for (final (viewport, scale) in const [
      (GoldenViewport.android, 1.0),
      (GoldenViewport.phone, 2.0),
      (GoldenViewport.android, 2.0),
    ]) {
      testWidgets('${viewport.name} at text scale $scale (ar): no overflow', (
        tester,
      ) async {
        await loadAppFonts();
        await _pumpHub(
          tester,
          banners: sampleBanners(),
          language: AppLanguage.ar,
          viewport: viewport,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(KHomeBannerCarousel.carouselKey), findsOneWidget);
      });
    }
  });

  group('navigation (D124)', () {
    late FakeHomeBannersRepository banners;

    Future<GoRouter> pumpRouted(
      WidgetTester tester, {
      String? meId,
      FakeLiveRepository? live,
    }) async {
      setViewport(tester, GoldenViewport.phone);
      final prefs = await testPrefs();
      Widget stub(String text) => Scaffold(body: Center(child: Text(text)));
      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const LiveScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.liveRoomSegment,
                builder: (_, state) {
                  final id = state.pathParameters['roomId']!;
                  return LiveRoomSwipe(roomId: id, child: stub('room:$id'));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.families,
            builder: (_, _) => stub('families'),
          ),
          GoRoute(path: AppRoutes.cpSpace, builder: (_, _) => stub('cp')),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, _) => stub('notifications'),
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (_, _) => stub('discover'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
            storiesRepositoryProvider.overrideWithValue(
              FakeStoriesRepository(),
            ),
            notificationsRepositoryProvider.overrideWithValue(
              FakeNotificationsRepository(),
            ),
            liveMediaEngineProvider.overrideWithValue(FakeLiveMediaEngine.new),
            homeBannersRepositoryProvider.overrideWithValue(banners),
            currentUserProvider.overrideWithValue(
              meId == null ? null : testUser().copyWith(id: meId),
            ),
            ...liveOverrides(
              live ?? FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6))),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.light,
              locale: AppLanguage.en.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    setUp(() => banners = FakeHomeBannersRepository(banners: sampleBanners()));

    testWidgets('a banner opens its link; "/live?tab=trending" selects '
        'Popular', (tester) async {
      final l10n = l10nFor(AppLanguage.en);
      final router = await pumpRouted(tester);
      await tester.tap(find.byKey(KHomeBannerCarousel.pageKey('banner-0')));
      await tester.pumpAndSettle();
      expect(find.text('families'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();

      // Following tab, then the talents banner (third) → Popular.
      await tester.tap(
        find.descendant(
          of: find.byType(KPrimaryTabs),
          matching: find.text(l10n.feedTabFollowing),
        ),
      );
      await tester.pumpAndSettle();
      final carousel = find.byKey(KHomeBannerCarousel.carouselKey);
      for (var i = 0; i < 2; i++) {
        await tester.drag(
          find.descendant(of: carousel, matching: find.byType(PageView)).last,
          const Offset(-400, 0),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byKey(KHomeBannerCarousel.pageKey('banner-2')).hitTestable(),
      );
      await tester.pumpAndSettle();
      bool selected(String label) =>
          tester
              .getSemantics(
                find.descendant(
                  of: find.byType(KPrimaryTabs),
                  matching: find.text(label),
                ),
              )
              .getSemanticsData()
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
      expect(selected(l10n.feedTabPopular), isTrue);
    });

    testWidgets('top bar: search opens Discover, the bell the notifications', (
      tester,
    ) async {
      final router = await pumpRouted(tester, meId: 'user-me');
      await tester.tap(find.byKey(LiveHubTopBar.searchKey));
      await tester.pumpAndSettle();
      expect(find.text('discover'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(NotificationsBell.bellKey));
      await tester.pumpAndSettle();
      expect(find.text('notifications'), findsOneWidget);
    });

    testWidgets('a card opens its room; inside, swipe up / down moves '
        "through the tab's rooms", (tester) async {
      await pumpRouted(tester);
      await tester.tap(find.byKey(LiveHubGrid.cardKey(1)));
      await tester.pumpAndSettle();
      expect(find.text('room:room-1'), findsOneWidget);
      await tester.fling(find.text('room:room-1'), const Offset(0, -400), 2000);
      await tester.pumpAndSettle();
      expect(find.text('room:room-2'), findsOneWidget);
      await tester.fling(find.text('room:room-2'), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      expect(find.text('room:room-1'), findsOneWidget);
      await tester.fling(find.text('room:room-1'), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      expect(find.text('room:room-0'), findsOneWidget);
      // The first room: nothing before it.
      await tester.fling(find.text('room:room-0'), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      expect(find.text('room:room-0'), findsOneWidget);
      // A slow drag is not a swipe.
      await tester.drag(find.text('room:room-0'), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(find.text('room:room-0'), findsOneWidget);
    });

    testWidgets("no swipe in the caller's own live", (tester) async {
      await pumpRouted(tester, meId: 'user-1');
      await tester.tap(find.byKey(LiveHubGrid.cardKey(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveRoomSwipe.swipeKey), findsNothing);
      await tester.fling(find.text('room:room-1'), const Offset(0, -400), 2000);
      await tester.pumpAndSettle();
      expect(find.text('room:room-1'), findsOneWidget);
    });
  });
}
