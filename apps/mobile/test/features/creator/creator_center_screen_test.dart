// D172: the Creator Center hub in the owner's reference layout — this
// month's real numbers (fakes here), the detailed statistics one tap away,
// every service tile to a real destination or an honest «قريباً», the
// admin's banner only when there is one, the Agency tab (D179's agency
// page, embedded by D184),
// Arabic RTL and English LTR, 360×800 and large text.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/presentation/agency_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/creator/data/creator_repository.dart';
import 'package:kabso_live/features/creator/presentation/creator_center_screen.dart';
import 'package:kabso_live/features/live/application/home_banners_provider.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

class _FakeCreator implements CreatorRepository {
  new({this.fail = false});

  final bool fail;
  final List<CreatorStatsPeriod> calls = [];

  @override
  Future<CreatorStats> mine(CreatorStatsPeriod period) async {
    calls.add(period);
    if (fail) throw const NetworkFailure.offline();
    return CreatorStats(
      period: period,
      followersTotal: 140,
      followersNew: 22,
      posts: const CreatorContentStats(
        published: 0,
        views: 0,
        likes: 0,
        comments: 0,
        shares: 0,
      ),
      reels: const CreatorContentStats(
        published: 0,
        views: 0,
        likes: 0,
        comments: 0,
        shares: 0,
      ),
      // 439 min 50 s → 439 (whole minutes).
      live: const CreatorLiveStats(
        lives: 3,
        liveSeconds: 439 * 60 + 50,
        giftCount: 4,
        giftCoins: 1200,
        earningsCoins: 780,
        newFollowers: 5,
        peakViewers: 9,
      ),
      month: DateTime(2026, 10),
    );
  }
}

const _banner = HomeBanner(
  id: 'b1',
  imageUrl: 'https://example.invalid/b1.png',
  link: '/families',
);

