// D129: the live hub's "voice rooms · live" switch (غرف صوتية · بث حي) —
// server-side `kind` on every tab, voice rooms first, the last choice kept
// on the device, the category chips and the banner slot inside the filtered
// list, and the layout in Arabic and English, small screens and large text.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_kind_switch.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// Rooms 0–5 are voice rooms, 6–11 video lives (solo, multi, PK); the
/// handler answers like the server: `kind` filters, a category too.
List<LiveRoomSummary> _allRooms() => [
  for (final (i, room) in apiRooms(12, categories: apiCategories()).indexed)
    room.copyWith(
      mode: i < 6
          ? LiveRoomMode.audio
          : const [LiveRoomMode.solo, LiveRoomMode.multi, LiveRoomMode.pk][i %
                3],
    ),
];

LiveRoomPage _serve(RoomsRequest r) => apiPage([
  for (final room in _allRooms())
    if ((r.kind == null || LiveRoomsKind.of(room.mode) == r.kind) &&
        (r.category == null || room.category?.slug == r.category))
      room,
]);

Future<MemoryLiveHubKind> _pump(
  WidgetTester tester,
  FakeLiveRepository live, {
  AppLanguage language = AppLanguage.en,
  LiveRoomsKind kind = LiveRoomsKind.audio,
  GoldenViewport viewport = GoldenViewport.phone,
  List<HomeBanner> banners = const [],
}) async {
  setViewport(tester, viewport);
  final memory = MemoryLiveHubKind(kind);
  await pumpScreen(
    tester,
    const LiveScreen(),
    language: language,
    homeBannersRepository: FakeHomeBannersRepository(banners: banners),
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      liveScopeProvider.overrideWithValue((
        userId: 'user-me',
        language: language,
      )),
      liveHubKindProvider.overrideWith(() => memory),
    ],
  );
  await tester.pumpAndSettle();
  return memory;
}

List<String> _cardIds(WidgetTester tester) => [
  for (final card in tester.widgetList<KLiveGridCard>(
    find.byType(KLiveGridCard),
  ))
    card.room.roomId ?? '',
];

