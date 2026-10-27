// D131 (owner, ref 165): the Live hub's four filters (Nearby · Popular ▾ ·
// Featured · Explore) over every live video (`kind=video`), Popular's menu
// (Following, All, the categories), D133's Nearby without a country, the
// banner after the 4th card, and the layout in Arabic and English, small
// screens and large text. D131 (ref 166): the Voice rooms screen behind the
// party button (`kind=audio`).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// Rooms 0–3 are voice rooms, 4–11 video lives (solo, multi, PK); the
/// handler answers like the server: `kind` filters, a category too,
/// `featured` keeps rooms 4 and 5, Nearby has no country unless [country].
LiveRoomPage Function(RoomsRequest) _server({String? country}) => (r) {
  if (r.nearby && country == null) {
    return const LiveRoomPage(
      data: [],
      page: PageInfo(nextCursor: null, hasMore: false),
      emptyReason: LiveRoomsEmptyReason.countryNotSet,
    );
  }
  return apiPage([
    for (final (i, room) in apiRooms(12, categories: apiCategories()).indexed)
      if ((r.kind == null ||
              r.kind!.includes(
                i < 4
                    ? LiveRoomMode.audio
                    : const [
                        LiveRoomMode.solo,
                        LiveRoomMode.multi,
                        LiveRoomMode.pk,
                      ][i % 3],
              )) &&
          (r.category == null || room.category?.slug == r.category) &&
          (!r.featured || i == 4 || i == 5))
        room.copyWith(
          mode: i < 4
              ? LiveRoomMode.audio
              : const [
                  LiveRoomMode.solo,
                  LiveRoomMode.multi,
                  LiveRoomMode.pk,
                ][i % 3],
          seatCount: i < 4 ? 8 : null,
          occupiedSeats: i < 4 ? i + 1 : 0,
          viewerCount: 10 + i,
        ),
  ]);
};

Future<FakeLiveRepository> _pump(
  WidgetTester tester, {
  Widget screen = const LiveScreen(),
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  List<HomeBanner> banners = const [],
  String? country,
  FakeAuthRepository? auth,
}) async {
  setViewport(tester, viewport);
  final live = FakeLiveRepository(
    rooms: _server(country: country),
    categories: apiCategories(),
  );
  await pumpScreen(
    tester,
    screen,
    language: language,
    homeBannersRepository: FakeHomeBannersRepository(banners: banners),
    overrides: [
      ...liveOverrides(live, language: language, country: country),
      currentUserProvider.overrideWithValue(
        testUser().copyWith(country: country),
      ),
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ],
  );
  await tester.pumpAndSettle();
  return live;
}

List<int> _cardNumbers(WidgetTester tester) => [
  for (final card in tester.widgetList<KLiveGridCard>(
    find.byType(KLiveGridCard),
  ))
    int.parse((card.room.roomId ?? '').split('-').last),
];

Finder _pill(LiveHubFilter f) => find.byKey(LiveHubFilterBar.pillKey(f));

