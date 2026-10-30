// D121: the follower and following lists — the repository against the
// contract, the screen's two tabs, paging, pull to refresh, Follow /
// Following / Follow back with optimistic update and rollback, the private
// (403) and unavailable (404) states, the way in from a profile's counts,
// Arabic RTL and English LTR, 360×800 and text scale 2.
// D125 (restyle after the owner's reference): the header (back, username,
// add people → Discover), the tabs with counts, the debounced server-side
// search (`q`), the sort row (`order`), Message + ⋯ (unfollow, remove
// follower, report, block) on your own lists, ⋯ (report, block) on others'.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/follows/data/follow_lists_repository.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/follows/presentation/follow_lists_screen.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _base = '/api/v1';

FollowListItem _person(
  int i, {
  bool followedByMe = false,
  bool followsMe = false,
  bool isPrivate = false,
  bool isSelf = false,
  bool requestedByMe = false,
  String? name,
}) => FollowListItem(
  id: 'u$i',
  username: 'user$i',
  displayName: name ?? 'Person $i',
  avatarUrl: null,
  isSelf: isSelf,
  isPrivate: isPrivate,
  followedByMe: followedByMe,
  followsMe: followsMe,
  requestedByMe: requestedByMe,
);

AppFailure _server(ErrorCode code, String raw) =>
    ServerFailure(code: code, rawCode: raw, debugMessage: raw);

/// In-memory lists, served [pageSize] at a time; every call is recorded as
/// `followers user0` or `following user0 c20` (D125: plus ` q=…` and
/// ` oldest`); removing a follower as `REMOVE user1`.
class _FakeLists implements FollowListsRepository {
  new({this.followers = const [], this.following = const []});

  /// The server's default `limit` (§5).
  static const int pageSize = 20;

  List<FollowListItem> followers;
  List<FollowListItem> following;
  AppFailure? failure;
  final List<String> calls = [];

  @override
  Future<PageOf<FollowListItem>> list(
    String username,
    FollowListKind kind, {
    String? cursor,
    String? query,
    FollowListOrder order = FollowListOrder.newest,
  }) async {
    calls.add(
      '${kind.path} $username'
      '${cursor == null ? '' : ' $cursor'}'
      '${query == null ? '' : ' q=$query'}'
      '${order == FollowListOrder.newest ? '' : ' ${order.wire}'}',
    );
    if (failure case final f?) throw f;
    final q = query?.toLowerCase() ?? '';
    final source = kind == FollowListKind.followers ? followers : following;
    final all = [
      for (final u
          in order == FollowListOrder.newest ? source : source.reversed)
        if (u.username.startsWith(q) ||
            u.displayName.toLowerCase().startsWith(q))
          u,
    ];
    final start = cursor == null ? 0 : int.parse(cursor.substring(1));
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? 'c$end' : null, hasMore: more),
    );
  }

  @override
  Future<int> removeFollower(String username) async {
    calls.add('REMOVE $username');
    if (failure case final f?) throw f;
    followers = [
      for (final u in followers)
        if (u.username != username) u,
    ];
    return followers.length;
  }
}

/// Follow / unfollow by username, with an optional [gate] and [failure].
class _FakeProfiles implements ProfileRepository {
  new([PublicProfile? profile]) : profile = profile ?? apiProfile();

  PublicProfile profile;
  Completer<void>? gate;
  AppFailure? failure;
  final List<String> calls = [];

  /// D175: usernames whose follow is a request (private accounts).
  final Set<String> private = {};

  @override
  Future<PublicProfile> getProfile(String username) async {
    calls.add('GET $username');
    return profile;
  }

  Future<FollowState> _edge(String verb, String username, bool to) async {
    calls.add('$verb $username');
    await gate?.future;
    if (failure case final f?) throw f;
    // D175: the row's account answers as a private one when [private].
    if (to && private.contains(username)) {
      return const FollowState(
        isFollowing: false,
        isRequested: true,
        followerCount: 1,
      );
    }
    return FollowState(isFollowing: to, followerCount: 1);
  }

