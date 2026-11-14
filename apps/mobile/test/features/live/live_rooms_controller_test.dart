// KL-038: the Live hub pagination controller (HL-H3–H6, CONVENTIONS §5 and
// §10.4) against a fake repository, and the production-honesty guard.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_repository.dart';

const _badCursor = ServerFailure(
  code: ErrorCode.validationFailed,
  rawCode: 'VALIDATION_FAILED',
  debugMessage: 'bad cursor',
  statusCode: 400,
  details: [FieldIssue(field: 'cursor', issue: 'invalid_value')],
);

void main() {
  late FakeLiveRepository repo;
  late ProviderContainer container;

  ProviderContainer make({AppLanguage language = AppLanguage.en}) =>
      ProviderContainer.test(
        retry: (_, _) => null,
        overrides: liveOverrides(repo, language: language),
      );

  /// A tab as a query (video lives, no filter), or [query] itself.
  LiveRoomsQuery q(Object tab) =>
      tab is LiveRoomsQuery ? tab : LiveRoomsQuery(tab: tab as FeedTab);

  Future<LiveHubState> load(Object tab) async {
    final sub = container.listen(liveRoomsProvider(q(tab)), (_, _) {});
    addTearDown(sub.close);
    return await container.read(liveRoomsProvider(q(tab)).future);
  }

  LiveRoomsController controller(Object tab) =>
      container.read(liveRoomsProvider(q(tab)).notifier);

  LiveHubState state(Object tab) =>
      container.read(liveRoomsProvider(q(tab))).requireValue;

  List<String> ids(Object tab) => [for (final r in state(tab).rooms) r.id];

  setUp(() {
    repo = FakeLiveRepository();
    container = make();
  });

  group('hosting switch (GET /live/config)', () {
    test('hosting disabled: unavailable, and no list calls at all', () async {
      repo.hostingEnabled = false;
      for (final tab in FeedTab.values) {
        final s = await load(tab);
        expect(s.hostingEnabled, isFalse);
        expect(s.rooms, isEmpty);
        expect(
          liveHubContent(AsyncData(s)).value,
          isA<FeedUnavailable<LiveRoomCardData>>(),
        );
      }
      expect(repo.requests, isEmpty);
    });

    test('refresh re-checks the config and picks up a switch', () async {
      repo.hostingEnabled = false;
      await load(FeedTab.popular);
      repo
        ..hostingEnabled = true
        ..rooms = (_) => apiPage(apiRooms(3));
      await controller(FeedTab.popular).refresh();
      expect(state(FeedTab.popular).hostingEnabled, isTrue);
      expect(ids(FeedTab.popular), ['room-0', 'room-1', 'room-2']);
      expect(repo.configCalls, 2);
    });

    test('a failing refresh keeps what is shown and rethrows', () async {
      repo.rooms = (_) => apiPage(apiRooms(2));
      await load(FeedTab.latest);
      repo.configFailure = const NetworkFailure.offline();
      await expectLater(
        controller(FeedTab.latest).refresh(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(ids(FeedTab.latest), ['room-0', 'room-1']);
    });
  });

  group('filters (D131, D133)', () {
    test('every call carries the query: tab, kind, category, nearby, '
        'featured; the next pages keep them', () async {
      repo.rooms = (r) => apiPage(apiRooms(2), nextCursor: r.cursor ?? 'c1');
      const query = LiveRoomsQuery(
        tab: FeedTab.popular,
        category: 'music',
        nearby: true,
      );
      await load(query);
      await controller(query).loadMore();
      for (final r in repo.requests) {
        expect(r.tab, LiveRoomsTab.popular);
        expect(r.kind, LiveRoomsKind.video);
        expect(r.category, 'music');
        expect(r.nearby, isTrue);
        expect(r.featured, isFalse);
      }
      expect(repo.requests.last.cursor, 'c1');

      repo.requests.clear();
      const voice = LiveRoomsQuery(
        tab: FeedTab.latest,
        kind: LiveRoomsKind.audio,
        featured: true,
      );
      await load(voice);
      final r = repo.requests.single;
      expect(r.tab, LiveRoomsTab.latest);
      expect(r.kind, LiveRoomsKind.audio);
      expect(r.featured, isTrue);
      expect(r.nearby, isFalse);
      expect(r.category, isNull);
    });

    test('two queries are two lists; equal queries share one', () async {
      repo.rooms = (r) => apiPage(apiRooms(1, start: r.featured ? 9 : 0));
      await load(FeedTab.popular);
      await load(const LiveRoomsQuery(tab: FeedTab.popular, featured: true));
      expect(ids(FeedTab.popular), ['room-0']);
      expect(ids(const LiveRoomsQuery(tab: FeedTab.popular, featured: true)), [
        'room-9',
      ]);
      final calls = repo.requests.length;
      await load(const LiveRoomsQuery(tab: FeedTab.popular));
      expect(repo.requests, hasLength(calls));
    });

    test('Nearby without a country: COUNTRY_NOT_SET is kept on the state '
        '(the list asks for a country); otherwise false', () async {
      repo.rooms = (r) => r.nearby
          ? const LiveRoomPage(
              data: [],
              page: PageInfo(nextCursor: null, hasMore: false),
              emptyReason: LiveRoomsEmptyReason.countryNotSet,
            )
          : apiPage(apiRooms(1));
      const nearby = LiveRoomsQuery(tab: FeedTab.popular, nearby: true);
      final s = await load(nearby);
      expect(s.countryNotSet, isTrue);
      expect(s.rooms, isEmpty);
      expect((await load(FeedTab.popular)).countryNotSet, isFalse);
    });

    test('an unknown emptyReason reads as none', () {
      final page = LiveRoomPage.fromJson({
        'data': <Object?>[],
        'page': {'nextCursor': null, 'hasMore': false},
        'emptyReason': 'SOMETHING_NEW',
      });
      expect(page.emptyReason, isNull);
      expect(
        LiveRoomPage.fromJson({
          'data': <Object?>[],
          'page': {'nextCursor': null, 'hasMore': false},
          'emptyReason': 'COUNTRY_NOT_SET',
        }).emptyReason,
        LiveRoomsEmptyReason.countryNotSet,
      );
    });

    test('a failed first page is an error; retry reloads it', () async {
      repo.rooms = (_) => throw const NetworkFailure.timeout();
      const query = LiveRoomsQuery(tab: FeedTab.popular, category: 'games');
      final sub = container.listen(liveRoomsProvider(query), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(liveRoomsProvider(query).future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(
        liveHubContent(container.read(liveRoomsProvider(query))).error,
        isA<NetworkFailure>(),
      );
      repo.rooms = (_) => apiPage(apiRooms(1));
      controller(query).retry();
      expect(await container.read(liveRoomsProvider(query).future), isNotNull);
      expect(ids(query), ['room-0']);
      expect(repo.requests.last.category, 'games');
    });

    test('the categories come from their own call, localized; a locale '
        'change refetches them and the rooms', () async {
      repo.categories = apiCategories();
      expect(
        await container.read(liveDiscoveryCategoriesProvider.future),
        apiCategories(),
      );
      await load(FeedTab.popular);
      final calls = repo.categoryCalls;
      final rooms = repo.requests.length;
      container.updateOverrides(liveOverrides(repo, language: AppLanguage.ar));
      await container.read(liveDiscoveryCategoriesProvider.future);
      await container.read(liveRoomsProvider(q(FeedTab.popular)).future);
      expect(repo.categoryCalls, calls + 1);
      expect(repo.requests.length, rooms + 1);
    });
  });

  group('pagination (HL-H5)', () {
    /// Pages of 20 with cursors `c1`, `c2`, …; [pages] pages in total.
    void paged(int pages, {int overlap = 0}) {
      repo.rooms = (r) {
        final index = r.cursor == null ? 0 : int.parse(r.cursor!.substring(1));
        final start = index * 20 - (index == 0 ? 0 : overlap);
        return apiPage(
          apiRooms(20, start: start),
          nextCursor: index + 1 < pages ? 'c${index + 1}' : null,
        );
      };
    }

    test('first page from no cursor, limit 20; next pages append', () async {
      paged(3);
      await load(FeedTab.latest);
      expect(repo.requests.single.cursor, isNull);
      expect(repo.requests.single.limit, 20);
      expect(repo.requests.single.tab, LiveRoomsTab.latest);
      expect(state(FeedTab.latest).hasMore, isTrue);

      await controller(FeedTab.latest).loadMore();
      expect(repo.requests.last.cursor, 'c1');
      expect(state(FeedTab.latest).rooms, hasLength(40));
      await controller(FeedTab.latest).loadMore();
      expect(state(FeedTab.latest).rooms, hasLength(60));
      expect(state(FeedTab.latest).hasMore, isFalse);

      // End of list: further calls do nothing.
      final calls = repo.requests.length;
      await controller(FeedTab.latest).loadMore();
      expect(repo.requests, hasLength(calls));
    });

    test('dedupes rooms by id across pages (ranking drift)', () async {
      paged(2, overlap: 5);
      await load(FeedTab.popular);
      await controller(FeedTab.popular).loadMore();
      final all = ids(FeedTab.popular);
      expect(all, hasLength(35));
      expect(all.toSet(), hasLength(35));
      expect(all.first, 'room-0');
      expect(all.last, 'room-34');
    });

    test('loadingMore while in flight; concurrent calls are ignored', () async {
      paged(3);
      await load(FeedTab.popular);
      final gate = Completer<void>();
      final inner = repo.rooms;
      repo.rooms = (r) async {
        await gate.future;
        return await inner(r);
      };
      final first = controller(FeedTab.popular).loadMore();
      expect(state(FeedTab.popular).loadingMore, isTrue);
      final content = liveHubContent(
        container.read(liveRoomsProvider(q(FeedTab.popular))),
      ).requireValue;
      expect((content as FeedItems).loadingMore, isTrue);
      await controller(FeedTab.popular).loadMore();
      gate.complete();
      await first;
      expect(repo.requests.where((r) => r.cursor == 'c1'), hasLength(1));
      expect(state(FeedTab.popular).loadingMore, isFalse);
    });

    test('footer error keeps the list; retry loads the page', () async {
      paged(2);
      await load(FeedTab.popular);
      final ok = repo.rooms;
      repo.rooms = (r) => r.cursor == null
          ? ok(r)
          : throw const ServerFailure(
              code: ErrorCode.rateLimited,
              rawCode: 'RATE_LIMITED',
              debugMessage: 'x',
              retryAfter: Duration(seconds: 30),
            );
      await controller(FeedTab.popular).loadMore();
      final s = state(FeedTab.popular);
      expect(s.rooms, hasLength(20));
      expect(s.loadMoreError, isA<ServerFailure>());
      expect(s.canLoadMore, isFalse);

      // Prefetch does not retry on its own.
      final calls = repo.requests.length;
      await controller(FeedTab.popular).loadMore();
      expect(repo.requests, hasLength(calls));

      repo.rooms = ok;
      await controller(FeedTab.popular).retryLoadMore();
      expect(state(FeedTab.popular).rooms, hasLength(40));
      expect(state(FeedTab.popular).loadMoreError, isNull);
    });

    test('refresh resets to the first page', () async {
      paged(3);
      await load(FeedTab.popular);
      await controller(FeedTab.popular).loadMore();
      expect(state(FeedTab.popular).rooms, hasLength(40));
      await controller(FeedTab.popular).refresh();
      expect(state(FeedTab.popular).rooms, hasLength(20));
      expect(state(FeedTab.popular).nextCursor, 'c1');
      expect(repo.requests.last.cursor, isNull);
    });

    test('bad cursor: restart from the first page once', () async {
      paged(3);
      await load(FeedTab.popular);
      await controller(FeedTab.popular).loadMore(); // 40 rooms, cursor c2
      final ok = repo.rooms;
      repo.rooms = (r) => r.cursor == null ? ok(r) : throw _badCursor;
      await controller(FeedTab.popular).loadMore();
      // Restarted: the first page replaces the list, no error shown.
      expect(repo.requests.last.cursor, isNull);
      expect(state(FeedTab.popular).rooms, hasLength(20));
      expect(state(FeedTab.popular).loadMoreError, isNull);

      // Rejected again right away: no loop, the footer error shows.
      final calls = repo.requests.length;
      await controller(FeedTab.popular).loadMore();
      expect(repo.requests, hasLength(calls + 1));
      expect(state(FeedTab.popular).loadMoreError, _badCursor);

      // After a successful page, a later bad cursor restarts again.
      repo.rooms = ok;
      await controller(FeedTab.popular).retryLoadMore();
      expect(state(FeedTab.popular).rooms, hasLength(40));
      repo.rooms = (r) => r.cursor == null ? ok(r) : throw _badCursor;
      await controller(FeedTab.popular).loadMore();
      expect(state(FeedTab.popular).loadMoreError, isNull);
      expect(repo.requests.last.cursor, isNull);
    });

    test('a late page from before a refresh is dropped', () async {
      paged(3);
      await load(FeedTab.popular);
      final gate = Completer<void>();
      final ok = repo.rooms;
      repo.rooms = (r) async {
        if (r.cursor != null) await gate.future;
        return await ok(r);
      };
      final more = controller(FeedTab.popular).loadMore();
      await controller(FeedTab.popular).refresh();
      gate.complete();
      await more;
      expect(state(FeedTab.popular).rooms, hasLength(20));
    });
  });

  group('production never shows fixture data (D35/D37)', () {
    test('rooms come only from the repository', () async {
      // Hosting on, nobody live: every tab is honestly empty.
      for (final tab in FeedTab.values) {
        final s = await load(tab);
        expect(s.hostingEnabled, isTrue);
        expect(s.rooms, isEmpty);
        final content = liveHubContent(AsyncData(s)).requireValue;
        expect((content as FeedItems<LiveRoomCardData>).items, isEmpty);
      }
    });

    test('cards mirror the API room: no invented counts or covers', () async {
      repo.rooms = (_) => apiPage(apiRooms(1));
      final s = await load(FeedTab.popular);
      final content = liveHubContent(AsyncData(s)).requireValue;
      final card = (content as FeedItems<LiveRoomCardData>).items.single;
      expect(card.hostName, 'Sara');
      expect(card.title, 'Arabic music night');
      expect(card.viewerCount, 0);
      expect(card.cover, isNull);
      expect(card.hostAvatar, isNull);
      expect(card.inPk, isFalse);
      expect(card.guestCount, isNull);
    });
  });
}
