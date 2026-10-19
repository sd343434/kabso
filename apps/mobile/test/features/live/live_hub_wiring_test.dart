// KL-038: the Live hub wired to the v1.3 API — prefetch, footer states,
// categories, freshness (re-select, resume) and honest copy.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_full_page.dart';
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

/// The Popular tab's full-screen pager (D50).
PageController _pager(WidgetTester tester) => tester
    .widget<PageView>(
      find.byKey(const PageStorageKey<String>('live.pager.popular')),
    )
    .controller!;

Future<void> _goToPage(
  WidgetTester tester,
  int page, {
  bool settle = true,
}) async {
  _pager(tester).jumpToPage(page);
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final pager = _pager(tester);
  await _goToPage(tester, 1000);
  expect(pager.page, isNotNull);
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

    testWidgets('a long page prefetches only when 2 streams or fewer '
        'remain', (tester) async {
      final live = FakeLiveRepository(rooms: _paged(3));
      await _pump(tester, live);
      expect(_cursors(live), [null]);
      await _goToPage(tester, 16);
      expect(_cursors(live), [null]);
      await _goToPage(tester, 17);
      expect(_cursors(live), [null, 'c1']);
    });

    testWidgets('the last stream shows a progress line while the next page '
        'loads', (tester) async {
      final live = FakeLiveRepository(
        rooms: (r) => r.cursor == null
            ? apiPage(apiRooms(6), nextCursor: 'c1')
            : Completer<LiveRoomPage>().future,
      );
      await _pump(tester, live, settle: false);
      await tester.pump();
      await _goToPage(tester, 5, settle: false);
      expect(_cursors(live), [null, 'c1']);
      expect(find.byKey(LiveHubPager.loadingMoreKey), findsOneWidget);
      expect(find.byKey(LiveHubPager.loadMoreErrorKey), findsNothing);
    });

    testWidgets('load-more error: inline message + Retry on the last stream; '
        'the streams stay', (tester) async {
      var fail = true;
      final live = FakeLiveRepository(
        rooms: (r) {
          if (r.cursor != null && fail) {
            throw const NetworkFailure.offline();
          }
          return _paged(2, size: 6)(r);
        },
      );
      await _pump(tester, live);
      await _scrollToEnd(tester);
      final error = find.byKey(LiveHubPager.loadMoreErrorKey);
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: error,
          matching: find.text(l10n.liveHubLoadMoreFailed),
        ),
        findsOneWidget,
      );
      expect(_pager(tester).page, 5);
      // No automatic retry loop.
      final calls = live.requests.length;
      await _goToPage(tester, 4);
      await _scrollToEnd(tester);
      expect(live.requests, hasLength(calls));

      fail = false;
      await tester.tap(
        find.descendant(of: error, matching: find.text(l10n.actionRetry)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(LiveHubPager.loadMoreErrorKey), findsNothing);
      await _scrollToEnd(tester);
      expect(_pager(tester).page, 11);
    });

    testWidgets('end of list: no progress line or error on the last stream', (
      tester,
    ) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6)));
      await _pump(tester, live);
      await _scrollToEnd(tester);
      expect(find.byKey(LiveHubPager.loadingMoreKey), findsNothing);
      expect(find.byKey(LiveHubPager.loadMoreErrorKey), findsNothing);
    });

    testWidgets('empty list: no end caption', (tester) async {
      await _pump(tester, FakeLiveRepository());
      expect(find.text(l10n.liveHubEmptyTitle), findsOneWidget);
      expect(find.byKey(FeedRegion.endOfListKey), findsNothing);
    });
  });

  group('categories (HL-H3)', () {
    for (final language in AppLanguage.values) {
      testWidgets('All + server chips, interactive, filter sent '
          '(${language.name})', (tester) async {
        final ar = language == AppLanguage.ar;
        final live = FakeLiveRepository(
          categories: apiCategories(ar: ar),
          rooms: (_) => apiPage(apiRooms(4, ar: ar)),
        );
        await _pump(tester, live, language: language);
        final chips = find.byType(KChip);
        expect(chips, findsNWidgets(4));
        expect(
          find.descendant(of: chips, matching: find.byType(InkWell)),
          findsNWidgets(4),
        );
        final all = find.byKey(const ValueKey('live.chip.all'));
        final music = find.byKey(const ValueKey('live.chip.music'));
        // The row starts at the reading start (RTL: from the right).
        if (ar) {
          expect(
            tester.getCenter(all).dx,
            greaterThan(tester.getCenter(music).dx),
          );
        } else {
          expect(
            tester.getCenter(all).dx,
            lessThan(tester.getCenter(music).dx),
          );
        }
        expect(find.text(ar ? 'موسيقى' : 'Music'), findsOneWidget);

        await tester.tap(music);
        await tester.pumpAndSettle();
        expect(live.requests.last.category, 'music');
        expect(live.requests.last.cursor, isNull);
        bool selected(Finder f) =>
            tester
                .getSemantics(f)
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue;
        expect(selected(music), isTrue);
        expect(selected(all), isFalse);

        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(live.requests.last.category, isNull);
      });
    }

    testWidgets('no categories: a single non-interactive All', (tester) async {
      await _pump(tester, FakeLiveRepository());
      expect(find.byType(KChip), findsOneWidget);
      expect(
        find.descendant(of: find.byType(KChip), matching: find.byType(InkWell)),
        findsNothing,
      );
    });
  });

  group('freshness (HL-H5)', () {
    testWidgets('re-tapping the selected tab re-fetches it', (tester) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(2)));
      await _pump(tester, live);
      final configs = live.configCalls;
      final lists = live.requests.length;
      await tester.tap(
        find.descendant(
          of: find.byType(KPrimaryTabs),
          matching: find.text(l10n.feedTabPopular),
        ),
      );
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
        expect(find.byType(KLiveFullPage), findsWidgets);
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

  group('full-screen streams (D50)', () {
    testWidgets('one stream fills the screen under the floating tabs; it '
        'and "Join live" open its room', (tester) async {
      await _pump(
        tester,
        FakeLiveRepository(rooms: (_) => apiPage(apiRooms(2))),
      );
      final page = find.byType(KLiveFullPage).first;
      expect(tester.getRect(page), const Rect.fromLTWH(0, 0, 393, 852));
      final tabs = tester.getRect(find.byType(KPrimaryTabs));
      expect(tabs.top, greaterThanOrEqualTo(0));
      expect(tabs.overlaps(tester.getRect(page)), isTrue);
      // Badges sit below the tabs and the category row.
      expect(
        tester.getRect(find.byKey(KLiveFullPage.badgesKey).first).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(KChipRow)).bottom),
      );
      expect(
        find.descendant(
          of: page,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.button ?? false),
          ),
        ),
        findsWidgets,
      );
      expect(find.byKey(KLiveFullPage.joinKey), findsOneWidget);
      // The page carries the API room id (the route is tested in
      // live_room_test.dart).
      expect(tester.widget<KLiveFullPage>(page).room.roomId, 'room-0');
    });

    testWidgets('swiping up shows the next stream', (tester) async {
      await _pump(
        tester,
        FakeLiveRepository(rooms: (_) => apiPage(apiRooms(3))),
      );
      expect(find.text('Sara'), findsOneWidget);
      await tester.fling(
        find.byType(KLiveFullPage).first,
        const Offset(0, -500),
        2000,
      );
      await tester.pumpAndSettle();
      expect(_pager(tester).page, 1);
      expect(find.text('Sara'), findsNothing);
    });

    testWidgets('creator identity and "New" from the API room (D39)', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeLiveRepository(rooms: (_) => apiPage(apiRooms(1))),
      );
      expect(find.text('Sara'), findsOneWidget); // host displayName
      expect(find.text('Arabic music night'), findsOneWidget);
      final page = find.byType(KLiveFullPage);
      // No cover in v1.3: the host's large avatar (and the small one).
      expect(
        find.descendant(of: page, matching: find.byType(KAvatar)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: page, matching: find.text(l10n.liveCardNew)),
        findsOneWidget,
      );
      expect(find.byType(KViewerCountChip), findsNothing);
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
