// KL-038: the Live hub wired to the v1.3 API — prefetch, footer states,
// categories, freshness (re-select, resume) and honest copy.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_grid.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeLiveRepository live, {
  AppLanguage language = AppLanguage.en,
  bool settle = true,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    const LiveScreen(),
    language: language,
    overrides: liveOverrides(live, language: language),
  );
  // Footer skeletons shimmer forever: those tests pump frames instead.
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(milliseconds: 100));
}

/// [pages] pages of [size] rooms with cursors `c1`, `c2`, ….
RoomsHandler _paged(int pages, {int size = 20}) => (r) {
  final index = r.cursor == null ? 0 : int.parse(r.cursor!.substring(1));
  return apiPage(
    apiRooms(size, start: index * size),
    nextCursor: index + 1 < pages ? 'c${index + 1}' : null,
  );
};

List<String?> _cursors(FakeLiveRepository live) => [
  for (final r in live.requests) r.cursor,
];

/// Scrolls the Popular grid (D124) by [dy] logical pixels.
Future<void> _scrollBy(
  WidgetTester tester,
  double dy, {
  bool settle = true,
}) async {
  await tester.drag(find.byType(CustomScrollView).first, Offset(0, -dy));
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _scrollToEnd(WidgetTester tester, {bool settle = true}) async {
  for (var i = 0; i < 12; i++) {
    await _scrollBy(tester, 2000, settle: settle);
  }
}

Future<void> _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  states.forEach(tester.binding.handleAppLifecycleStateChanged);
  return tester.pumpAndSettle();
}

