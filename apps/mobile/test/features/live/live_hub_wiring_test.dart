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
import 'package:kabso_live/features/live/presentation/widgets/live_cover_card.dart';
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

Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(KLiveCoverCard).first, const Offset(0, -6000));
  await tester.pumpAndSettle();
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
      final live = FakeLiveRepository(rooms: _paged(2, size: 4));
      await _pump(tester, live);
      expect(_cursors(live), [null, 'c1']);
    });

    testWidgets('a long page prefetches only within 2 viewport heights', (
      tester,
    ) async {
      final live = FakeLiveRepository(rooms: _paged(3));
      await _pump(tester, live);
      // 20 rooms = 10 rows ≈ 2,530 dp: more than 2 viewports remain.
      expect(_cursors(live), [null]);
      await tester.drag(
        find.byType(KLiveCoverCard).first,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(_cursors(live), [null, 'c1']);
    });

    testWidgets('footer: 2 skeleton cards while the next page loads', (
      tester,
    ) async {
      final live = FakeLiveRepository(
        rooms: (r) => r.cursor == null
            ? apiPage(apiRooms(6), nextCursor: 'c1')
            : Completer<LiveRoomPage>().future,
      );
      await _pump(tester, live, settle: false);
      await tester.pump();
      await tester.drag(
        find.byType(KLiveCoverCard).first,
        const Offset(0, -6000),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_cursors(live), [null, 'c1']);
      expect(find.byType(KLiveCoverCardSkeleton), findsNWidgets(2));
      expect(find.byKey(FeedRegion.endOfListKey), findsNothing);
    });

    testWidgets('footer error: inline message + Retry; list stays', (
      tester,
    ) async {
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
      final error = find.byKey(FeedRegion.loadMoreErrorKey);
      expect(error, findsOneWidget);
      expect(
        find.descendant(
          of: error,
          matching: find.text(l10n.liveHubLoadMoreFailed),
        ),
        findsOneWidget,
      );
      expect(find.byType(KLiveCoverCard), findsNWidgets(6));
      // No automatic retry loop.
      final calls = live.requests.length;
      await _scrollToEnd(tester);
      expect(live.requests, hasLength(calls));

      fail = false;
      await tester.tap(
        find.descendant(of: error, matching: find.text(l10n.actionRetry)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(FeedRegion.loadMoreErrorKey), findsNothing);
      await _scrollToEnd(tester);
      expect(find.byKey(FeedRegion.endOfListKey), findsOneWidget);
    });

    testWidgets('end of list: the caption, no "all caught up"', (tester) async {
      final live = FakeLiveRepository(rooms: (_) => apiPage(apiRooms(6)));
      await _pump(tester, live);
      await _scrollToEnd(tester);
      expect(find.text(l10n.liveHubListEnd), findsOneWidget);
      expect(find.byType(KLiveCoverCardSkeleton), findsNothing);
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
        expect(find.byType(KLiveCoverCard), findsNWidgets(2));
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

  group('cards', () {
    testWidgets('not interactive until the room screen exists', (tester) async {
      await _pump(
        tester,
        FakeLiveRepository(rooms: (_) => apiPage(apiRooms(2))),
      );
      final card = find.byType(KLiveCoverCard).first;
      expect(
        find.descendant(of: card, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        tester.getSemantics(card).getSemanticsData().flagsCollection.isButton,
        isFalse,
      );
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
      // No cover in v1.3: the host avatar fallback with initials.
      expect(
        find.descendant(
          of: find.byType(KLiveCoverCard),
          matching: find.byType(KAvatar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(KLiveCoverCard),
          matching: find.text(l10n.liveCardNew),
        ),
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

    test('Home and Live hub copy has no stale phase numbers', () {
      for (final file in ['app_en.arb', 'app_ar.arb']) {
        for (final MapEntry(:key, :value) in values(file).entries) {
          if (!key.startsWith('home') && !key.startsWith('liveHub')) continue;
          expect(value, isNot(contains('Phase')), reason: '$file $key');
          expect(value, isNot(contains('المرحلة')), reason: '$file $key');
        }
      }
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
