// KL-060 part E1: reposts (PUT/DELETE /posts/{id}/repost and the profile
// Reposts tab on GET /users/{username}/reposts) and who liked a post
// (GET /posts/{id}/likes; 403 when the author hides the like count).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/presentation/likers_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

void main() {
  group('wire', () {
    late FakeHttpAdapter http;
    late PostsRepositoryImpl repo;
    const base = '/api/v1';

    setUp(() {
      http = FakeHttpAdapter();
      repo = PostsRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
    });

    test('repost is PUT, undo is DELETE; the state comes back', () async {
      http
        ..on(
          'PUT',
          '$base/posts/p1/repost',
          (_) => const FakeResponse(
            200,
            body: {'reposted': true, 'repostCount': 4},
          ),
        )
        ..on(
          'DELETE',
          '$base/posts/p1/repost',
          (_) => const FakeResponse(
            200,
            body: {'reposted': false, 'repostCount': 3},
          ),
        );
      expect(await repo.setReposted('p1', reposted: true), (
        reposted: true,
        repostCount: 4,
      ));
      expect(await repo.setReposted('p1', reposted: false), (
        reposted: false,
        repostCount: 3,
      ));
    });

    test('likers and reposts are paged lists; 403 is AUTH_FORBIDDEN', () async {
      http
        ..on(
          'GET',
          '$base/posts/p1/likes',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'id': 'u-omar',
                  'username': 'omar',
                  'displayName': 'Omar',
                  'avatarUrl': null,
                },
              ],
              'page': {'nextCursor': 'c2', 'hasMore': true},
            },
          ),
        )
        ..on(
          'GET',
          '$base/posts/p2/likes',
          (_) => FakeResponse(
            403,
            body: errorEnvelope('AUTH_FORBIDDEN', 'Hidden'),
          ),
        )
        ..on(
          'GET',
          '$base/users/sara/reposts',
          (_) => FakeResponse(
            200,
            body: {
              'data': [postJson('p9')],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        );
      final likers = await repo.likers('p1', cursor: 'c1');
      expect(likers.items.single.username, 'omar');
      expect(likers.next, 'c2');
      expect(http.requests.last.queryParameters, {'cursor': 'c1'});
      await expectLater(
        repo.likers('p2'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.authForbidden,
          ),
        ),
      );
      final reposts = await repo.userReposts('sara');
      expect(reposts.items.single.id, 'p9');
    });
  });

  test('the Reposts tab reads /users/{username}/reposts; a hidden '
      'profile (404) is empty', () async {
    final repo = FakePostsRepository(pageSize: 1);
    final c = ProviderContainer.test(
      overrides: [
        postsRepositoryProvider.overrideWithValue(repo),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    repo.userRepostLists['sara'] = [testPost('r1'), testPost('r2')];
    const key = (username: 'sara', tab: ProfileTab.reposts);
    final first = await c.read(
      profileGridProvider(key).future,
    ) as FeedItems<ProfileGridItem>;
    expect([for (final i in first.items) i.postId], ['r1']);
    await c.read(profileGridPagesProvider(key).notifier).loadMore();
    final all = await c.read(
      profileGridProvider(key).future,
    ) as FeedItems<ProfileGridItem>;
    expect([for (final i in all.items) i.postId], ['r1', 'r2']);
    expect(
      repo.calls,
      containsAll(['userReposts:sara:', 'userReposts:sara:1']),
    );

    repo.hiddenProfiles.add('lina');
    const hidden = (username: 'lina', tab: ProfileTab.reposts);
    final none = await c.read(
      profileGridProvider(hidden).future,
    ) as FeedItems<ProfileGridItem>;
    expect(none.items, isEmpty);
  });

  group('screens', () {
    Future<void> pump(
      WidgetTester tester, {
      required FakePostsRepository repo,
      String initial = '/home',
      FeedPostData? post,
      AppLanguage language = AppLanguage.en,
    }) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => Scaffold(
              body: ListView(children: [FeedPostTile(post: post!)]),
            ),
          ),
          GoRoute(
            path: AppRoutes.postLikesPattern,
            builder: (_, s) =>
                LikersScreen(postId: s.pathParameters['postId']!),
          ),
          GoRoute(
            path: AppRoutes.userProfilePattern,
            builder: (_, s) =>
                Scaffold(body: Text('profile ${s.pathParameters['username']}')),
          ),
        ],
      );
      setViewport(tester, GoldenViewport.phone);
      final prefs = await testPrefs(language: language.name);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postsRepositoryProvider.overrideWithValue(repo),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
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
              brightness: Brightness.light,
              locale: language.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String repostValue(WidgetTester tester) =>
        tester.getSemantics(find.byKey(FeedPostTile.repostKey)).value;

    testWidgets('repost applies at once with the server count; undo; a '
        'refused repost (400) comes back with a message', (tester) async {
      final repo = FakePostsRepository()..repostCounts['p1'] = 2;
      await pump(
        tester,
        repo: repo,
        post: feedPostOf(testPost('p1', reposts: 2)),
      );
      expect(repostValue(tester), '2');
      await tester.tap(find.byKey(FeedPostTile.repostKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'repost:p1:true');
      expect(repostValue(tester), '3');
      expect(find.text(_en.feedPostReposted), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(FeedPostTile.repostKey)).label,
        _en.feedPostUnrepost,
      );
      await tester.tap(find.byKey(FeedPostTile.repostKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'repost:p1:false');
      expect(repostValue(tester), '2');

      repo.failWith = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'postId invalid_value',
        statusCode: 400,
      );
      await tester.tap(find.byKey(FeedPostTile.repostKey));
      await tester.pumpAndSettle();
      expect(repostValue(tester), '2');
      expect(find.text(_en.feedPostRepostRefused), findsOneWidget);
    });

    testWidgets('your own post has no repost button', (tester) async {
      await pump(
        tester,
        repo: FakePostsRepository(),
        post: feedPostOf(testPost('p1', isSelf: true)),
      );
      expect(find.byKey(FeedPostTile.repostKey), findsNothing);
      expect(find.byKey(FeedPostTile.likeKey), findsOneWidget);
    });

    testWidgets('the heart likes; the count opens who liked it; a row '
        'opens the profile', (tester) async {
      final repo = FakePostsRepository()..postLikers['p1'] = [_omar];
      await pump(
        tester,
        repo: repo,
        post: feedPostOf(testPost('p1', likes: 1)),
      );
      await tester.tap(find.byKey(FeedPostTile.likeKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'like:p1:true');
      expect(find.text(_en.likersTitle), findsNothing);

      await tester.tap(find.byKey(FeedPostTile.likersKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.likersTitle), findsOneWidget);
      expect(repo.calls.last, 'likers:p1:');
      await tester.tap(find.byKey(LikersScreen.userKey('omar')));
      await tester.pumpAndSettle();
      expect(find.text('profile omar'), findsOneWidget);
    });

    testWidgets('no like count (hidden by the author): nothing opens the '
        'likers', (tester) async {
      await pump(
        tester,
        repo: FakePostsRepository(),
        post: feedPostOf(testPost('p1', hideLikeCount: true)),
      );
      expect(find.byKey(FeedPostTile.likersKey), findsNothing);
    });

    testWidgets('likers: hidden (403) and empty say so', (tester) async {
      final repo = FakePostsRepository()..hiddenLikers.add('p1');
      await pump(tester, repo: repo, initial: AppRoutes.postLikes('p1'));
      expect(find.byKey(LikersScreen.hiddenKey), findsOneWidget);
      expect(find.text(_en.likersHiddenTitle), findsOneWidget);

      await pump(
        tester,
        repo: FakePostsRepository(),
        initial: AppRoutes.postLikes('p2'),
      );
      expect(find.byKey(LikersScreen.emptyKey), findsOneWidget);
    });

    testWidgets('Arabic RTL at 360 dp and text scale 1.3: the action row '
        'does not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        repo: FakePostsRepository(),
        language: AppLanguage.ar,
        post: feedPostOf(testPost('p1', likes: 12345, reposts: 678)),
      );
      setViewport(tester, GoldenViewport.android);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(FeedPostTile.repostKey), findsOneWidget);
    });
  });
}