  @override
  Future<FollowState> follow(String username) => _edge('PUT', username, true);

  @override
  Future<FollowState> unfollow(String username) =>
      _edge('DELETE', username, false);
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeLists lists,
  _FakeProfiles? profiles,
  String initial = '/users/user0/follows',
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  List<Override> extra = const [],
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: AppRoutes.userFollowsPattern,
        builder: (_, s) => FollowListsScreen(
          username: s.pathParameters['username']!,
          initial: FollowListKind.parse(s.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: AppRoutes.userProfilePattern,
        builder: (_, s) =>
            PublicProfileScreen(username: s.pathParameters['username']!),
      ),
      GoRoute(path: '/me', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: AppRoutes.chatPattern,
        builder: (_, s) => Text('chat ${s.pathParameters['username']}'),
      ),
      GoRoute(
        path: AppRoutes.discover,
        builder: (_, _) => const Text('discover'),
      ),
    ],
  );
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        followListsRepositoryProvider.overrideWithValue(lists),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? _FakeProfiles(),
        ),
        profileGridProvider.overrideWith((ref, _) => const FeedItems([])),
        ...extra,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(String username) => find.byKey(FollowListView.rowKey(username));
Finder _button(String username) =>
    find.byKey(FollowListView.buttonKey(username));
String _buttonText(WidgetTester tester, String username) => tester
    .widget<Text>(
      find.descendant(of: _button(username), matching: find.byType(Text)),
    )
    .data!;

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('repository (contract)', () {
    late FakeHttpAdapter http;
    late FollowListsRepositoryImpl repo;

    setUp(() {
      http = FakeHttpAdapter();
      repo = FollowListsRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
    });

    test('GET /users/{username}/followers|following with the cursor; '
        'FollowListItem parsed', () async {
      http
        ..on(
          'GET',
          '$_base/users/sara.k/followers',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'id': '2b5c7d3e-8f41-4c2a-9e6b-1d0f3a7c5e92',
                  'username': 'omar.live',
                  'displayName': 'عمر',
                  'avatarUrl': null,
                  'isSelf': false,
                  'isPrivate': true,
                  'followedByMe': true,
                  'followsMe': true,
                },
              ],
              'page': {'nextCursor': 'next-1', 'hasMore': true},
            },
          ),
        )
        ..on(
          'GET',
          '$_base/users/sara.k/following',
          (_) => const FakeResponse(
            200,
            body: {
              'data': <Object>[],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        );
      final page = await repo.list('sara.k', FollowListKind.followers);
      expect(page.next, 'next-1');
      final u = page.items.single;
      expect(u.username, 'omar.live');
      expect(u.name, 'عمر');
      expect(
        (u.isPrivate, u.followedByMe, u.followsMe, u.isSelf),
        (true, true, true, false),
      );
      expect(u.canToggle, isTrue);
      final more = await repo.list(
        'sara.k',
        FollowListKind.following,
        cursor: 'next-1',
      );
      expect(more.items, isEmpty);
      expect(more.next, isNull);
      expect(http.requests.first.uri.queryParameters, isEmpty);
      expect(http.requests.last.uri.queryParameters, {'cursor': 'next-1'});
    });

    test('D125: q (trimmed) and order=oldest are sent; the default order '
        'and an empty search are left out; DELETE /me/followers/{username} '
        'returns the follower count', () async {
      final page = {
        'data': <Object>[],
        'page': {'nextCursor': null, 'hasMore': false},
      };
      http
        ..on(
          'GET',
          '$_base/users/sara.k/following',
          (_) => FakeResponse(200, body: page),
        )
        ..on(
          'DELETE',
          '$_base/me/followers/omar.live',
          (_) => const FakeResponse(
            200,
            body: {'followsMe': false, 'followerCount': 41},
          ),
        );
      await repo.list(
        'sara.k',
        FollowListKind.following,
        query: '  om ',
        order: FollowListOrder.oldest,
        cursor: 'c1',
      );
      await repo.list('sara.k', FollowListKind.following, query: '   ');
      expect(http.requests.first.uri.queryParameters, {
        'cursor': 'c1',
        'q': 'om',
        'order': 'oldest',
      });
      expect(http.requests[1].uri.queryParameters, isEmpty);
      expect(await repo.removeFollower('omar.live'), 41);
      expect(http.requests.last.method, 'DELETE');
    });

    test(
      '404 (unknown or blocked) and 403 (private) map to failures',
      () async {
        http
          ..on(
            'GET',
            '$_base/users/gone/followers',
            (_) => FakeResponse(404, body: errorEnvelope('NOT_FOUND', 'x')),
          )
          ..on(
            'GET',
            '$_base/users/priv/following',
            (_) =>
                FakeResponse(403, body: errorEnvelope('AUTH_FORBIDDEN', 'x')),
          );
        await expectLater(
          repo.list('gone', FollowListKind.followers),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.code,
              'code',
              ErrorCode.notFound,
            ),
          ),
        );
        await expectLater(
          repo.list('priv', FollowListKind.following),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.code,
              'code',
              ErrorCode.authForbidden,
            ),
          ),
        );
      },
    );
  });

  group('screen', () {
    // D175: a private account you do not follow offers Follow too (it sends
    // a request; until v1.47-social there was no control on that row), and
    // a pending request says "Requested".
    testWidgets('two tabs with the profile count labels; rows with name, '
        '@username and Follow back / Following / Follow / Requested; none '
        'for yourself', (tester) async {
      final lists = _FakeLists(
        followers: [
          _person(1, followsMe: true),
          _person(2, followedByMe: true, followsMe: true),
          _person(3),
          _person(4, isSelf: true, name: 'Me'),
          _person(5, isPrivate: true),
          _person(6, isPrivate: true, requestedByMe: true),
        ],
        following: [_person(7, followedByMe: true)],
      );
      await _pump(tester, lists: lists);
      // D125 header: back, the username centred, add people.
      expect(find.byKey(FollowListsScreen.backKey), findsOneWidget);
      expect(find.byKey(FollowListsScreen.addPeopleKey), findsOneWidget);
      expect(find.text('user0'), findsOneWidget);
      // Tabs carry the profile's counts (apiProfile: 1 234 / 40).
      expect(
        find.descendant(
          of: find.byKey(FollowListsScreen.tabKey(FollowListKind.followers)),
          matching: find.text(
            en.followListsTabFollowers(KFormat.compact(1234, en)),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(FollowListsScreen.tabKey(FollowListKind.following)),
          matching: find.text(en.followListsTabFollowing('40')),
        ),
        findsOneWidget,
      );
      expect(lists.calls, ['followers user0']);
      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('user1'), findsOneWidget);
      // Someone else's list: no Message; ⋯ on every row but yourself.
      expect(find.byKey(FollowListView.messageKey('user1')), findsNothing);
      expect(find.byKey(FollowListView.moreKey('user1')), findsOneWidget);
      expect(find.byKey(FollowListView.moreKey('user4')), findsNothing);
      expect(_buttonText(tester, 'user1'), en.followListsFollowBack);
      expect(_buttonText(tester, 'user2'), en.liveFollowing);
      expect(_buttonText(tester, 'user3'), en.liveFollow);
      expect(_button('user4'), findsNothing);
      expect(_buttonText(tester, 'user5'), en.liveFollow);
      expect(_buttonText(tester, 'user6'), en.followRequested);

      await tester.tap(
        find.byKey(FollowListsScreen.tabKey(FollowListKind.following)),
      );
      await tester.pumpAndSettle();
      expect(lists.calls, ['followers user0', 'following user0']);
      expect(find.text('Person 7'), findsOneWidget);
      expect(_buttonText(tester, 'user7'), en.liveFollowing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('?tab=following opens on Following', (tester) async {
      final lists = _FakeLists(following: [_person(7, followedByMe: true)]);
      await _pump(
        tester,
        lists: lists,
        initial: AppRoutes.userFollows('user0', following: true),
      );
      expect(lists.calls, ['following user0']);
      expect(find.text('Person 7'), findsOneWidget);
    });

    testWidgets('pages as you scroll (cursor), pull to refresh restarts', (
      tester,
    ) async {
      final lists = _FakeLists(
        followers: [for (var i = 1; i <= 45; i++) _person(i)],
      );
      await _pump(tester, lists: lists);
      expect(lists.calls, ['followers user0']);
      await tester.scrollUntilVisible(
        _row('user45'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(lists.calls, [
        'followers user0',
        'followers user0 c20',
        'followers user0 c40',
      ]);
      expect(_row('user45'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, 600),
        1000,
      );
      await tester.pumpAndSettle();
      expect(lists.calls.last, 'followers user0');
      expect(lists.calls.where((c) => c == 'followers user0'), hasLength(2));
    });

    testWidgets('Follow back turns into Following at once (optimistic) and '
        'stays; Following → unfollow; a failure rolls back with a message', (
      tester,
    ) async {
      final profiles = _FakeProfiles()..gate = Completer<void>();
      final lists = _FakeLists(
        followers: [
          _person(1, followsMe: true),
          _person(2, followedByMe: true),
        ],
      );
      await _pump(tester, lists: lists, profiles: profiles);
      // The header's counts read the profile (D125).
      expect(profiles.calls, ['GET user0']);
      profiles.calls.clear();

      await tester.tap(_button('user1'));
      await tester.pump();
      expect(_buttonText(tester, 'user1'), en.liveFollowing);
      expect(profiles.calls, ['PUT user1']);
      // A second tap while in flight is ignored.
      await tester.tap(_button('user1'));
      await tester.pump();
      expect(profiles.calls, ['PUT user1']);
      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(_buttonText(tester, 'user1'), en.liveFollowing);

      profiles
        ..gate = null
        ..failure = _server(ErrorCode.rateLimited, 'RATE_LIMITED');
      await tester.tap(_button('user2'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'DELETE user2');
      expect(_buttonText(tester, 'user2'), en.liveFollowing);
      expect(find.byType(SnackBar), findsOneWidget);

      profiles.failure = null;
      await tester.tap(_button('user2'));
      await tester.pumpAndSettle();
      expect(_buttonText(tester, 'user2'), en.liveFollow);
    });

    testWidgets('unfollowing a private account asks first', (tester) async {
      final profiles = _FakeProfiles();
      final lists = _FakeLists(
        followers: [_person(1, followedByMe: true, isPrivate: true)],
      );
      await _pump(tester, lists: lists, profiles: profiles);
      profiles.calls.clear();
      await tester.tap(_button('user1'));
      await tester.pumpAndSettle();
      expect(profiles.calls, isEmpty);
      await tester.tap(find.byKey(const Key('follows.unfollowConfirm')));
      await tester.pumpAndSettle();
      // The tab counts are read again (D125).
      expect(profiles.calls, ['DELETE user1', 'GET user0']);
      // Not followed any more: Follow again sends a request (D175; there was
      // no control here before follow requests existed).
      expect(_buttonText(tester, 'user1'), en.liveFollow);
      profiles.private.add('user1');
      await tester.tap(_button('user1'));
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'GET user0');
      expect(profiles.calls, contains('PUT user1'));
      expect(_buttonText(tester, 'user1'), en.followRequested);
      // Cancelling a request asks nothing.
      await tester.tap(_button('user1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('follows.unfollowConfirm')), findsNothing);
      expect(profiles.calls, contains('DELETE user1'));
      expect(_buttonText(tester, 'user1'), en.liveFollow);
    });

    testWidgets('a row opens that profile', (tester) async {
      final lists = _FakeLists(followers: [_person(1)]);
      await _pump(tester, lists: lists);
      await tester.tap(find.text('Person 1'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicProfileScreen), findsOneWidget);
    });

    testWidgets('empty, private (403), unavailable or blocked (404) and '
        'error states', (tester) async {
      final lists = _FakeLists();
      await _pump(tester, lists: lists);
      expect(find.byKey(FollowListView.emptyKey), findsOneWidget);
      expect(find.text(en.followListsFollowersEmpty), findsOneWidget);

      lists.failure = _server(ErrorCode.authForbidden, 'AUTH_FORBIDDEN');
      await _pump(tester, lists: lists, initial: '/users/priv/follows');
      expect(find.byKey(FollowListView.privateKey), findsOneWidget);
      expect(find.text(en.followListsPrivateBody), findsOneWidget);

      lists.failure = _server(ErrorCode.notFound, 'NOT_FOUND');
      await _pump(tester, lists: lists, initial: '/users/blocked/follows');
      expect(find.byKey(FollowListView.notFoundKey), findsOneWidget);
      expect(find.text(en.profileNotFoundTitle), findsOneWidget);

      lists.failure = const NetworkFailure.offline();
      await _pump(tester, lists: lists, initial: '/users/x/follows');
      expect(find.text(en.errorTitle), findsOneWidget);
      lists.failure = null;
      await tester.tap(find.text(en.actionRetry));
      await tester.pumpAndSettle();
      expect(find.byKey(FollowListView.emptyKey), findsOneWidget);
    });

    testWidgets('Arabic: RTL, the Arabic labels and Follow back', (
      tester,
    ) async {
      final lists = _FakeLists(
        followers: [
          _person(1, followsMe: true, name: 'سارة'),
          _person(2, followedByMe: true, name: 'عمر'),
        ],
      );
      await _pump(tester, lists: lists, language: AppLanguage.ar);
      expect(
        find.text(ar.followListsTabFollowers(KFormat.compact(1234, ar))),
        findsOneWidget,
      );
      expect(find.text(ar.followListsTabFollowing('40')), findsOneWidget);
      expect(ar.followListsTabFollowing('91'), '91 يتابع');
      expect(
        find.text('${ar.followListsSortBy} ${ar.followListsSortDefault}'),
        findsOneWidget,
      );
      expect(_buttonText(tester, 'user1'), 'رد المتابعة');
      expect(_buttonText(tester, 'user2'), ar.liveFollowing);
      expect(
        Directionality.of(tester.element(_row('user1'))),
        TextDirection.rtl,
      );
      // The photo is at the reading start (right) and the button at the end.
      final avatar = tester.getCenter(
        find.descendant(of: _row('user1'), matching: find.byType(KAvatar)),
      );
      final button = tester.getCenter(_button('user1'));
      expect(avatar.dx, greaterThan(button.dx));
    });

    for (final language in AppLanguage.values) {
      testWidgets('360×800 at text scale 2 (${language.name}): no overflow', (
        tester,
      ) async {
        final lists = _FakeLists(
          followers: [
            _person(
              1,
              followsMe: true,
              name: 'A very long display name that never ends at all',
            ),
            _person(2, followedByMe: true),
            _person(3),
          ],
        );
        await _pump(
          tester,
          lists: lists,
          language: language,
          viewport: GoldenViewport.android,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(_button('user1'), findsOneWidget);
        expect(
          tester.getSize(_button('user1')).width,
          lessThanOrEqualTo(FollowListRow.buttonMaxWidth),
        );
        await tester.tap(
          find.byKey(FollowListsScreen.tabKey(FollowListKind.following)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('D125 search, sort, header', () {
    testWidgets('search waits 300 ms after the last keystroke, then asks the '
        'server (q); no match has its own state; clearing restores the list', (
      tester,
    ) async {
      final lists = _FakeLists(
        followers: [
          _person(1, name: 'Omar'),
          _person(2, name: 'Sara'),
        ],
      );
      await _pump(tester, lists: lists);
      expect(lists.calls, ['followers user0']);
      await tester.enterText(find.byKey(FollowListsScreen.searchKey), 'Sa');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(find.byKey(FollowListsScreen.searchKey), 'Sar');
      await tester.pump(const Duration(milliseconds: 299));
      expect(lists.calls, ['followers user0']);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(lists.calls.last, 'followers user0 q=Sar');
      expect(lists.calls, hasLength(2));
      expect(find.text('Person 1'), findsNothing);
      expect(find.text('Sara'), findsOneWidget);

      await tester.enterText(find.byKey(FollowListsScreen.searchKey), 'zz');
      await tester.pump(FollowListsScreen.searchDebounce);
      await tester.pumpAndSettle();
      expect(find.byKey(FollowListView.noMatchKey), findsOneWidget);
      expect(find.text(en.followListsNoMatchBody('zz')), findsOneWidget);

      await tester.tap(find.byKey(FollowListsScreen.searchClearKey));
      await tester.pumpAndSettle();
      expect(find.text('Omar'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.byKey(FollowListsScreen.searchClearKey), findsNothing);
    });

    testWidgets('the sort row toggles Default (newest) ↔ Oldest first and '
        'asks the server for order=oldest', (tester) async {
      final lists = _FakeLists(followers: [_person(1), _person(2), _person(3)]);
      await _pump(tester, lists: lists);
      expect(
        find.text('${en.followListsSortBy} ${en.followListsSortDefault}'),
        findsOneWidget,
      );
      double y(String u) => tester.getCenter(_row(u)).dy;
      expect(y('user1'), lessThan(y('user3')));
      await tester.tap(find.byKey(FollowListsScreen.sortKey));
      await tester.pumpAndSettle();
      expect(lists.calls.last, 'followers user0 oldest');
      expect(
        find.text('${en.followListsSortBy} ${en.followListsSortOldest}'),
        findsOneWidget,
      );
      expect(y('user3'), lessThan(y('user1')));
      await tester.tap(find.byKey(FollowListsScreen.sortKey));
      await tester.pumpAndSettle();
      expect(y('user1'), lessThan(y('user3')));
    });

    testWidgets('add people opens Discover (user search)', (tester) async {
      await _pump(tester, lists: _FakeLists(followers: [_person(1)]));
      await tester.tap(find.byKey(FollowListsScreen.addPeopleKey));
      await tester.pumpAndSettle();
      expect(find.text('discover'), findsOneWidget);
    });

    testWidgets('header and rows: back circle at the reading start, add '
        'people at the end, 56 pt photos; Arabic mirrors it', (tester) async {
      for (final language in AppLanguage.values) {
        await _pump(
          tester,
          lists: _FakeLists(followers: [_person(1)]),
          language: language,
        );
        final back = tester.getCenter(find.byKey(FollowListsScreen.backKey));
        final add = tester.getCenter(
          find.byKey(FollowListsScreen.addPeopleKey),
        );
        expect(
          back.dx < add.dx,
          language == AppLanguage.en,
          reason: language.name,
        );
        expect(
          tester
              .getSize(
                find.descendant(
                  of: _row('user1'),
                  matching: find.byType(KAvatar),
                ),
              )
              .width,
          FollowListRow.avatarSize,
        );
      }
    });
  });

  group('D125 my own lists', () {
    testWidgets('the search field and Message are a visible grey in light '
        'and dark (surfaceOverlay); ⋯ lines up with the sort icon', (
      tester,
    ) async {
      for (final b in Brightness.values) {
        await _pump(
          tester,
          lists: _FakeLists(followers: [_person(1)]),
          initial: AppRoutes.userFollows('layla.k'),
          brightness: b,
        );
        final palette = b == Brightness.light ? KPalette.light : KPalette.dark;
        final field = tester.widget<TextField>(
          find.byKey(FollowListsScreen.searchKey),
        );
        expect(field.decoration!.fillColor, palette.surfaceOverlay);
        expect(palette.surfaceOverlay, isNot(palette.background));
        final button = tester.widget<FilledButton>(
          find.byKey(FollowListView.messageKey('user1')),
        );
        expect(
          button.style!.backgroundColor!.resolve({}),
          palette.surfaceOverlay,
        );
        final more = tester.getCenter(
          find.byKey(FollowListView.moreKey('user1')),
        );
        final sort = tester.getCenter(
          find.descendant(
            of: find.byKey(FollowListsScreen.sortKey),
            matching: find.byIcon(Icons.swap_vert_rounded),
          ),
        );
        expect(more.dx, closeTo(sort.dx, 0.5), reason: b.name);
      }
    });

    const me = 'layla.k';

    testWidgets('rows show Message (opens the conversation) and ⋯, no '
        'Follow control', (tester) async {
      final lists = _FakeLists(followers: [_person(1, followsMe: true)]);
      await _pump(tester, lists: lists, initial: AppRoutes.userFollows(me));
      expect(_button('user1'), findsNothing);
      final message = find.byKey(FollowListView.messageKey('user1'));
      expect(message, findsOneWidget);
      expect(
        find.descendant(of: message, matching: find.text(en.profileMessage)),
        findsOneWidget,
      );
      await tester.tap(message);
      await tester.pumpAndSettle();
      expect(find.text('chat user1'), findsOneWidget);
    });

    testWidgets('followers ⋯: Follow back, Remove follower (asks, then '
        'DELETE /me/followers and the row leaves), Report, Block', (
      tester,
    ) async {
      final lists = _FakeLists(
        followers: [_person(1, followsMe: true), _person(2, followsMe: true)],
      );
      final profiles = _FakeProfiles();
      await _pump(
        tester,
        lists: lists,
        profiles: profiles,
        initial: AppRoutes.userFollows(me),
      );
      await tester.tap(find.byKey(FollowListView.moreKey('user1')));
      await tester.pumpAndSettle();
      for (final a in ['followBack', 'removeFollower', 'report', 'block']) {
        expect(find.byKey(Key('follows.menu.$a')), findsOneWidget, reason: a);
      }
      expect(find.byKey(const Key('follows.menu.unfollow')), findsNothing);
      await tester.tap(find.byKey(const Key('follows.menu.removeFollower')));
      await tester.pumpAndSettle();
      expect(
        find.text(en.followListsRemoveFollowerTitle('Person 1')),
        findsOneWidget,
      );
      // Cancel changes nothing.
      await tester.tap(find.text(en.actionCancel));
      await tester.pumpAndSettle();
      expect(lists.calls.where((c) => c.startsWith('REMOVE')), isEmpty);

      await tester.tap(find.byKey(FollowListView.moreKey('user1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('follows.menu.removeFollower')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('follows.removeConfirm')));
      await tester.pumpAndSettle();
      expect(lists.calls, contains('REMOVE user1'));
      expect(_row('user1'), findsNothing);
      expect(_row('user2'), findsOneWidget);
      expect(
        find.text(en.followListsFollowerRemoved('Person 1')),
        findsOneWidget,
      );
      // The profile counts are reloaded.
      expect(profiles.calls.where((c) => c == 'GET $me'), hasLength(2));

      // Follow back from the menu.
      await tester.tap(find.byKey(FollowListView.moreKey('user2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('follows.menu.followBack')));
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('PUT user2'));
    });

    testWidgets('a failed removal keeps the row and says why', (tester) async {
      final lists = _FakeLists(followers: [_person(1)]);
      await _pump(tester, lists: lists, initial: AppRoutes.userFollows(me));
      lists.failure = _server(ErrorCode.rateLimited, 'RATE_LIMITED');
      await tester.tap(find.byKey(FollowListView.moreKey('user1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('follows.menu.removeFollower')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('follows.removeConfirm')));
      await tester.pumpAndSettle();
      expect(_row('user1'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('following ⋯: Unfollow (the row leaves), Report, Block; no '
        'Remove follower', (tester) async {
      final lists = _FakeLists(
        following: [
          _person(7, followedByMe: true),
          _person(8, followedByMe: true),
        ],
      );
      final profiles = _FakeProfiles();
      await _pump(
        tester,
        lists: lists,
        profiles: profiles,
        initial: AppRoutes.userFollows(me, following: true),
      );
      await tester.tap(find.byKey(FollowListView.moreKey('user7')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('follows.menu.removeFollower')),
        findsNothing,
      );
      expect(find.byKey(const Key('follows.menu.report')), findsOneWidget);
      expect(find.byKey(const Key('follows.menu.block')), findsOneWidget);
      await tester.tap(find.byKey(const Key('follows.menu.unfollow')));
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('DELETE user7'));
      expect(_row('user7'), findsNothing);
      expect(_row('user8'), findsOneWidget);
    });

    testWidgets("someone else's list ⋯: only Report and Block", (tester) async {
      await _pump(
        tester,
        lists: _FakeLists(followers: [_person(1, followsMe: true)]),
      );
      await tester.tap(find.byKey(FollowListView.moreKey('user1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('follows.menu.report')), findsOneWidget);
      expect(find.byKey(const Key('follows.menu.block')), findsOneWidget);
      for (final a in ['followBack', 'unfollow', 'removeFollower']) {
        expect(find.byKey(Key('follows.menu.$a')), findsNothing, reason: a);
      }
    });

    for (final language in AppLanguage.values) {
      testWidgets('my lists at 360×800, text scale 2 (${language.name}): no '
          'overflow, Message stays bounded', (tester) async {
        await _pump(
          tester,
          lists: _FakeLists(
            followers: [
              _person(1, name: 'A very long display name that never ends'),
              _person(2),
            ],
          ),
          initial: AppRoutes.userFollows(me),
          language: language,
          viewport: GoldenViewport.android,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(FollowListView.messageKey('user1'))).width,
          lessThanOrEqualTo(FollowListRow.buttonMaxWidth),
        );
        await tester.enterText(find.byKey(FollowListsScreen.searchKey), 'A');
        await tester.pump(FollowListsScreen.searchDebounce);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('way in', () {
    testWidgets('tapping Followers / Following on a public profile opens '
        'the lists on that tab', (tester) async {
      final lists = _FakeLists(
        followers: [_person(1)],
        following: [_person(2)],
      );
      await _pump(
        tester,
        lists: lists,
        initial: AppRoutes.userProfile('host0'),
      );
      await tester.tap(find.byKey(ProfileHeaderView.followersKey));
      await tester.pumpAndSettle();
      expect(find.byType(FollowListsScreen), findsOneWidget);
      expect(lists.calls, ['followers host0']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileHeaderView.followingKey));
      await tester.pumpAndSettle();
      expect(lists.calls.last, 'following host0');
      expect(find.text('Person 2'), findsOneWidget);
    });

    testWidgets('tapping the counts on my own profile opens my lists', (
      tester,
    ) async {
      final lists = _FakeLists(following: [_person(2, followedByMe: true)]);
      final me = testUser();
      await _pump(
        tester,
        lists: lists,
        initial: '/me',
        extra: [
          meProvider.overrideWith((ref) => me),
          profileStatsProvider.overrideWith(
            (ref, _) => apiProfile(isSelf: true),
          ),
        ],
      );
      await tester.tap(find.byKey(ProfileHeaderView.followingKey));
      await tester.pumpAndSettle();
      expect(lists.calls, ['following ${me.username}']);
      expect(find.text('Person 2'), findsOneWidget);
    });

    testWidgets('a private profile you do not follow keeps the counts plain', (
      tester,
    ) async {
      final lists = _FakeLists();
      await _pump(
        tester,
        lists: lists,
        profiles: _FakeProfiles(apiProfile(isPrivate: true)),
        initial: AppRoutes.userProfile('host0'),
      );
      await tester.tap(find.byKey(ProfileHeaderView.followersKey));
      await tester.pumpAndSettle();
      expect(find.byType(FollowListsScreen), findsNothing);
      expect(lists.calls, isEmpty);
    });
  });
}
