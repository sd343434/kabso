// D394: a promo banner whose link is `/ambassadors` opens «برنامج سفراء
// Kabso» (D390) from every placement that shares the banner opener: the
// programme page (on: the form; off: «قريباً» and no form), the dashboard
// for an ambassador, a short note for a Kabso Team account (who stays where
// they are), and the programme page when the status cannot be read.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_dashboard_screen.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_programme_screen.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/hub_card_banner.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/ambassadors/ambassador_fixtures.dart';
import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Counts the status reads; [failure] makes them fail.
class _Repo extends FakeAmbassadorRepository {
  new({super.programme, this.failure});

  final AppFailure? failure;
  int reads = 0;

  @override
  Future<AmbassadorProgramme> programme() {
    reads++;
    final f = failure;
    if (f != null) return Future.error(f);
    return super.programme();
  }
}

HomeBanner _banner(String id, {int width = 1500, int height = 300}) =>
    HomeBanner(
      id: id,
      imageUrl: 'https://media.example.test/media/$id/$width.webp',
      width: width,
      height: height,
      link: AppRoutes.ambassadors,
    );

User _staff() => testUser().copyWith(
  kabsoTeam: true,
  staff: const KabsoStaffIdentity(role: StaffLineRole.moderation),
);

enum _Placement { home, hubCard, room }

const _staffNote =
    "The Kabso Ambassadors Program isn't available to Kabso Team accounts";
const _soon = 'Coming soon — you can apply once it launches';

/// The placement's page at [AppRoutes.home], the programme's two pages, and
/// the app's staff redirect (a Kabso Team account never reaches them).
Future<GoRouter> _pump(
  WidgetTester tester, {
  required _Placement placement,
  required _Repo repo,
  User? user,
  AppLanguage language = AppLanguage.en,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 2600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final me = user ?? testUser();
  final banners = FakeHomeBannersRepository(
    banners: placement == _Placement.home ? [_banner('amb-home')] : const [],
    hubCardBanners: placement == _Placement.hubCard
        ? [_banner('amb-card', width: 720, height: 805)]
        : const [],
    roomBanners: placement == _Placement.room
        ? [_banner('amb-room', width: 600, height: 800)]
        : const [],
  );
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (_, state) =>
        me.staff != null && AppRoutes.staffBlocked(state.matchedLocation)
        ? AppRoutes.staffUnavailable
        : null,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => switch (placement) {
          _Placement.room => const Scaffold(
            body: Center(child: LiveRoomPromoBox(roomId: 'room-0')),
          ),
          _ => const LiveScreen(),
        },
      ),
      GoRoute(
        path: AppRoutes.ambassadors,
        builder: (_, _) => const AmbassadorProgrammeScreen(),
      ),
      GoRoute(
        path: AppRoutes.ambassadorDashboard,
        builder: (_, _) => const AmbassadorDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffUnavailable,
        builder: (_, _) => const Scaffold(body: Text('staff unavailable')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpScreen(
    tester,
    Router.withConfig(config: router),
    language: language,
    homeBannersRepository: banners,
    overrides: [
      ...liveOverrides(FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6)))),
      currentUserProvider.overrideWithValue(me),
      ambassadorRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapBanner(WidgetTester tester, _Placement placement) async {
  final banner = switch (placement) {
    _Placement.home => find.byKey(KHomeBannerCarousel.pageKey('amb-home')),
    _Placement.hubCard => find.byKey(KHubCardBanner.pageKey('amb-card')),
    _Placement.room => find.byKey(LiveRoomPromoBox.pageKey('amb-room')),
  };
  await tester.ensureVisible(banner);
  await tester.pumpAndSettle();
  await tester.tap(banner.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  test('the link: exactly /ambassadors is an in-app route', () {
    expect(
      HomeBannerTarget.parse('/ambassadors'),
      const HomeBannerRoute(AppRoutes.ambassadors),
    );
    for (final link in [
      '/ambassadors/',
      '/ambassadors/me',
      '/ambassadors?tab=apply',
      '/Ambassadors',
      '/ambassador',
    ]) {
      expect(HomeBannerTarget.parse(link), isNull, reason: link);
    }
  });

  for (final placement in _Placement.values) {
    group('${placement.name} banner', () {
      testWidgets('on: the programme page with the application form', (
        tester,
      ) async {
        final repo = _Repo();
        final router = await _pump(tester, placement: placement, repo: repo);
        await _tapBanner(tester, placement);
        expect(router.state.matchedLocation, AppRoutes.ambassadors);
        expect(find.byType(AmbassadorProgrammeScreen), findsOne);
        expect(find.byKey(AmbassadorProgrammeScreen.submitKey), findsOne);
        expect(tester.takeException(), isNull);
      });

      testWidgets('off: the programme page says «coming soon», no form', (
        tester,
      ) async {
        final repo = _Repo(
          programme: ambassadorProgramme(enabled: false, refusal: 'DISABLED'),
        );
        await _pump(tester, placement: placement, repo: repo);
        await _tapBanner(tester, placement);
        expect(find.byType(AmbassadorProgrammeScreen), findsOne);
        expect(find.byKey(AmbassadorProgrammeScreen.statusKey), findsOne);
        expect(find.text(_soon), findsOne);
        expect(find.byKey(AmbassadorProgrammeScreen.submitKey), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an ambassador: the dashboard, not the programme page', (
        tester,
      ) async {
        final repo = _Repo(
          programme: ambassadorProgramme(
            status: 'AMBASSADOR',
            refusal: 'AMBASSADOR',
          ),
        );
        final router = await _pump(tester, placement: placement, repo: repo);
        await _tapBanner(tester, placement);
        expect(router.state.matchedLocation, AppRoutes.ambassadorDashboard);
        expect(find.byType(AmbassadorDashboardScreen), findsOne);
        expect(find.byType(AmbassadorProgrammeScreen), findsNothing);
        expect(find.byKey(AmbassadorDashboardScreen.copyKey), findsOne);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a Kabso Team account: a short note, stays where it is', (
        tester,
      ) async {
        final repo = _Repo();
        final router = await _pump(
          tester,
          placement: placement,
          repo: repo,
          user: _staff(),
        );
        await _tapBanner(tester, placement);
        expect(find.text(_staffNote), findsOne);
        expect(router.state.matchedLocation, AppRoutes.home);
        expect(find.byType(AmbassadorProgrammeScreen), findsNothing);
        expect(find.text('staff unavailable'), findsNothing);
        expect(repo.reads, 0);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('the status cannot be read: the programme page opens and says '
      'why', (tester) async {
    final repo = _Repo(failure: const NetworkFailure.offline());
    final router = await _pump(tester, placement: _Placement.home, repo: repo);
    await _tapBanner(tester, _Placement.home);
    expect(router.state.matchedLocation, AppRoutes.ambassadors);
    expect(find.byType(AmbassadorProgrammeScreen), findsOne);
    expect(find.byKey(AmbassadorProgrammeScreen.submitKey), findsNothing);
    expect(repo.reads, 2);
  });

  testWidgets('Arabic: the staff note', (tester) async {
    await _pump(
      tester,
      placement: _Placement.home,
      repo: _Repo(),
      user: _staff(),
      language: AppLanguage.ar,
    );
    await _tapBanner(tester, _Placement.home);
    expect(
      find.text('برنامج سفراء Kabso غير متاح لحسابات فريق Kabso'),
      findsOne,
    );
  });
}
