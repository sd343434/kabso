// D131 (owner, ref 165): the Live hub's four filters (Nearby · Popular ▾ ·
// Featured · Explore) over every live video (`kind=video`), Popular's menu
// (Following, All, the categories), D133's Nearby without a country, the
// banner after the first row (D248), and the layout in Arabic and English,
// small screens and large text. D131 (ref 166): the Voice rooms screen
// behind the party button (`kind=audio`); D342: one mixed list of every
// party kind (`kind=party_all`), each card with its kind's badge.

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_boost_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/live_boost_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/live_nearby_country.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// The mode of fixture room [i]: 0–3 voice rooms (D342: room 1 a podcast),
/// 4–11 video lives (solo, multi, PK).
LiveRoomMode _mode(int i) => i < 4
    ? (i == 1 ? LiveRoomMode.podcast : LiveRoomMode.audio)
    : const [LiveRoomMode.solo, LiveRoomMode.multi, LiveRoomMode.pk][i % 3];

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
      if ((r.kind == null || r.kind!.includes(_mode(i))) &&
          (r.category == null || room.category?.slug == r.category) &&
          (!r.featured || i == 4 || i == 5))
        room.copyWith(
          mode: _mode(i),
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
  List<LiveBoostedRoom>? boosted,
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
      if (boosted != null)
        liveBoostedRoomsProvider.overrideWith((ref) async => boosted),
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
    Offset(f.index < 3 ? 200 : -200, 0),
  );
  await tester.pumpAndSettle();
  await tester.tap(_pill(f));
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('Live hub filters (ref 165)', () {
    testWidgets('opens on Popular: D239 video lives only (kind=solo), '
        'tab=popular; the four pills in order, Popular selected with its '
        'chevron', (tester) async {
      final live = await _pump(tester);
      expect(live.requests, isNotEmpty);
      final r = live.requests.last;
      // D212 (owner): the category row's «الكل» lists every live; the
      // «بث مباشر» tab is the video lives (kind=solo, podcast_d212_test).
      // D239: the main hub is solo and PK only (server-side kind=solo).
      expect(r.kind, LiveRoomsKind.solo);
      expect(r.tab, LiveRoomsTab.popular);
      expect(r.nearby || r.featured, isFalse);
      // D239: no audio rooms (0–3) and no multi (i % 3 == 1).
      expect(_cardNumbers(tester), isNotEmpty);
      expect(_cardNumbers(tester).any((n) => n < 4), isFalse);
      expect(_cardNumbers(tester).any((n) => n % 3 == 1), isFalse);
      final xs = [
        for (final f in LiveHubFilter.values.take(3))
          tester.getCenter(_pill(f)).dx,
      ];
      expect(xs, [...xs]..sort());
      // D237: Following, Nearby, Popular on screen; the row scrolls on.
      expect(find.text(en.liveHubFilterFollowing), findsOneWidget);
      expect(find.text(en.liveHubFilterNearby), findsOneWidget);
      expect(find.text(en.liveHubFilterPopular), findsOneWidget);
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
      // D237: Following is the first pill.
      final nearby = find.descendant(
        of: _pill(LiveHubFilter.following),
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
      expect(live.requests.last.kind, LiveRoomsKind.solo);
      await _tapPill(tester, LiveHubFilter.featured);
      expect(live.requests.last.featured, isTrue);
      expect(_cardNumbers(tester), [5]); // D239: 4 is a multi
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.last.nearby, isTrue);
      expect(live.requests.last.kind, LiveRoomsKind.solo);
      final before = live.requests.length;
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.length, before + 1);
      expect(live.requests.last.cursor, isNull);
    });

    testWidgets("Popular's menu: All and the categories (D237: not "
        'Following); a choice becomes the label', (tester) async {
      final live = await _pump(tester);
      // Tapping the selected Popular opens its menu.
      await _tapPill(tester, LiveHubFilter.popular);
      expect(
        find.byKey(const Key('liveHub.popularMenu.following')),
        findsNothing,
      );
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
      // Another filter, then back: the menu choice is kept (its list is
      // already loaded).
      await _tapPill(tester, LiveHubFilter.explore);
      await _tapPill(tester, LiveHubFilter.popular);
      expect(
        find.descendant(
          of: _pill(LiveHubFilter.popular),
          matching: find.text(apiCategories().first.name),
        ),
        findsOneWidget,
      );
    });

    testWidgets('D237: «المتابَعين» is the first tab (the reading start), '
        'the people I follow (D239: solo and PK)', (tester) async {
      final live = await _pump(tester);
      expect(LiveHubFilter.values, [
        LiveHubFilter.following,
        LiveHubFilter.nearby,
        LiveHubFilter.popular,
        LiveHubFilter.featured,
        LiveHubFilter.explore,
      ]);
      expect(
        tester.getRect(_pill(LiveHubFilter.following)).left,
        closeTo(14.5, 0.5),
      );
      await _tapPill(tester, LiveHubFilter.following);
      expect(live.requests.last.tab, LiveRoomsTab.following);
      expect(live.requests.last.kind, LiveRoomsKind.solo);
      expect(live.requests.last.category, isNull);
    });

    testWidgets('Nearby without a country: the honest state and "Set your '
        'country", which opens the country list; D240: the choice is kept '
        'on the device (never the profile) and Nearby reloads with it', (
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
      expect(auth.countryUpdates, isEmpty);
      expect(find.byType(CountryPickerSheet), findsNothing);
      expect(live.requests.last.country, 'JO');
      expect(live.requests.last.nearby, isTrue);
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

    for (final language in AppLanguage.values) {
      testWidgets('D237: nobody I follow is live — the honest copy and '
          '«عرض الرائج» (${language.name})', (tester) async {
        final l10n = l10nFor(language);
        final live = FakeLiveRepository(rooms: (_) => apiPage(const []));
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          const LiveScreen(),
          language: language,
          overrides: [...liveOverrides(live, language: language)],
        );
        await tester.pumpAndSettle();
        await _tapPill(tester, LiveHubFilter.following);
        expect(find.text(l10n.liveHubFollowingEmptyTitle), findsOneWidget);
        await tester.tap(find.text(l10n.feedSeePopular));
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(_pill(LiveHubFilter.popular))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
      });
    }

    testWidgets('D237: no category row; every card names its kind, from the '
        "room's mode. D239: only solo and PK (no audio, podcast or multi)", (
      tester,
    ) async {
      final live = await _pump(tester);
      expect(find.byType(LiveHubCategoryBar), findsNothing);
      expect(live.requests.last.kind, LiveRoomsKind.solo);
      final types = {
        for (final card in tester.widgetList<KLiveGridCard>(
          find.byType(KLiveGridCard),
        ))
          card.room.roomId: tester
              .widget<LiveTypeTag>(
                find.descendant(
                  of: find.byWidget(card),
                  matching: find.byKey(KLiveGridCard.typeKey),
                ),
              )
              .kind,
      };
      expect(types.values, everyElement(isNotNull));
      // D362: drawn as its tiny tag beside the live wave.
      expect(types.values.toSet(), {LiveCardKind.live, LiveCardKind.pk});
    });

    testWidgets('D239: a «مميز» (rocket) audio or multi room is not pinned '
        'on the hub; it is pinned in its party tab instead', (tester) async {
      final rooms = apiRooms(12, categories: apiCategories());
      LiveBoostedRoom boost(int i, LiveRoomMode mode) => LiveBoostedRoom(
        room: rooms[i].copyWith(mode: mode),
        endsAt: DateTime.now().add(const Duration(minutes: 10)),
        stage: 2,
      );
      final boosted = [
        boost(0, LiveRoomMode.audio),
        boost(4, LiveRoomMode.multi),
        boost(5, LiveRoomMode.pk),
      ];
      await _pump(tester, boosted: boosted);
      List<(int, bool)> featured() => [
        for (final card in tester.widgetList<KLiveGridCard>(
          find.byType(KLiveGridCard),
        ))
          (
            int.parse((card.room.roomId ?? '').split('-').last),
            card.room.featured,
          ),
      ];
      // The PK room is pinned first; the audio and multi rooms are nowhere.
      expect(featured().first, (5, true));
      expect(featured().map((e) => e.$1), isNot(contains(0)));
      expect(featured().map((e) => e.$1), isNot(contains(4)));
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, screen: const VoiceRoomsScreen(), boosted: boosted);
      // The party page (D342: every party kind): the rocket audio room is
      // pinned there.
      expect(find.byType(VoiceRoomRow).evaluate(), isNotEmpty);
      expect(
        tester
            .widget<VoiceRoomRow>(find.byType(VoiceRoomRow).first)
            .room
            .roomId,
        rooms[0].id,
      );
    });

    testWidgets('D303: the banner is the first block, above the first row', (
      tester,
    ) async {
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
      final first = tester.getRect(find.byKey(LiveHubGrid.cardKey(0)));
      final second = tester.getRect(find.byKey(LiveHubGrid.cardKey(1)));
      final banner = tester.getRect(find.byType(KHomeBannerCarousel));
      expect(first.top, greaterThan(banner.bottom));
      expect(second.top, greaterThan(banner.bottom));
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

  group('Voice rooms — D246 party page (owner reference)', () {
    Future<void> tapFilter(WidgetTester tester, LiveHubFilter f) async {
      await tester.tap(find.byKey(VoiceRoomsScreen.filterKey(f)));
      await tester.pumpAndSettle();
    }

    testWidgets('D342: the filters are the big top tabs (Popular selected); '
        'no Live switch and no kinds row; one mixed list of every party '
        'kind (kind=party_all) in the server order, each card with its '
        "kind's badge; cards with seats and a count", (tester) async {
      final live = await _pump(tester, screen: const VoiceRoomsScreen());
      final r = live.requests.last;
      expect(r.kind, LiveRoomsKind.partyAll);
      expect(r.tab, LiveRoomsTab.popular);
      expect(r.nearby, isFalse);
      expect(r.category, isNull);
      // One list: no other kind was asked for.
      expect(live.requests.map((e) => e.kind).toSet(), {
        LiveRoomsKind.partyAll,
      });
      expect(find.byType(LiveHubFilterBar), findsNothing);
      expect(find.byType(LiveHubCategoryBar), findsNothing);
      expect(find.byType(LiveNearbyCountryRow), findsNothing);
      expect(find.byKey(VoiceRoomsScreen.countryKey), findsNothing);
      for (final f in VoiceRoomsScreen.filters) {
        expect(find.byKey(VoiceRoomsScreen.filterKey(f)), findsOneWidget);
      }
      // «المميزة» is not a tab: the paid «مميز» lives pin first instead.
      expect(
        find.byKey(VoiceRoomsScreen.filterKey(LiveHubFilter.featured)),
        findsNothing,
      );
      // D342 (owner: «زر في الاعلى لنقل المستخدم على لايف … ازله»): no
      // Live switch (its key and its name), no bell, no search.
      expect(find.byKey(const Key('voiceRooms.live')), findsNothing);
      expect(find.byType(KLiveIcon), findsNothing);
      expect(find.byTooltip(en.liveCategoryLive), findsNothing);
      expect(find.byType(NotificationsBell), findsNothing);
      expect(find.byTooltip(en.feedSearch), findsNothing);
      // D342 (owner: «ازل فلاتر بث صوتي بث بوكاست و بث متعدد»): no kinds
      // row and none of its tabs.
      expect(find.byKey(const Key('voiceRooms.kinds')), findsNothing);
      for (final k in LiveHubCategory.values) {
        expect(find.byKey(Key('voiceRooms.kind.${k.name}')), findsNothing);
      }
      // The header is the filters' row only: the section row right under.
      expect(
        tester.getRect(find.byKey(VoiceRoomsScreen.layoutKey)).top -
            tester.getRect(find.byKey(VoiceRoomsScreen.filtersKey)).bottom,
        lessThan(KVoiceRoomsHeader.subRow),
      );
      // Not pushed here: no back button.
      expect(find.byKey(VoiceRoomsScreen.backKey), findsNothing);
      // Every party room of the server's page, in its order — audio,
      // podcast and multi mixed — and no video live.
      const expected = [0, 1, 2, 3, 4, 7, 10];
      final shown = [
        for (final row in tester.widgetList<VoiceRoomRow>(
          find.byType(VoiceRoomRow),
        ))
          int.parse(row.room.roomId!.split('-').last),
      ];
      expect(shown, expected.take(shown.length).toList());
      expect(shown.length, greaterThanOrEqualTo(5));
      // Each card's badge says its own kind.
      for (final (i, n) in shown.indexed) {
        final kind = switch (_mode(n)) {
          LiveRoomMode.podcast => PartyKind.podcast,
          LiveRoomMode.multi => PartyKind.multi,
          _ => PartyKind.audio,
        };
        final row = find.byKey(VoiceRoomList.rowKey(i));
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(LiveTypeTag.keyOf(kind.cardKind)),
          ),
          findsOneWidget,
          reason: 'row $i (room $n)',
        );
        for (final other in PartyKind.values.where((k) => k != kind)) {
          expect(
            find.descendant(
              of: row,
              matching: find.byKey(LiveTypeTag.keyOf(other.cardKind)),
            ),
            findsNothing,
          );
        }
      }
      for (final kind in PartyKind.values) {
        expect(find.byKey(LiveTypeTag.keyOf(kind.cardKind)), findsWidgets);
      }
      // The voice rooms (0–3) have seats; the first's 1/8.
      expect(find.text('1/8'), findsOneWidget);
      expect(find.byKey(VoiceRoomRow.kindKey), findsNWidgets(shown.length));
      // No level or "Popular" pill: the summary has no such data.
      expect(find.text('Lv.'), findsNothing);
      // Measured geometry: cards 68.6 tall, 12.8 from the sides.
      final row = tester.getRect(find.byKey(VoiceRoomList.rowKey(0)));
      expect(row.height, closeTo(68.6, 0.5));
      expect(row.left, closeTo(12.8, 0.1));
      final popular = tester.widget<Text>(
        find.descendant(
          of: find.byKey(VoiceRoomsScreen.filterKey(LiveHubFilter.popular)),
          matching: find.byType(Text),
        ),
      );
      expect(popular.style!.fontSize, KVoiceRoomsHeader.tabSelected);
      expect(
        tester.getSemantics(
          find.byKey(VoiceRoomsScreen.filterKey(LiveHubFilter.popular)),
        ),
        matchesSemantics(
          label: en.liveHubFilterPopular,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      // A screen reader hears each card's kind in full.
      expect(
        tester.getSemantics(find.byKey(VoiceRoomList.rowKey(1))).label,
        contains(en.liveCategoryPodcast),
      );
    });

    testWidgets('D342: each filter is one party_all list; Nearby sends the '
        'country and shows it in its own row; the switch shows the grid '
        'with the same badges', (tester) async {
      final live = await _pump(
        tester,
        screen: const VoiceRoomsScreen(),
        country: 'JO',
      );
      await tapFilter(tester, LiveHubFilter.following);
      expect(live.requests.last.tab, LiveRoomsTab.following);
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      await tapFilter(tester, LiveHubFilter.explore);
      expect(live.requests.last.tab, LiveRoomsTab.latest);
      expect(live.requests.last.featured, isFalse);
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      final filtersRow = tester.getRect(
        find.byKey(VoiceRoomsScreen.filtersKey),
      );
      await tapFilter(tester, LiveHubFilter.nearby);
      expect(live.requests.last.nearby, isTrue);
      expect(live.requests.last.country, 'JO');
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      // The country under the filters (the ref's «Jordan»), the only tab of
      // the second row.
      expect(
        find.descendant(
          of: find.byKey(VoiceRoomsScreen.countryKey),
          matching: find.text('Jordan'),
        ),
        findsOneWidget,
      );
      final country = tester.getRect(find.byKey(VoiceRoomsScreen.countryKey));
      expect(country.top, greaterThanOrEqualTo(filtersRow.bottom - 0.5));
      expect(country.left, closeTo(KVoiceRoomsHeader.subTabInset, 0.5));
      // A tap opens the local picker; a choice reloads Nearby with it.
      await tester.tap(find.byKey(VoiceRoomsScreen.countryKey));
      await tester.pumpAndSettle();
      expect(find.byType(CountryPickerSheet), findsOneWidget);
      expect(find.byKey(CountryPickerSheet.clearKey), findsNothing);
      await tester.enterText(find.byKey(CountryPickerSheet.searchKey), 'Egy');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CountryPickerSheet.rowKey('EG')));
      await tester.pumpAndSettle();
      expect(live.requests.last.country, 'EG');
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      await tapFilter(tester, LiveHubFilter.following);
      expect(find.byKey(VoiceRoomsScreen.countryKey), findsNothing);
      await tapFilter(tester, LiveHubFilter.popular);
      await tester.tap(find.byKey(VoiceRoomsScreen.layoutKey));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceRoomRow), findsNothing);
      expect(find.byType(KLiveGridCard), findsWidgets);
      // The grid keeps the list (no new request) and its badges.
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      for (final card in tester.widgetList<KLiveGridCard>(
        find.byType(KLiveGridCard),
      )) {
        final n = int.parse(card.room.roomId!.split('-').last);
        final kind = switch (_mode(n)) {
          LiveRoomMode.podcast => PartyKind.podcast,
          LiveRoomMode.multi => PartyKind.multi,
          _ => PartyKind.audio,
        };
        expect(
          tester
              .widget<LiveTypeTag>(
                find.descendant(
                  of: find.byWidget(card),
                  matching: find.byKey(KLiveGridCard.typeKey),
                ),
              )
              .kind,
          kind.cardKind,
          reason: 'room $n',
        );
      }
    });

    testWidgets('D342: the empty mixed list says so honestly (no voice-only '
        'copy) and offers Try again', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final live = FakeLiveRepository(
        rooms: (_) => apiPage(const []),
        categories: apiCategories(),
      );
      await pumpScreen(
        tester,
        const VoiceRoomsScreen(),
        overrides: [
          ...liveOverrides(live),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      expect(find.text(en.livePartyEmptyTitle), findsOneWidget);
      expect(find.text(en.livePartyEmptyBody), findsOneWidget);
      expect(find.text(en.liveVoiceEmptyTitle), findsNothing);
      expect(find.byType(VoiceRoomRow), findsNothing);
      final before = live.requests.length;
      await tester.tap(find.text(en.actionRetry).first);
      await tester.pumpAndSettle();
      expect(live.requests.length, greaterThan(before));
    });

    testWidgets('cards show only the API facts: «رائج» (popular), «PK» '
        '(inPk), the level (roomLevel), «مميز» (a paid slot), the flag '
        '(hostCountry), the topic under the title, a mic for audio and a '
        'camera for multi', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: const [
              VoiceRoomRow(
                key: Key('a'),
                room: LiveRoomCardData(
                  hostName: 'Sara',
                  title: 'Tarab night',
                  viewerCount: 102,
                  isAudio: true,
                  inPk: true,
                  featured: true,
                  topic: 'welcome',
                  popular: true,
                  roomLevel: 12,
                  hostCountry: 'JO',
                ),
              ),
              VoiceRoomRow(
                key: Key('m'),
                room: LiveRoomCardData(
                  hostName: 'Omar',
                  title: 'Game night',
                  viewerCount: 84,
                  isMulti: true,
                ),
              ),
              VoiceRoomRow(
                key: Key('p'),
                room: LiveRoomCardData(
                  hostName: 'Lina',
                  title: 'Startup talk',
                  viewerCount: 40,
                  isAudio: true,
                  isPodcast: true,
                  podcast: LivePodcast(
                    episodeNumber: 12,
                    topic: PodcastTopic.business,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Finder inCard(String k, Finder f) =>
          find.descendant(of: find.byKey(Key(k)), matching: f);
      expect(inCard('a', find.byKey(VoiceRoomRow.pkKey)), findsOneWidget);
      expect(inCard('a', find.byKey(VoiceRoomRow.featuredKey)), findsOneWidget);
      expect(inCard('a', find.text('welcome')), findsOneWidget);
      // D342: each kind its own mark on the picture (D362: its tiny tag
      // beside the live wave, no glyph).
      expect(
        inCard('a', find.byKey(LiveTypeTag.keyOf(PartyKind.audio.cardKind))),
        findsOneWidget,
      );
      expect(inCard('a', find.text(en.liveTypeTagVoice)), findsOneWidget);
      // The count's mic.
      expect(inCard('a', find.byIcon(Icons.mic_rounded)), findsOneWidget);
      // D246 (v1.58-live): «رائج», the host's level and flag — from the API.
      expect(inCard('a', find.byKey(VoiceRoomRow.popularKey)), findsOneWidget);
      expect(inCard('a', find.text(en.liveCardPopular)), findsOneWidget);
      expect(
        tester
            .widget<CharmLevelBadge>(
              inCard('a', find.byKey(VoiceRoomRow.levelKey)),
            )
            .level,
        12,
      );
      final flag = tester.widget<Image>(
        inCard(
          'a',
          find.descendant(
            of: find.byKey(VoiceRoomRow.flagKey),
            matching: find.byType(Image),
          ),
        ),
      );
      expect((flag.image as AssetImage).assetName, 'assets/flags/jo.webp');
      // None of them without the data (an older server, no country).
      expect(inCard('m', find.byKey(VoiceRoomRow.popularKey)), findsNothing);
      expect(inCard('m', find.byKey(VoiceRoomRow.levelKey)), findsNothing);
      expect(inCard('m', find.byKey(VoiceRoomRow.flagKey)), findsNothing);
      expect(inCard('m', find.byKey(VoiceRoomRow.pkKey)), findsNothing);
      expect(inCard('m', find.byKey(VoiceRoomRow.featuredKey)), findsNothing);
      expect(inCard('m', find.byKey(VoiceRoomRow.topicKey)), findsNothing);
      expect(inCard('m', find.byKey(VoiceRoomRow.seatsKey)), findsNothing);
      expect(
        inCard('m', find.byKey(LiveTypeTag.keyOf(PartyKind.multi.cardKind))),
        findsOneWidget,
      );
      expect(inCard('m', find.text(en.liveTypeTagMulti)), findsOneWidget);
      expect(inCard('m', find.byIcon(Icons.videocam_rounded)), findsOneWidget);
      // A podcast: its badge, and its episode and topic under the title.
      expect(
        inCard('p', find.byKey(LiveTypeTag.keyOf(PartyKind.podcast.cardKind))),
        findsOneWidget,
      );
      expect(inCard('p', find.text(en.liveTypeTagPodcast)), findsOneWidget);
      expect(
        inCard('p', find.byKey(LiveTypeTag.keyOf(PartyKind.audio.cardKind))),
        findsNothing,
      );
      expect(inCard('p', find.text('Episode 12 · Business')), findsOneWidget);
      // D362: no chip and no glyph — a 9 sp weight-800 white tag with a
      // soft shadow, never taller than the old 18 lp chip.
      for (final k in PartyKind.values) {
        final tag = find.byKey(LiveTypeTag.keyOf(k.cardKind));
        expect(
          find.descendant(of: tag, matching: find.byType(Container)),
          findsNothing,
        );
        expect(tester.getSize(tag).height, lessThanOrEqualTo(18));
        expect(
          find.descendant(of: tag, matching: find.byType(CustomPaint)),
          findsNothing,
        );
        final style = tester
            .widget<Text>(
              find.descendant(
                of: tag,
                matching: find.byKey(LiveTypeTag.textKey),
              ),
            )
            .style!;
        expect(style.color, const Color(0xFFFFFFFF));
        expect(style.fontSize, 9);
        expect(style.fontWeight, FontWeight.w800);
        expect(style.shadows, LiveTypeTag.shadows);
      }
      // Right beside the live wave, at the cover's bottom start.
      final cover = tester.getRect(find.byKey(const Key('a')));
      final mark = find.descendant(
        of: find.byKey(const Key('a')),
        matching: find.byKey(VoiceRoomRow.kindKey),
      );
      final wave = tester.getRect(
        find.descendant(of: mark, matching: find.byType(KLiveEqualizer)),
      );
      final badge = tester.getRect(
        find.byKey(LiveTypeTag.keyOf(PartyKind.audio.cardKind)),
      );
      expect(wave.left - cover.left, closeTo(KVoiceRoomRow.markStart, 0.5));
      expect(badge.left - wave.right, closeTo(3, 0.5));
      expect((badge.center.dy - wave.center.dy).abs(), lessThan(1.5));
      expect(badge.bottom, lessThan(cover.bottom));
      expect(badge.top - cover.top, greaterThan(cover.height / 2));
      expect(tester.getSize(find.byKey(const Key('a'))).height, 68.6);
      expect(tester.getSize(find.byKey(const Key('p'))).height, 68.6);
    });

    testWidgets('Arabic: «المتابَعة» at the reading start; the badges in '
        'Arabic at the start of each picture; nothing in the corner', (
      tester,
    ) async {
      await _pump(
        tester,
        screen: const VoiceRoomsScreen(),
        language: AppLanguage.ar,
      );
      expect(find.text(ar.liveVoiceSection), findsOneWidget);
      expect(find.text(ar.livePartyTabFollowing), findsOneWidget);
      final following = tester.getCenter(
        find.byKey(VoiceRoomsScreen.filterKey(LiveHubFilter.following)),
      );
      final nearby = tester.getCenter(
        find.byKey(VoiceRoomsScreen.filterKey(LiveHubFilter.nearby)),
      );
      expect(following.dx, greaterThan(nearby.dx));
      expect(find.byKey(const Key('voiceRooms.live')), findsNothing);
      expect(find.byKey(const Key('voiceRooms.kinds')), findsNothing);
      for (final (kind, label) in [
        // D362: the owner's short English tags in Arabic too.
        (PartyKind.audio, ar.liveTypeTagVoice),
        (PartyKind.podcast, ar.liveTypeTagPodcast),
        (PartyKind.multi, ar.liveTypeTagMulti),
      ]) {
        final badge = find.byKey(LiveTypeTag.keyOf(kind.cardKind)).first;
        expect(
          find.descendant(of: badge, matching: find.text(label)),
          findsOneWidget,
        );
      }
      // RTL: the cover (and its badge) at the right of the card.
      final row = tester.getRect(find.byKey(VoiceRoomList.rowKey(1)));
      final badge = tester.getRect(
        find.byKey(LiveTypeTag.keyOf(PartyKind.podcast.cardKind)).first,
      );
      expect(badge.right, lessThanOrEqualTo(row.right));
      expect(badge.left, greaterThan(row.right - KVoiceRoomRow.height));
    });
  });

  group('D240 «القريبة» = a country the viewer chooses', () {
    testWidgets('the hub: the profile country by default, the row opens the '
        'picker, a choice reloads Nearby with it and is kept', (tester) async {
      final live = await _pump(tester, country: 'JO');
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.last.nearby, isTrue);
      expect(live.requests.last.country, 'JO');
      expect(live.requests.last.kind, LiveRoomsKind.solo);
      await tester.tap(find.byKey(LiveNearbyCountryRow.rowKey));
      await tester.pumpAndSettle();
      expect(find.byType(CountryPickerSheet), findsOneWidget);
      expect(find.text(en.liveCountryPickerTitle), findsOneWidget);
      // A local choice: no «remove my country» row.
      expect(find.byKey(CountryPickerSheet.clearKey), findsNothing);
      await tester.enterText(find.byKey(CountryPickerSheet.searchKey), 'Egy');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CountryPickerSheet.rowKey('EG')));
      await tester.pumpAndSettle();
      expect(find.byType(CountryPickerSheet), findsNothing);
      expect(live.requests.last.country, 'EG');
      expect(live.requests.last.nearby, isTrue);
      expect(
        find.descendant(
          of: find.byKey(LiveNearbyCountryRow.rowKey),
          matching: find.text('Egypt'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no profile country: the honest empty state and the row '
        'both open the picker', (tester) async {
      final live = await _pump(tester);
      await _tapPill(tester, LiveHubFilter.nearby);
      expect(live.requests.last.country, isNull);
      expect(find.text(en.liveNearbyNoCountryTitle), findsOneWidget);
      expect(find.text(en.liveNearbyChooseCountry), findsOneWidget);
      await tester.tap(find.byKey(LiveNearbyCountryRow.rowKey));
      await tester.pumpAndSettle();
      expect(find.byType(CountryPickerSheet), findsOneWidget);
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