void main() {
  group('the switch', () {
    testWidgets('voice rooms are first and selected by default; every list '
        'call carries kind=audio', (tester) async {
      final live = FakeLiveRepository(rooms: _serve);
      await _pump(tester, live);
      final audio = find.byKey(
        LiveHubKindSwitch.segmentKey(LiveRoomsKind.audio),
      );
      final video = find.byKey(
        LiveHubKindSwitch.segmentKey(LiveRoomsKind.video),
      );
      expect(find.text('Voice rooms'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      // LTR: voice rooms at the start (left).
      expect(tester.getCenter(audio).dx, lessThan(tester.getCenter(video).dx));
      // Above the tabs, under the title.
      expect(
        tester.getCenter(audio).dy,
        greaterThan(tester.getCenter(find.byKey(LiveHubTopBar.titleKey)).dy),
      );
      expect(
        tester.getCenter(audio).dy,
        lessThan(tester.getCenter(find.text('Popular')).dy),
      );
      expect(live.requests, isNotEmpty);
      expect(live.requests.map((r) => r.kind).toSet(), {LiveRoomsKind.audio});
      for (final id in _cardIds(tester)) {
        expect(int.parse(id.split('-').last), lessThan(6), reason: id);
      }
      expect(
        tester.getSemantics(audio),
        matchesSemantics(
          label: 'Voice rooms',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(video),
        matchesSemantics(
          label: 'Live',
          isButton: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      // A 48 pt touch target per half.
      expect(tester.getSize(audio).height, 48);
    });

    testWidgets('Live shows video lives only (solo, multi, PK), reloading '
        'from the first page, and is remembered', (tester) async {
      final live = FakeLiveRepository(rooms: _serve);
      final memory = await _pump(tester, live);
      final before = live.requests.length;
      await tester.tap(
        find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.video)),
      );
      await tester.pumpAndSettle();
      final after = live.requests.sublist(before);
      expect(after, isNotEmpty);
      expect(after.every((r) => r.kind == LiveRoomsKind.video), isTrue);
      expect(after.every((r) => r.cursor == null), isTrue);
      final ids = _cardIds(tester);
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(int.parse(id.split('-').last), greaterThanOrEqualTo(6));
      }
      expect(memory.saved, [LiveRoomsKind.video]);
      // Selecting it again changes nothing.
      final count = live.requests.length;
      await tester.tap(
        find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.video)),
      );
      await tester.pumpAndSettle();
      expect(live.requests.length, count);
      expect(memory.saved, [LiveRoomsKind.video]);
    });

    testWidgets('the category stays selected across a switch and both '
        'filter together', (tester) async {
      final live = FakeLiveRepository(
        rooms: _serve,
        categories: apiCategories(),
      );
      await _pump(tester, live);
      final slug = apiCategories().first.slug;
      await tester.tap(find.byKey(ValueKey('live.chip.$slug')));
      await tester.pumpAndSettle();
      expect(live.requests.last.category, slug);
      expect(live.requests.last.kind, LiveRoomsKind.audio);
      await tester.tap(
        find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.video)),
      );
      await tester.pumpAndSettle();
      final popular = live.requests.lastWhere(
        (r) => r.tab == LiveRoomsTab.popular,
      );
      expect(popular.category, slug);
      expect(popular.kind, LiveRoomsKind.video);
    });

    testWidgets('the banner still follows the 4th card of the filtered '
        'list', (tester) async {
      final live = FakeLiveRepository(rooms: _serve);
      await _pump(
        tester,
        live,
        kind: LiveRoomsKind.video,
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
      expect(_cardIds(tester).first, 'room-6');
    });

    testWidgets('an empty voice list is the honest empty state, with the '
        'switch still there', (tester) async {
      final live = FakeLiveRepository(
        rooms: (r) =>
            r.kind == LiveRoomsKind.audio ? apiPage(const []) : _serve(r),
      );
      await _pump(tester, live);
      expect(find.byType(KLiveGridCard), findsNothing);
      expect(
        find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.video)),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.video)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KLiveGridCard), findsWidgets);
    });

    testWidgets('Arabic: غرف صوتية at the reading start (right), then بث حي', (
      tester,
    ) async {
      final live = FakeLiveRepository(rooms: _serve);
      await _pump(tester, live, language: AppLanguage.ar);
      expect(find.text('غرف صوتية'), findsOneWidget);
      expect(find.text('بث حي'), findsOneWidget);
      expect(
        tester
            .getCenter(
              find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.audio)),
            )
            .dx,
        greaterThan(
          tester
              .getCenter(
                find.byKey(LiveHubKindSwitch.segmentKey(LiveRoomsKind.video)),
              )
              .dx,
        ),
      );
    });

    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('360×800, ${language.name}, text ×$scale: no overflow', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final live = FakeLiveRepository(rooms: _serve);
          await _pump(
            tester,
            live,
            language: language,
            viewport: GoldenViewport.android,
          );
          expect(tester.takeException(), isNull);
          final row = tester.getRect(find.byType(LiveHubKindSwitch));
          expect(row.height, 48);
          expect(row.width, 360);
        });
      }
    }
  });

  group('the device preference', () {
    Future<ProviderContainer> make(Map<String, Object> saved) async {
      final prefs = await testPrefs(extra: saved);
      final c = ProviderContainer.test(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      return c;
    }

    test('voice rooms when nothing is saved; the saved choice otherwise; '
        'a bad value falls back to voice rooms', () async {
      expect(
        (await make(const {})).read(liveHubKindProvider),
        LiveRoomsKind.audio,
      );
      expect(
        (await make(const {PreferenceKeys.liveHubKind: 'video'}))
            .read(liveHubKindProvider),
        LiveRoomsKind.video,
      );
      expect(
        (await make(const {PreferenceKeys.liveHubKind: 'podcast'}))
            .read(liveHubKindProvider),
        LiveRoomsKind.audio,
      );
    });

    test('a selection is saved on the device', () async {
      final c = await make(const {});
      await c.read(liveHubKindProvider.notifier).select(LiveRoomsKind.video);
      expect(c.read(liveHubKindProvider), LiveRoomsKind.video);
      expect(
        c.read(sharedPreferencesProvider).getString(PreferenceKeys.liveHubKind),
        'video',
      );
    });
  });

  group('the controller', () {
    test('a kind switch reloads every loaded tab with the new kind, keeping '
        'the category; more pages keep the kind', () async {
      final repo = FakeLiveRepository(
        categories: apiCategories(),
        rooms: (r) => apiPage(apiRooms(2), nextCursor: r.cursor ?? 'c1'),
      );
      final memory = MemoryLiveHubKind();
      final c = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          liveRepositoryProvider.overrideWithValue(repo),
          liveScopeProvider.overrideWithValue((
            userId: 'user-me',
            language: AppLanguage.en,
          )),
          liveHubKindProvider.overrideWith(() => memory),
        ],
      );
      for (final tab in FeedTab.values) {
        c.listen(liveRoomsProvider(tab), (_, _) {});
        await c.read(liveRoomsProvider(tab).future);
      }
      await c
          .read(liveRoomsProvider(FeedTab.popular).notifier)
          .selectCategory('music');
      repo.requests.clear();

      await c.read(liveHubKindProvider.notifier).select(LiveRoomsKind.video);
      for (final tab in FeedTab.values) {
        await c.read(liveRoomsProvider(tab).future);
      }
      expect(repo.requests, hasLength(3));
      expect(repo.requests.every((r) => r.kind == LiveRoomsKind.video), isTrue);
      expect(repo.requests.every((r) => r.cursor == null), isTrue);
      expect(
        repo.requests.firstWhere((r) => r.tab == LiveRoomsTab.popular).category,
        'music',
      );
      expect(
        c.read(liveRoomsProvider(FeedTab.popular)).requireValue.category,
        'music',
      );

      repo.requests.clear();
      await c.read(liveRoomsProvider(FeedTab.latest).notifier).loadMore();
      expect(repo.requests.single.kind, LiveRoomsKind.video);
      expect(repo.requests.single.cursor, 'c1');
      expect(
        liveHubContent(c.read(liveRoomsProvider(FeedTab.latest))).value,
        isA<FeedItems<Object?>>(),
      );
    });
  });
}