const List<AppLifecycleState> _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const List<AppLifecycleState> _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  final l10n = l10nFor(AppLanguage.en);

  group('pagination (HL-H5)', () {
    testWidgets('a short first page prefetches the next one by itself', (
      tester,
    ) async {
      // 3 streams: 2 remain after the first, so the next page is fetched.
      final live = FakeLiveRepository(rooms: _paged(2, size: 3));
      await _pump(tester, live);
      expect(_cursors(live), [null, 'c1']);
    });

    testWidgets('a long page prefetches only when 2 screens or less of '
        'cards remain', (tester) async {
      // 40 cards: 20 rows of about 207 dp (D131).
      final live = FakeLiveRepository(rooms: _paged(3, size: 40));
      await _pump(tester, live);
      expect(_cursors(live), [null]);
      await _scrollBy(tester, 600);
      expect(_cursors(live), [null]);
      await _scrollBy(tester, 2600);
      expect(_cursors(live), [null, 'c1']);
    });

    testWidgets('a progress footer under the grid while the next page '
        'loads', (tester) async {
      final live = FakeLiveRepository(
        rooms: (r) => r.cursor == null
            ? apiPage(apiRooms(6), nextCursor: 'c1')
            : Completer<LiveRoomPage>().future,
      );
      await _pump(tester, live, settle: false);
      await tester.pump();
      await _scrollToEnd(tester, settle: false);
      expect(_cursors(live), [null, 'c1']);
      expect(find.byKey(LiveHubGrid.loadingMoreKey), findsOneWidget);
      expect(find.byKey(FeedRegion.loadMoreErrorKey), findsNothing);
    });

    testWidgets('load-more error: inline message + Retry under the grid; '
        'the cards stay', (tester) async {
      var fail = true;
      final live = FakeLiveRepository(
        rooms: (r) {
          if (r.cursor != null && fail) {
            throw const NetworkFailure.offline();
          }
          return _paged(2, size: 10)(r);
        },
      );
      await _pump(tester, live);
      await _scrollToEnd(tester);
      final error = find.byKey(FeedRegion.loadMoreErrorKey);
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: error,
          matching: find.text(l10n.liveHubLoadMoreFailed),
        ),
        findsOneWidget,
      );
      expect(find.byKey(LiveHubGrid.cardKey(9)), findsOneWidget);
      // No automatic retry loop.
      final calls = live.requests.length;
      await _scrollBy(tester, -400);
      await _scrollToEnd(tester);
      expect(live.requests, hasLength(calls));

      fail = false;
      await tester.tap(
        find.descendant(of: error, matching: find.text(l10n.actionRetry)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(FeedRegion.loadMoreErrorKey), findsNothing);
      await _scrollToEnd(tester);
      expect(find.byKey(LiveHubGrid.cardKey(19)), findsOneWidget);
    });

    testWidgets('end of list: no progress footer or error under the grid', (
      tester,
    ) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6)));
      await _pump(tester, live);
      await _scrollToEnd(tester);
      expect(find.byKey(LiveHubGrid.loadingMoreKey), findsNothing);
      expect(find.byKey(FeedRegion.loadMoreErrorKey), findsNothing);
    });

    testWidgets('empty list: no end caption', (tester) async {
      await _pump(tester, FakeLiveRepository());
      expect(find.text(l10n.liveHubEmptyTitle), findsOneWidget);
      expect(find.byKey(FeedRegion.endOfListKey), findsNothing);
    });
  });

  group("categories (HL-H3; D131: in Popular's menu)", () {
    for (final language in AppLanguage.values) {
      testWidgets('Following, All + the server categories; the filter is '
          'sent (${language.name})', (tester) async {
        final ar = language == AppLanguage.ar;
        final live = FakeLiveRepository(
          categories: apiCategories(ar: ar),
          rooms: (_) => apiPage(apiRooms(4, ar: ar)),
        );
        await _pump(tester, live, language: language);
        final popular = find.byKey(
          LiveHubFilterBar.pillKey(LiveHubFilter.popular),
        );
        await tester.tap(popular);
        await tester.pumpAndSettle();
        expect(find.byKey(LiveHubFilterBar.menuFollowingKey), findsOneWidget);
        expect(find.byKey(LiveHubFilterBar.menuAllKey), findsOneWidget);
        for (final c in apiCategories(ar: ar)) {
          expect(
            find.byKey(LiveHubFilterBar.menuCategoryKey(c.slug)),
            findsOneWidget,
          );
        }
        expect(find.text(ar ? 'موسيقى' : 'Music'), findsOneWidget);
        await tester.tap(find.byKey(LiveHubFilterBar.menuCategoryKey('music')));
        await tester.pumpAndSettle();
        expect(live.requests.last.category, 'music');
        expect(live.requests.last.cursor, isNull);
        await tester.tap(popular);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LiveHubFilterBar.menuAllKey));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: popular,
            matching: find.text(l10nFor(language).liveHubFilterPopular),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('no categories: the menu has Following and All only', (
      tester,
    ) async {
      await _pump(tester, FakeLiveRepository());
      await tester.tap(
        find.byKey(LiveHubFilterBar.pillKey(LiveHubFilter.popular)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<Object>), findsNothing);
      expect(find.byKey(LiveHubFilterBar.menuFollowingKey), findsOneWidget);
      expect(find.byKey(LiveHubFilterBar.menuAllKey), findsOneWidget);
      expect(
        find.byKey(LiveHubFilterBar.menuCategoryKey('music')),
        findsNothing,
      );
    });
  });

  group('freshness (HL-H5)', () {
    testWidgets('re-tapping the selected filter re-fetches it (Popular '
        'opens its menu instead)', (tester) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(2)));
      await _pump(tester, live);
      final featured = find.byKey(
        LiveHubFilterBar.pillKey(LiveHubFilter.featured),
      );
      await tester.tap(featured);
      await tester.pumpAndSettle();
      final configs = live.configCalls;
      final lists = live.requests.length;
      await tester.tap(featured);
      await tester.pumpAndSettle();
      expect(live.configCalls, configs + 1);
      expect(live.requests, hasLength(lists + 1));
      expect(live.requests.last.cursor, isNull);
    });

    testWidgets('resume after more than 60 s re-fetches; sooner does not', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 16, 20);
      await withClock(Clock(() => now), () async {
        final live = FakeLiveRepository(hostingEnabled: false);
        await _pump(tester, live);
        expect(find.byKey(const Key('feed.unavailable')), findsOneWidget);
        final calls = live.configCalls;

        await _lifecycle(tester, _toBackground);
        now = now.add(const Duration(seconds: 30));
        await _lifecycle(tester, _toForeground);
        expect(live.configCalls, calls);

        // Hosting was switched on while the app was away for 2 minutes.
        live
          ..hostingEnabled = true
          ..rooms = (_) => apiPage(apiRooms(2));
        await _lifecycle(tester, _toBackground);
        now = now.add(const Duration(minutes: 2));
        await _lifecycle(tester, _toForeground);
        expect(live.configCalls, calls + 1);
        expect(find.byType(KLiveGridCard), findsWidgets);
      });
    });

    testWidgets('pull-to-refresh on unavailable re-checks the config', (
      tester,
    ) async {
      final live = FakeLiveRepository(hostingEnabled: false);
      await _pump(tester, live);
      final calls = live.configCalls;
      await tester.fling(
        find.byKey(const Key('feed.unavailable')),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(live.configCalls, calls + 1);
      expect(live.requests, isEmpty);
    });
  });

  group('grid (D124)', () {
    testWidgets('creator identity and "New" from the API room (D39)', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeLiveRepository(rooms: (_) => apiPage(apiRooms(1))),
      );
      final card = find.byType(KLiveGridCard);
      expect(card, findsOneWidget);
      // D131 (ref 165): the host's name is announced, the title drawn.
      expect(
        find.bySemanticsLabel(RegExp('^Sara, live, New, Arabic music night')),
        findsOneWidget,
      );
      expect(find.text('Arabic music night'), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(l10n.liveCardNew)),
        findsOneWidget,
      );
      // No cover and no avatar in the fixture: the host's initial.
      expect(find.byKey(KLiveGridCard.initialKey), findsOneWidget);
      expect(tester.widget<KLiveGridCard>(card).room.roomId, 'room-0');
    });
  });

  group('errors', () {
    testWidgets('429 on load: compact error with the Retry-After wait', (
      tester,
    ) async {
      final live = FakeLiveRepository()
        ..configFailure = const ServerFailure(
          code: ErrorCode.rateLimited,
          rawCode: 'RATE_LIMITED',
          debugMessage: 'x',
          statusCode: 429,
          retryAfter: Duration(seconds: 30),
        );
      await _pump(tester, live);
      expect(find.text(l10n.liveHubErrorTitle), findsOneWidget);
      expect(find.text(l10n.errorRateLimitedRetryIn('0:30')), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });

    testWidgets('5xx on load: compact error with Error ID', (tester) async {
      final live = FakeLiveRepository()
        ..configFailure = const ServerFailure(
          code: ErrorCode.internalError,
          rawCode: 'INTERNAL_ERROR',
          debugMessage: 'x',
          statusCode: 500,
          requestId: 'req-42',
        );
      await _pump(tester, live);
      expect(find.text(l10n.errorInternal), findsOneWidget);
      expect(find.text(l10n.errorIdLabel('req-42')), findsOneWidget);
    });
  });

  group('honest copy', () {
    Map<String, String> values(String file) {
      final json = jsonDecode(
        File('lib/l10n/$file').readAsStringSync(),
      ) as Map<String, Object?>;
      return {
        for (final e in json.entries)
          if (!e.key.startsWith('@')) e.key: '${e.value}',
      };
    }

    // KL-047: every string family the Home and Live screens render (tabs,
    // states, actions, cards, badges, nav, retry and error copy), not only
    // the home*/liveHub* keys. Rendered text is also checked state by state
    // in test/features/home_live/kl047_polish_test.dart.
    // KL-034 adds the live room: every live*, gift*, pk*, chat* and
    // multiGuest* string (room states, sheets, PK, seats); its rendered text
    // is checked state by state in live_room_test.dart.
    test('Home, Live and live room copy has no development phases', () {
      const prefixes = [
        'home',
        'live',
        'feed',
        'gift',
        'pk',
        'chat',
        'multiGuest',
        'compact',
        'nav',
        'actionRetry',
        'error',
      ];
      final phase = RegExp('phase|المرحلة|مرحلة', caseSensitive: false);
      var checked = 0;
      for (final file in ['app_en.arb', 'app_ar.arb']) {
        for (final MapEntry(:key, :value) in values(file).entries) {
          if (!prefixes.any(key.startsWith)) continue;
          checked++;
          expect(value, isNot(contains(phase)), reason: '$file $key');
        }
      }
      expect(checked, greaterThan(150));
    });

    test('the three v1.3 live codes have their own messages', () {
      for (final language in AppLanguage.values) {
        final l = l10nFor(language);
        final messages = {
          l.errorLiveHostingUnavailable,
          l.errorLiveRoomAlreadyActive,
          l.errorLiveRoomEnded,
        };
        expect(messages, hasLength(3));
        expect(messages, isNot(contains(l.errorUnknown)));
      }
    });
  });
}
