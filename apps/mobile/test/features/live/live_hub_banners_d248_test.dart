// D248 (owner: «اجعل التصميم مشابه للبيجو لايف بحيث بعد أول بثين هناك بنر
// متحرك، وفي الأسفل قليلاً بنر بحجم اللايف», refs 375/376): the promo
// carousel after the first row of the hub's grid and a card-size banner
// (`placement=hub_card`) in one grid cell — its position, size, rotation,
// tap, hidden states, filters, paging and refresh, Arabic and English.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/live/presentation/hub/hub_card_banner.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// [pages] pages of [size] rooms with cursors `c1`, `c2`, ….
RoomsHandler _paged(int pages, {int size = 20}) => (r) {
  final index = r.cursor == null ? 0 : int.parse(r.cursor!.substring(1));
  return apiPage(
    apiRooms(size, start: index * size),
    nextCursor: index + 1 < pages ? 'c${index + 1}' : null,
  );
};

Future<FakeLiveRepository> _pumpHub(
  WidgetTester tester, {
  int rooms = 8,
  RoomsHandler? handler,
  List<HomeBanner> banners = const [],
  List<HomeBanner> cards = const [],
  int cell = HubCardBanners.defaultCell,
  FakeHomeBannersRepository? repo,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  setViewport(tester, viewport);
  final live = FakeLiveRepository(
    rooms:
        handler ??
        (_) => apiPage(apiRooms(rooms, ar: language == AppLanguage.ar)),
  );
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
    homeBannersRepository:
        repo ??
        FakeHomeBannersRepository(
          banners: banners,
          hubCardBanners: cards,
          hubCardCell: cell,
        ),
    overrides: liveOverrides(live, language: language),
  );
  await tester.pumpAndSettle();
  return live;
}

Future<void> _scrollBy(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(CustomScrollView).first, Offset(0, -dy));
  await tester.pumpAndSettle();
}

/// Which card banner the cell shows now.
String? _shownCard(WidgetTester tester) {
  for (final id in ['card-0', 'card-1', 'card-2']) {
    final page = find.byKey(KHubCardBanner.pageKey(id));
    if (page.evaluate().isEmpty) continue;
    final opacity = tester.widget<FadeTransition>(
      find.ancestor(of: page, matching: find.byType(FadeTransition)).first,
    );
    if (opacity.opacity.value == 1) return id;
  }
  return null;
}