Future<_FakeCreator> _pump(
  WidgetTester tester, {
  _FakeCreator? creator,
  List<HomeBanner> banners = const [],
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  final fake = creator ?? _FakeCreator();
  Widget page(String name) => Scaffold(body: Text('page $name'));
  final router = GoRouter(
    initialLocation: AppRoutes.creatorCenter,
    routes: [
      GoRoute(
        path: AppRoutes.creatorCenter,
        builder: (_, _) => const CreatorCenterScreen(),
      ),
      GoRoute(path: AppRoutes.creatorStats, builder: (_, _) => page('stats')),
      GoRoute(path: AppRoutes.goLive, builder: (_, _) => page('goLive')),
      GoRoute(path: AppRoutes.eventCenter, builder: (_, _) => page('events')),
      GoRoute(
        path: AppRoutes.levelPattern,
        builder: (_, state) =>
            page('level ${state.pathParameters['category']}'),
      ),
      GoRoute(path: AppRoutes.families, builder: (_, _) => page('families')),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        creatorRepositoryProvider.overrideWithValue(fake),
        homeBannersProvider.overrideWith((ref) async => banners),
        agencyRepositoryProvider.overrideWithValue(FakeAgencyRepository()),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _tapService(WidgetTester tester, CreatorService s) async {
  await tester.scrollUntilVisible(
    find.byKey(s.key),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(s.key), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('this month', () {
    testWidgets('loads THIS_MONTH and shows the month, minutes, followers '
        'and earnings', (tester) async {
      final fake = await _pump(tester);
      expect(fake.calls, [CreatorStatsPeriod.thisMonth]);
      expect(find.text(_en.creatorMonthData('October')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.minutesKey),
          matching: find.text('439'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.minutesKey),
          matching: find.text(_en.creatorLiveMinutes),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.fansKey),
          matching: find.text('22'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.fansKey),
          matching: find.text(_en.creatorNewFans),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.earningsKey),
          matching: find.text('780'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.earningsKey),
          matching: find.text(_en.creatorNewEarnings),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Arabic names the month in Arabic', (tester) async {
      await _pump(tester, language: AppLanguage.ar);
      expect(find.text(_ar.creatorMonthData('أكتوبر')), findsOneWidget);
      expect(find.text(_ar.creatorTabLive), findsOneWidget);
      expect(find.text(_ar.creatorGoLive), findsOneWidget);
    });

    testWidgets('a failure shows dashes, never zeros', (tester) async {
      await _pump(tester, creator: _FakeCreator(fail: true));
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.minutesKey),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(CreatorCenterScreen.minutesKey),
          matching: find.text(_en.creatorLiveMinutes),
        ),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
    });

    testWidgets('«Live Data ›» opens the detailed statistics', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(CreatorCenterScreen.liveDataKey));
      await tester.pumpAndSettle();
      expect(find.text('page stats'), findsOneWidget);
    });

    testWidgets('the card itself opens them too', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(CreatorCenterScreen.fansKey));
      await tester.pumpAndSettle();
      expect(find.text('page stats'), findsOneWidget);
    });
  });

  group('banner', () {
    testWidgets('no banner: no slot', (tester) async {
      await _pump(tester);
      expect(find.byKey(CreatorCenterScreen.bannerKey), findsNothing);
    });

    testWidgets("the admin's banner opens its link", (tester) async {
      await _pump(tester, banners: const [_banner]);
      expect(find.byKey(CreatorCenterScreen.bannerKey), findsOneWidget);
      await tester.tap(find.byKey(CreatorCenterScreen.bannerKey));
      await tester.pumpAndSettle();
      expect(find.text('page families'), findsOneWidget);
    });
  });

  group('services', () {
    for (final (service, page) in [
      (CreatorService.preview, 'goLive'),
      (CreatorService.events, 'events'),
      (CreatorService.hostLevel, 'level attractiveness'),
      (CreatorService.fans, 'stats'),
    ]) {
      testWidgets('${service.name} opens $page', (tester) async {
        await _pump(tester);
        await _tapService(tester, service);
        expect(find.text('page $page'), findsOneWidget);
      });
    }

    testWidgets('cover opens the live cover options', (tester) async {
      await _pump(tester);
      await _tapService(tester, CreatorService.cover);
      expect(find.text(_en.liveCoverSheetTitle), findsOneWidget);
      expect(find.byKey(LiveCoverPicture.chooseKey), findsOneWidget);
    });

    testWidgets('traffic card says where it is bought', (tester) async {
      await _pump(tester);
      await _tapService(tester, CreatorService.traffic);
      expect(find.text(_en.creatorTrafficHint), findsOneWidget);
    });

    testWidgets('not built: faded, «Soon», disabled, does nothing', (
      tester,
    ) async {
      await _pump(tester);
      const soon = [
        CreatorService.violations,
        CreatorService.academy,
        CreatorService.support,
        CreatorService.identity,
      ];
      final labels = {
        CreatorService.violations: _en.creatorSvcViolations,
        CreatorService.academy: _en.creatorSvcAcademy,
        CreatorService.support: _en.creatorSvcSupport,
        CreatorService.identity: _en.creatorSvcIdentity,
      };
      for (final s in soon) {
        await _tapService(tester, s);
        expect(find.byType(CreatorCenterScreen), findsOneWidget);
        expect(find.textContaining('page '), findsNothing);
        final node = tester.getSemantics(find.byKey(s.key));
        expect(node.label, _en.meHubSoonItem(labels[s]!));
        expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      }
      expect(
        find.byKey(CreatorCenterScreen.soonKey, skipOffstage: false),
        findsNWidgets(soon.length),
      );
    });

    testWidgets('Go Live floats over the grid and opens the go-live screen', (
      tester,
    ) async {
      await _pump(tester);
      final pill = tester.getRect(find.byKey(CreatorCenterScreen.goLiveKey));
      expect(pill.width, KCreator.goLiveWidth);
      await tester.tap(find.byKey(CreatorCenterScreen.goLiveKey));
      await tester.pumpAndSettle();
      expect(find.text('page goLive'), findsOneWidget);
    });

    testWidgets('the last row scrolls clear of the Go Live pill', (
      tester,
    ) async {
      await _pump(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final pill = tester.getRect(find.byKey(CreatorCenterScreen.goLiveKey));
      final last = tester.getRect(find.byKey(CreatorService.fans.key));
      expect(last.bottom, lessThan(pill.top));
    });
  });

  group('agency', () {
    testWidgets("D179's agency page as the tab (join by code), no Go Live", (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(CreatorCenterScreen.agencyTabKey));
      await tester.pumpAndSettle();
      // No agency yet: the join-by-code card, inside the Creator Center (no
      // second app bar).
      expect(find.byKey(AgencyScreen.codeFieldKey), findsOneWidget);
      expect(find.byType(KAppBar), findsOneWidget);
      expect(find.byKey(CreatorCenterScreen.goLiveKey), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(CreatorCenterScreen.agencyTabKey))
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );
      await tester.tap(find.byKey(CreatorCenterScreen.liveTabKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CreatorCenterScreen.goLiveKey), findsOneWidget);
    });
  });

  group('direction', () {
    testWidgets('Arabic: first tile and tab at the right', (tester) async {
      await _pump(tester, language: AppLanguage.ar);
      final preview = tester.getCenter(find.byKey(CreatorService.preview.key));
      final cover = tester.getCenter(find.byKey(CreatorService.cover.key));
      expect(preview.dx, greaterThan(cover.dx));
      expect(
        tester.getCenter(find.byKey(CreatorCenterScreen.liveTabKey)).dx,
        greaterThan(
          tester.getCenter(find.byKey(CreatorCenterScreen.agencyTabKey)).dx,
        ),
      );
    });

    testWidgets('English: first tile and tab at the left', (tester) async {
      await _pump(tester);
      final preview = tester.getCenter(find.byKey(CreatorService.preview.key));
      final cover = tester.getCenter(find.byKey(CreatorService.cover.key));
      expect(preview.dx, lessThan(cover.dx));
    });
  });

  group('360×800 and large text', () {
    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('${language.name} ×$scale has no overflow', (tester) async {
          await _pump(
            tester,
            language: language,
            viewport: GoldenViewport.android,
            textScale: scale,
            banners: const [_banner],
          );
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(CreatorService.fans.key, skipOffstage: false),
            findsOneWidget,
          );
        });
      }
    }
  });

  test('the period sent is THIS_MONTH on the wire', () {
    expect(CreatorStatsPeriod.thisMonth.wire, 'THIS_MONTH');
    final stats = CreatorStats.fromJson(const {
      'period': 'THIS_MONTH',
      'month': '2026-10',
      'followers': {'total': 1, 'newInPeriod': 1},
      'posts': <String, dynamic>{},
      'reels': <String, dynamic>{},
      'live': <String, dynamic>{},
    });
    expect(stats.period, CreatorStatsPeriod.thisMonth);
    expect(stats.month, DateTime(2026, 10));
    final other = CreatorStats.fromJson(const {
      'period': 'LAST_7_DAYS',
      'month': null,
      'followers': {'total': 1, 'newInPeriod': 1},
      'posts': <String, dynamic>{},
      'reels': <String, dynamic>{},
      'live': <String, dynamic>{},
    });
    expect(other.month, isNull);
  });
}
