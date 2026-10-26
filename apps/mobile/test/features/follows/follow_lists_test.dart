// D121: the follower and following lists — the repository against the
// contract, the screen's two tabs, paging, pull to refresh, Follow /
// Following / Follow back with optimistic update and rollback, the private
// (403) and unavailable (404) states, the way in from a profile's counts,
// Arabic RTL and English LTR, 360×800 and text scale 2.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
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
);

AppFailure _server(ErrorCode code, String raw) =>
    ServerFailure(code: code, rawCode: raw, debugMessage: raw);

/// In-memory lists, served [pageSize] at a time; every call is recorded as
/// `followers user0` or `following user0 c20`.
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
  }) async {
    calls.add('${kind.path} $username${cursor == null ? '' : ' $cursor'}');
    if (failure case final f?) throw f;
    final all = kind == FollowListKind.followers ? followers : following;
    final start = cursor == null ? 0 : int.parse(cursor.substring(1));
    final end = (start + pageSize).clamp(0, all.length);
    final more = end < all.length;
    return PageOf(
      all.sublist(start, end),
      PageInfo(nextCursor: more ? 'c$end' : null, hasMore: more),
    );
  }
}

/// Follow / unfollow by username, with an optional [gate] and [failure].
class _FakeProfiles implements ProfileRepository {
  new([PublicProfile? profile]) : profile = profile ?? apiProfile();

  PublicProfile profile;
  Completer<void>? gate;
  AppFailure? failure;
  final List<String> calls = [];

  @override
  Future<PublicProfile> getProfile(String username) async {
    calls.add('GET $username');
    return profile;
  }

  Future<FollowState> _edge(String verb, String username, bool to) async {
    calls.add('$verb $username');
    await gate?.future;
    if (failure case final f?) throw f;
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
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: language.locale,
        ),
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
    testWidgets('two tabs with the profile count labels; rows with name, '
        '@username and Follow back / Following / Follow; none for yourself '
        'or a private account you do not follow', (tester) async {
      final lists = _FakeLists(
        followers: [
          _person(1, followsMe: true),
          _person(2, followedByMe: true, followsMe: true),
          _person(3),
          _person(4, isSelf: true, name: 'Me'),
          _person(5, isPrivate: true),
        ],
        following: [_person(7, followedByMe: true)],
      );
      await _pump(tester, lists: lists);
      expect(find.text('@user0'), findsOneWidget);
      expect(
        find.byKey(FollowListsScreen.tabKey(FollowListKind.followers)),
        findsOneWidget,
      );
      for (final kind in FollowListKind.values) {
        expect(
          find.descendant(
            of: find.byKey(FollowListsScreen.tabKey(kind)),
            matching: find.text(followListLabel(en, kind)),
          ),
          findsOneWidget,
        );
      }
      expect(lists.calls, ['followers user0']);
      expect(find.text('Person 1'), findsOneWidget);
      expect(find.text('@user1'), findsOneWidget);
      expect(_buttonText(tester, 'user1'), en.followListsFollowBack);
      expect(_buttonText(tester, 'user2'), en.liveFollowing);
      expect(_buttonText(tester, 'user3'), en.liveFollow);
      expect(_button('user4'), findsNothing);
      expect(_button('user5'), findsNothing);

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
      await tester.tap(_button('user1'));
      await tester.pumpAndSettle();
      expect(profiles.calls, isEmpty);
      await tester.tap(find.byKey(const Key('follows.unfollowConfirm')));
      await tester.pumpAndSettle();
      expect(profiles.calls, ['DELETE user1']);
      // Not followed any more and private: no control.
      expect(_button('user1'), findsNothing);
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
      expect(find.text('المتابِعون'), findsOneWidget);
      expect(find.text(ar.profileFollowingCount), findsOneWidget);
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