void main() {
  test('cells: the card banner at its cell, after the last room when there '
      'are fewer, none without it', () {
    expect(LiveHubGrid.cells(6, cardBannerCell: 4), [0, 1, 2, 3, null, 4, 5]);
    expect(LiveHubGrid.cells(3, cardBannerCell: 4), [0, 1, 2, null]);
    expect(LiveHubGrid.cells(4, cardBannerCell: 4), [0, 1, 2, 3, null]);
    expect(LiveHubGrid.cells(2, cardBannerCell: 0), [null, 0, 1]);
    expect(LiveHubGrid.cells(3), [0, 1, 2]);
  });

  test('HubCardBanners.fromJson: the cell, a bad cell → 4', () {
    final json = {
      'data': [
        {
          'id': 'c1',
          'imageUrl': 'https://media.example.test/c1/720.webp',
          'width': 720,
          'height': 805,
          'blurhash': null,
          'title': null,
          'titleSide': 'RIGHT',
          'link': '/families',
        },
      ],
      'cell': 6,
    };
    final parsed = HubCardBanners.fromJson(json);
    expect(parsed.cell, 6);
    expect(parsed.banners.single.width, 720);
    expect(HubCardBanners.fromJson(const {'data': <Object>[]}).cell, 4);
    expect(
      HubCardBanners.fromJson(const {'data': <Object>[], 'cell': 99}).cell,
      4,
    );
  });

  group('the card-size banner', () {
    for (final language in AppLanguage.values) {
      testWidgets('first cell of the 3rd row, exactly a live card '
          '(${language.name})', (tester) async {
        await _pumpHub(
          tester,
          banners: sampleBanners(),
          cards: sampleCardBanners(count: 1),
          language: language,
        );
        // The carousel (D248b: 5:1) is after the first row.
        final pager = tester.getRect(
          find.byKey(KHomeBannerCarousel.carouselKey),
        );
        expect(
          pager.top,
          greaterThan(
            tester.getRect(find.byKey(LiveHubGrid.cardKey(1))).bottom,
          ),
        );
        expect(
          pager.bottom,
          lessThan(tester.getRect(find.byKey(LiveHubGrid.cardKey(2))).top),
        );
        expect(pager.width / pager.height, moreOrLessEquals(5, epsilon: 0.1));
        await _scrollBy(tester, 300);
        final cell = tester.getRect(find.byKey(LiveHubGrid.cardBannerSlotKey));
        final card2 = tester.getRect(find.byKey(LiveHubGrid.cardKey(2)));
        final card4 = tester.getRect(find.byKey(LiveHubGrid.cardKey(4)));
        // The same size and row rhythm as the cards.
        expect(cell.width, moreOrLessEquals(card2.width));
        expect(cell.height, moreOrLessEquals(card2.height));
        expect(
          cell.width / cell.height,
          moreOrLessEquals(0.894, epsilon: 1e-3),
        );
        expect(cell.top - card2.bottom, moreOrLessEquals(6));
        // The room after it takes the other cell of the row.
        expect(card4.top, cell.top);
        if (language == AppLanguage.ar) {
          // The reading start is the right.
          expect(cell.right, moreOrLessEquals(393 - 13));
          expect(cell.left - card4.right, moreOrLessEquals(7.2));
        } else {
          expect(cell.left, moreOrLessEquals(13));
          expect(card4.left - cell.right, moreOrLessEquals(7.2));
        }
      });
    }

    testWidgets('the cell comes from the server', (tester) async {
      await _pumpHub(tester, cards: sampleCardBanners(count: 1), cell: 1);
      final cell = tester.getRect(find.byKey(LiveHubGrid.cardBannerSlotKey));
      final card0 = tester.getRect(find.byKey(LiveHubGrid.cardKey(0)));
      final card1 = tester.getRect(find.byKey(LiveHubGrid.cardKey(1)));
      expect(cell.top, card0.top);
      expect(cell.left, greaterThan(card0.right));
      // Room 1 moved down to the next row's first cell.
      expect(card1.top, greaterThan(card0.bottom));
    });

    testWidgets('after the last room when there are fewer; hidden with none, '
        'on a failed request and on the empty state', (tester) async {
      await _pumpHub(tester, rooms: 3, cards: sampleCardBanners(count: 1));
      final cell = tester.getRect(find.byKey(LiveHubGrid.cardBannerSlotKey));
      final card2 = tester.getRect(find.byKey(LiveHubGrid.cardKey(2)));
      expect(cell.top, card2.top);

      await _pumpHub(tester);
      expect(find.byKey(LiveHubGrid.cardBannerSlotKey), findsNothing);
      expect(find.byKey(KHubCardBanner.cellKey), findsNothing);

      await _pumpHub(
        tester,
        repo: FakeHomeBannersRepository(
          hubCardBanners: sampleCardBanners(),
          failure: const NetworkFailure.offline(),
        ),
      );
      expect(find.byKey(LiveHubGrid.cardBannerSlotKey), findsNothing);
      expect(find.byType(KLiveGridCard), findsWidgets);

      await _pumpHub(tester, rooms: 0, cards: sampleCardBanners());
      expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
      expect(find.byKey(LiveHubGrid.cardBannerSlotKey), findsNothing);
    });

    testWidgets('several take turns in the one cell every 5 s (a fade); '
        'not with reduce motion', (tester) async {
      await _pumpHub(tester, cards: sampleCardBanners());
      expect(_shownCard(tester), 'card-0');
      await tester.pump(const Duration(milliseconds: 4900));
      expect(_shownCard(tester), 'card-0');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(_shownCard(tester), 'card-1');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(_shownCard(tester), 'card-0');

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(_shownCard(tester), 'card-0');
    });

    testWidgets('a button with the banner label; on every filter', (
      tester,
    ) async {
      await _pumpHub(tester, cards: sampleCardBanners(count: 1));
      final semantics = tester.getSemantics(
        find.byKey(KHubCardBanner.pageKey('card-0')),
      );
      expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
      for (final filter in LiveHubFilter.values) {
        final pill = find.byKey(LiveHubFilterBar.pillKey(filter));
        if (pill.evaluate().isEmpty) continue;
        await tester.tap(pill);
        await tester.pumpAndSettle();
        // Popular opens its menu on a second tap; close it.
        if (find.byType(LiveHubGrid).evaluate().isEmpty &&
            find.byKey(LiveHubGrid.gridKey).evaluate().isEmpty) {
          await tester.tapAt(const Offset(5, 840));
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(LiveHubGrid.cardBannerSlotKey),
          findsOneWidget,
          reason: filter.name,
        );
      }
    });
  });

  group('paging and refresh', () {
    testWidgets('the banners never count as lives: the next page loads at '
        'the end and every room is shown once', (tester) async {
      final live = await _pumpHub(
        tester,
        handler: _paged(2, size: 10),
        banners: sampleBanners(),
        cards: sampleCardBanners(count: 1),
      );
      for (var i = 0; i < 12; i++) {
        await _scrollBy(tester, 2000);
      }
      expect([for (final r in live.requests) r.cursor], [null, 'c1']);
      // 20 rooms + the card banner, rooms numbered 0…19.
      expect(find.byKey(LiveHubGrid.cardKey(19)), findsOneWidget);
      expect(find.byKey(LiveHubGrid.cardKey(20)), findsNothing);
    });

    testWidgets('pull to refresh reloads both banner lists', (tester) async {
      final repo = FakeHomeBannersRepository(
        banners: sampleBanners(),
        hubCardBanners: sampleCardBanners(count: 1),
      );
      await _pumpHub(tester, repo: repo);
      final before = repo.calls;
      expect(before, 2);
      repo.hubCardBanners = const [];
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repo.calls, before + 2);
      expect(find.byKey(LiveHubGrid.cardBannerSlotKey), findsNothing);
      expect(find.byKey(KHomeBannerCarousel.carouselKey), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (viewport, scale, language) in const [
      (GoldenViewport.android, 1.3, AppLanguage.ar),
      (GoldenViewport.android, 1.3, AppLanguage.en),
      (GoldenViewport.phone, 1.3, AppLanguage.ar),
    ]) {
      testWidgets('${viewport.name} at text scale $scale (${language.name}): '
          'no overflow, the cell is a card', (tester) async {
        await loadAppFonts();
        await _pumpHub(
          tester,
          banners: sampleBanners(),
          cards: [
            const HomeBanner(
              id: 'card-t',
              imageUrl: 'https://media.example.test/media/card-t/720.webp',
              width: 720,
              height: 805,
              title: 'A title long enough to need an ellipsis on a card',
              link: '/families',
            ),
          ],
          language: language,
          viewport: viewport,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await _scrollBy(tester, 400);
        expect(tester.takeException(), isNull);
        final cell = tester.getRect(find.byKey(LiveHubGrid.cardBannerSlotKey));
        final card = tester.getRect(find.byKey(LiveHubGrid.cardKey(2)));
        expect(cell.width, moreOrLessEquals(card.width));
        expect(cell.height, moreOrLessEquals(card.height));
      });
    }
  });
}
