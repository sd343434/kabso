// D359 (owner decision: events reach the «البث» hub ONLY through the
// existing home banner carousel — no extra strip, icon or button): an event
// banner opens that event's page (AppRoutes.event) from its `eventId`, the
// carousel keeps the server's order (running events' banners first, D359
// §10.154), and nothing else on the hub links an event. Arabic and English.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_notifications_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _running = '0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091';
const _upcoming = '0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8092';

HomeBanner _event(String id, String eventId, {String? link}) => HomeBanner(
  id: id,
  imageUrl: 'https://media.example.test/media/$id/1500.webp',
  height: 300,
  link: link ?? '/events/$eventId',
  eventId: eventId,
);

const _plain = HomeBanner(
  id: 'plain',
  imageUrl: 'https://media.example.test/media/plain/1500.webp',
  height: 300,
  link: '/families',
);

Future<void> _pumpRouted(
  WidgetTester tester,
  List<HomeBanner> banners, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final prefs = await testPrefs(language: language.name);
  Widget stub(String text) => Scaffold(body: Center(child: Text(text)));
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(path: AppRoutes.home, builder: (_, _) => const LiveScreen()),
      GoRoute(
        path: AppRoutes.eventPattern,
        builder: (_, state) => stub('event:${state.pathParameters['eventId']}'),
      ),
      GoRoute(path: AppRoutes.families, builder: (_, _) => stub('families')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        notificationsRepositoryProvider.overrideWithValue(
          FakeNotificationsRepository(),
        ),
        ...pkTestOverrides(),
        liveMediaEngineProvider.overrideWithValue(FakeLiveMediaEngine.new),
        homeBannersRepositoryProvider.overrideWithValue(
          FakeHomeBannersRepository(banners: banners),
        ),
        currentUserProvider.overrideWithValue(null),
        ...liveOverrides(
          FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6))),
          language: language,
        ),
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
          brightness: Brightness.light,
          locale: language.locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('${language.name}: tapping an event banner opens '
        'AppRoutes.event(id)', (tester) async {
      await _pumpRouted(tester, [
        _event('ev-run', _running),
        _plain,
      ], language: language);
      expect(AppRoutes.event(_running), '/events/$_running');
      await tester.tap(
        find.byKey(KHomeBannerCarousel.pageKey('ev-run')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('event:$_running'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the eventId decides: an event banner whose link the app '
      'cannot open (an https URL) still opens the event page', (tester) async {
    await _pumpRouted(tester, [
      _event('ev-url', _upcoming, link: 'https://kabsolive.com/e'),
    ]);
    await tester.tap(
      find.byKey(KHomeBannerCarousel.pageKey('ev-url')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('event:$_upcoming'), findsOneWidget);
  });

  testWidgets('the carousel keeps the server order: the running event first, '
      'then the rest; a plain banner still opens its link', (tester) async {
    final order = [
      _event('ev-run', _running),
      _plain,
      _event('ev-next', _upcoming),
    ];
    await _pumpRouted(tester, order);
    final carousel = tester.widget<KHomeBannerCarousel>(
      find.byType(KHomeBannerCarousel),
    );
    expect(carousel.banners.map((b) => b.id), ['ev-run', 'plain', 'ev-next']);
    // The first page shown is the running event's banner.
    expect(
      find.byKey(KHomeBannerCarousel.pageKey('ev-run')).hitTestable(),
      findsOneWidget,
    );
    // Only the carousel links events: one carousel, no other event entry.
    expect(find.byType(KHomeBannerCarousel), findsOneWidget);
    await tester.drag(
      find
          .descendant(
            of: find.byKey(KHomeBannerCarousel.carouselKey),
            matching: find.byType(PageView),
          )
          .last,
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(KHomeBannerCarousel.pageKey('plain')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('families'), findsOneWidget);
  });
}