/// Taps filter [f], scrolling the row to it first (the row scrolls, as in
/// the reference, where Explore is cut by the screen's end).
Future<void> _tapPill(WidgetTester tester, LiveHubFilter f) async {
  await tester.dragUntilVisible(
    _pill(f),
    find.byType(LiveHubFilterBar),
    Offset(f.index < 2 ? 200 : -200, 0),
  );
  await tester.pumpAndSettle();
  await tester.tap(_pill(f));
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('Live hub filters (ref 165)', () {
    testWidgets('opens on Popular: kind=video, tab=popular; the four pills '
        'in order, Popular selected with its chevron', (tester) async {
      final live = await _pump(tester);
      expect(live.requests, isNotEmpty);
      final r = live.requests.last;
      expect(r.kind, LiveRoomsKind.video);
      expect(r.tab, LiveRoomsTab.popular);
      expect(r.nearby || r.featured, isFalse);
      // Video lives only (rooms 4–11).
      expect(_cardNumbers(tester).every((n) => n >= 4), isTrue);
      final xs = [
        for (final f in LiveHubFilter.values.take(3))
          tester.getCenter(_pill(f)).dx,
      ];
      expect(xs, [...xs]..sort());
      expect(find.text(en.liveHubFilterNearby), findsOneWidget);
      expect(find.text(en.liveHubFilterPopular), findsOneWidget);
      expect(find.text(en.liveHubFilterFeatured), findsOneWidget);
      expect(
        tester.getSemantics(_pill(LiveHubFilter.popular)),
        matchesSemantics(
          label: en.liveHubFilterPopular,
          hint: en.liveHubPopularMenuHint,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      // The no tabs row and no chip row of D124 are gone.
      expect(find.byKey(const ValueKey('live.chip.all')), findsNothing);
      // Measured geometry: 33 pt pills, 14.5 pt from the start.
      final nearby = find.descendant(
        of: _pill(LiveHubFilter.nearby),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(nearby).height, closeTo(33, 0.5));
      expect(tester.getRect(nearby).left, closeTo(14.5, 0.5));
      // Cards: 13 pt from the sides (ref 12.8), 0.894 wide : high.
      final card = tester.getRect(find.byKey(LiveHubGrid.cardKey(0)));
      expect(card.left, closeTo(12.8, 0.25));
      expect(card.width / card.height, closeTo(0.894, 0.01));
    });

    testWidgets('Explore = tab=new; Featured = featured=true; Nearby = '
        'scope=nearby; a re-tap refreshes', (tester) async {
      final live = await _pump(tester, country: 'JO');
      await _tapPill(tester, LiveHubFilter.explore);
      expect(live.requests.last.tab, LiveRoomsTab.latest);
      expect(live.requests.last.kind, LiveRoomsKind.video);
      await _tapPill(tester, LiveHubFilter.featured);
      expect(live.requests.last.featured, isTrue);
      expect(_cardNumbers(tester), [4, 5]);
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.last.nearby, isTrue);
      expect(live.requests.last.kind, LiveRoomsKind.video);
      final before = live.requests.length;
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.length, before + 1);
      expect(live.requests.last.cursor, isNull);
    });

    testWidgets("Popular's menu: Following, All and the categories; a "
        'choice becomes the label', (tester) async {
      final live = await _pump(tester);
      // Tapping the selected Popular opens its menu.
      await _tapPill(tester, LiveHubFilter.popular);
      expect(find.byKey(LiveHubFilterBar.menuFollowingKey), findsOneWidget);
      expect(find.byKey(LiveHubFilterBar.menuAllKey), findsOneWidget);
      final slug = apiCategories().first.slug;
      await tester.tap(find.byKey(LiveHubFilterBar.menuCategoryKey(slug)));
      await tester.pumpAndSettle();
      expect(live.requests.last.category, slug);
      expect(live.requests.last.tab, LiveRoomsTab.popular);
      expect(
        find.descendant(
          of: _pill(LiveHubFilter.popular),
          matching: find.text(apiCategories().first.name),
        ),
        findsOneWidget,
      );
      // Following.
      await _tapPill(tester, LiveHubFilter.popular);
      await tester.tap(find.byKey(LiveHubFilterBar.menuFollowingKey));
      await tester.pumpAndSettle();
      expect(live.requests.last.tab, LiveRoomsTab.following);
      expect(live.requests.last.category, isNull);
      expect(
        find.descendant(
          of: _pill(LiveHubFilter.popular),
          matching: find.text(en.feedTabFollowing),
        ),
        findsOneWidget,
      );
      // Another filter, then back: the menu choice is kept (its list is
      // already loaded).
      await _tapPill(tester, LiveHubFilter.explore);
      await _tapPill(tester, LiveHubFilter.popular);
      expect(
        find.descendant(
          of: _pill(LiveHubFilter.popular),
          matching: find.text(en.feedTabFollowing),
        ),
        findsOneWidget,
      );
      expect(find.byKey(LiveHubFilterBar.menuFollowingKey), findsNothing);
    });

    testWidgets('Nearby without a country: the honest state and "Set your '
        'country", which opens the country list and saves the choice', (
      tester,
    ) async {
      final auth = FakeAuthRepository(me: testUser());
      final live = await _pump(tester, auth: auth);
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.last.nearby, isTrue);
      expect(find.text(en.liveNearbyNoCountryTitle), findsOneWidget);
      expect(find.byType(KLiveGridCard), findsNothing);
      await tester.tap(find.text(en.liveNearbySetCountry));
      await tester.pumpAndSettle();
      expect(find.byType(CountryPickerSheet), findsOneWidget);
      await tester.enterText(find.byKey(CountryPickerSheet.searchKey), 'jord');
      await tester.pumpAndSettle();
      expect(find.text('Jordan'), findsOneWidget);
      await tester.tap(find.byKey(CountryPickerSheet.rowKey('JO')));
      await tester.pumpAndSettle();
      expect(auth.countryUpdates, ['JO']);
      expect(find.byType(CountryPickerSheet), findsNothing);
    });

    testWidgets('Nearby with a country but nobody live names the country', (
      tester,
    ) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(const []));
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const LiveScreen(),
        overrides: [
          ...liveOverrides(live, country: 'JO'),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(country: 'JO'),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(find.text(en.liveNearbyEmptyTitle('Jordan')), findsOneWidget);
      expect(find.text(en.liveNearbyChangeCountry), findsOneWidget);
    });

    testWidgets('the banner still follows the 4th card', (tester) async {
      await _pump(
        tester,
        banners: const [
          HomeBanner(
            id: 'b1',
            imageUrl: 'https://media.example.test/b1.webp',
            link: '/families',
          ),
        ],
      );
      expect(find.byKey(LiveHubGrid.bannerSlotKey), findsOneWidget);
      final fourth = tester.getRect(find.byKey(LiveHubGrid.cardKey(3)));
      final banner = tester.getRect(find.byType(KHomeBannerCarousel));
      expect(banner.top, greaterThanOrEqualTo(fourth.bottom));
    });

    testWidgets('Arabic: Nearby at the reading start (right)', (tester) async {
      await _pump(tester, language: AppLanguage.ar);
      expect(find.text(ar.liveHubFilterNearby), findsOneWidget);
      expect(
        tester.getCenter(_pill(LiveHubFilter.nearby)).dx,
        greaterThan(tester.getCenter(_pill(LiveHubFilter.popular)).dx),
      );
    });

    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('360×800, ${language.name}, text ×$scale: no overflow', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await _pump(
            tester,
            language: language,
            viewport: GoldenViewport.android,
          );
          expect(tester.takeException(), isNull);
          await _pump(
            tester,
            screen: const VoiceRoomsScreen(),
            language: language,
            viewport: GoldenViewport.android,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Voice rooms (ref 166)', () {
    testWidgets('Hot · Recommendations by default (kind=audio, '
        'tab=popular), list rows with seats and a count', (tester) async {
      final live = await _pump(tester, screen: const VoiceRoomsScreen());
      final r = live.requests.last;
      expect(r.kind, LiveRoomsKind.audio);
      expect(r.tab, LiveRoomsTab.popular);
      expect(r.nearby, isFalse);
      expect(find.byType(VoiceRoomRow), findsNWidgets(4));
      expect(find.byKey(VoiceRoomRow.seatsKey), findsNWidgets(4));
      expect(find.text('1/8'), findsOneWidget);
      // Measured geometry: rows 68.6 tall, 12.8 from the sides.
      final row = tester.getRect(find.byKey(VoiceRoomList.rowKey(0)));
      expect(row.height, closeTo(68.6, 0.5));
      expect(row.left, closeTo(12.8, 0.1));
      expect(
        tester.getSemantics(
          find.byKey(VoiceRoomsScreen.tabKey(FeedTab.popular)),
        ),
        matchesSemantics(
          label: en.liveVoiceTabHot,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('Follow and New are the server tabs; the country is Nearby; '
        'a category filters; the switch shows the grid', (tester) async {
      final live = await _pump(
        tester,
        screen: const VoiceRoomsScreen(),
        country: 'JO',
      );
      await tester.tap(find.byKey(VoiceRoomsScreen.tabKey(FeedTab.following)));
      await tester.pumpAndSettle();
      expect(live.requests.last.tab, LiveRoomsTab.following);
      await tester.tap(find.byKey(VoiceRoomsScreen.tabKey(FeedTab.latest)));
      await tester.pumpAndSettle();
      expect(live.requests.last.tab, LiveRoomsTab.latest);
      // The second row: the country's name, then Recommendations.
      expect(
        find.descendant(
          of: find.byKey(VoiceRoomsScreen.nearbyKey),
          matching: find.text('Jordan'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(VoiceRoomsScreen.nearbyKey));
      await tester.pumpAndSettle();
      expect(live.requests.last.nearby, isTrue);
      expect(live.requests.last.tab, LiveRoomsTab.latest);
      expect(live.requests.last.kind, LiveRoomsKind.audio);
      final slug = apiCategories().first.slug;
      await tester.dragUntilVisible(
        find.byKey(VoiceRoomsScreen.categoryKey(slug)),
        find.byKey(VoiceRoomsScreen.recommendedKey),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(VoiceRoomsScreen.categoryKey(slug)));
      await tester.pumpAndSettle();
      expect(live.requests.last.category, slug);
      expect(live.requests.last.nearby, isFalse);
      await tester.tap(find.byKey(VoiceRoomsScreen.layoutKey));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceRoomRow), findsNothing);
      expect(find.byType(KLiveGridCard), findsWidgets);
    });

    testWidgets('Arabic: the back arrow and Follow at the reading start', (
      tester,
    ) async {
      await _pump(
        tester,
        screen: const VoiceRoomsScreen(),
        language: AppLanguage.ar,
      );
      expect(find.text(ar.liveVoiceTabHot), findsOneWidget);
      expect(find.text(ar.liveVoiceSection), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(VoiceRoomsScreen.backKey)).dx,
        greaterThan(
          tester
              .getCenter(find.byKey(VoiceRoomsScreen.tabKey(FeedTab.following)))
              .dx,
        ),
      );
    });
  });

  group('country picker (D133)', () {
    testWidgets('searchable in both languages; a failure keeps it open', (
      tester,
    ) async {
      final auth = FakeAuthRepository(me: testUser())
        ..updateCountryFailure = const NetworkFailure.offline();
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCountryPicker(context),
              child: const Text('open'),
            ),
          ),
        ),
        language: AppLanguage.ar,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(CountryPickerSheet.searchKey),
        'الأردن',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(CountryPickerSheet.rowKey('JO')), findsOneWidget);
      await tester.tap(find.byKey(CountryPickerSheet.rowKey('JO')));
      await tester.pumpAndSettle();
      expect(auth.countryUpdates, ['JO']);
      expect(find.byType(CountryPickerSheet), findsOneWidget);
    });
  });
}
