// KL-060 part D2: search (accounts, hashtags, posts) on GET /search, the
// hashtag page (GET /hashtags/{tag} and its posts, recent or top), and
// linked #tags and @mentions in captions.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/discover/hashtag_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/application/search_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
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
  test('queries: trimmed, one leading @ or # dropped, at most 64', () {
    expect(normalizeSearchQuery('  @omar '), 'omar');
    expect(normalizeSearchQuery('#البتراء'), 'البتراء');
    expect(normalizeSearchQuery('  '), '');
    expect(normalizeSearchQuery('x' * 80).length, maxSearchQuery);
  });

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

    test(
      'search sends q, type and the cursor; hashtag paths are encoded',
      () async {
        http
          ..on(
            'GET',
            '$base/search',
            (o) => FakeResponse(
              200,
              body: {
                'type': o.queryParameters['type'],
                'data': o.queryParameters['type'] == 'hashtags'
                    ? [
                        {'tag': 'petra', 'postCount': 3},
                      ]
                    : [
                        {
                          'id': 'u1',
                          'username': 'omar',
                          'displayName': 'Omar',
                          'avatarUrl': null,
                        },
                      ],
                'page': {'nextCursor': null, 'hasMore': false},
              },
            ),
          )
          ..on(
            'GET',
            '$base/hashtags/${Uri.encodeComponent('البتراء')}',
            (_) => const FakeResponse(
              200,
              body: {'tag': 'البتراء', 'postCount': 2},
            ),
          )
          ..on(
            'GET',
            '$base/hashtags/petra/posts',
            (_) => FakeResponse(
              200,
              body: {
                'data': [postJson('p1')],
                'page': {'nextCursor': null, 'hasMore': false},
              },
            ),
          );
        final people = await repo.searchPeople('om', cursor: 'c2');
        expect(people.items.single.username, 'omar');
        expect(http.requests.last.queryParameters, {
          'q': 'om',
          'type': 'users',
          'cursor': 'c2',
        });
        final tags = await repo.searchHashtags('pe');
        expect(tags.items.single.postCount, 3);
        expect(http.requests.last.queryParameters, {
          'q': 'pe',
          'type': 'hashtags',
        });
        expect((await repo.hashtag('البتراء')).postCount, 2);
        await repo.hashtagPosts('petra', sort: HashtagSort.top);
        expect(http.requests.last.queryParameters, {'sort': 'top'});
      },
    );
  });

  group('screens', () {
    Future<(FakePostsRepository, GoRouter)> pump(
      WidgetTester tester, {
      required FakePostsRepository repo,
      String initial = '/discover',
      Widget? home,
      AppLanguage language = AppLanguage.en,
    }) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
          GoRoute(
            path: '/home',
            builder: (_, _) => Scaffold(body: ListView(children: [?home])),
          ),
          GoRoute(
            path: AppRoutes.hashtagPattern,
            builder: (_, s) => HashtagScreen(tag: s.pathParameters['tag']!),
          ),
          GoRoute(
            path: AppRoutes.userProfilePattern,
            builder: (_, s) =>
                Scaffold(body: Text('profile ${s.pathParameters['username']}')),
          ),
          GoRoute(
            path: AppRoutes.postPattern,
            builder: (_, s) =>
                Scaffold(body: Text('post ${s.pathParameters['postId']}')),
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
      return (repo, router);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(DiscoverScreen.fieldKey), text);
      await tester.pump(DiscoverScreen.debounce);
      await tester.pumpAndSettle();
    }

    testWidgets('accounts, hashtags and posts; each result opens its page', (
      tester,
    ) async {
      final repo = FakePostsRepository()
        ..people = const [_omar]
        ..tags = const [Hashtag(tag: 'petra', postCount: 3)]
        ..searchable = [testPost('p1', text: 'Petra at night', photos: 1)];
      final (_, router) = await pump(tester, repo: repo);
      expect(find.byKey(DiscoverScreen.promptKey), findsOneWidget);

      await type(tester, '@om');
      expect(repo.calls, contains('search:users:om:'));
      await tester.tap(find.byKey(DiscoverScreen.userKey('omar')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.userProfile('omar'));
      router.pop();
      await tester.pumpAndSettle();

      await type(tester, 'pe');
      await tester.tap(find.byKey(DiscoverScreen.typeKey(SearchType.hashtags)));
      await tester.pumpAndSettle();
      expect(find.text('#petra'), findsOneWidget);
      expect(find.text(_en.hashtagPostCount(3)), findsOneWidget);
      await tester.tap(find.byKey(DiscoverScreen.hashtagKey('petra')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.hashtag('petra'));
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DiscoverScreen.typeKey(SearchType.posts)));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('search:posts:pe:'));
      await tester.tap(find.byKey(PostGridCell.cellKey('p1')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.post('p1'));
    });

    testWidgets('no results says so; clearing returns to the prompt; pages '
        'load on scroll', (tester) async {
      final repo = FakePostsRepository(pageSize: 10)
        ..people = [
          for (var i = 0; i < 25; i++)
            UserSummary(
              id: 'u$i',
              username: 'sam$i',
              displayName: 'Sam $i',
              avatarUrl: null,
            ),
        ];
      await pump(tester, repo: repo);
      await type(tester, 'zz');
      expect(find.byKey(DiscoverScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.searchNoResults('zz')), findsOneWidget);
      await type(tester, 'sam');
      await tester.scrollUntilVisible(
        find.byKey(DiscoverScreen.userKey('sam24')),
        300,
        scrollable: find.descendant(
          of: find.byKey(DiscoverScreen.resultsKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        repo.calls,
        containsAll(['search:users:sam:10', 'search:users:sam:20']),
      );
      await tester.tap(find.byKey(DiscoverScreen.clearKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DiscoverScreen.promptKey), findsOneWidget);
    });

    testWidgets('hashtag page: the count, recent then top, a cell opens the '
        'post; an unused tag says so', (tester) async {
      final repo = FakePostsRepository()
        ..tags = const [Hashtag(tag: 'petra', postCount: 2)]
        ..tagPosts['petra'] = [
          testPost('p1', photos: 1),
          testPost('p2', text: 'Rose city'),
        ];
      final (_, router) = await pump(
        tester,
        repo: repo,
        initial: AppRoutes.hashtag('petra'),
      );
      expect(find.text('#petra'), findsWidgets);
      expect(find.text(_en.hashtagPostCount(2)), findsOneWidget);
      expect(repo.calls, contains('hashtagPosts:petra:recent:'));
      await tester.tap(find.byKey(HashtagScreen.sortKey(HashtagSort.top)));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('hashtagPosts:petra:top:'));
      await tester.tap(find.byKey(PostGridCell.cellKey('p2')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.post('p2'));

      router.go(AppRoutes.hashtag('nothing'));
      await tester.pumpAndSettle();
      expect(find.byKey(HashtagScreen.notFoundKey), findsOneWidget);
    });

    testWidgets('captions: linked #tags and @mentions open their pages; '
        'unlinked ones stay text', (tester) async {
      final post = testPost(
        'p1',
        text: 'Sunset #petra with @omar and @ghost #other',
        hashtags: const ['petra'],
        mentions: const [_omar],
      );
      final (_, router) = await pump(
        tester,
        repo: FakePostsRepository(),
        initial: '/home',
        home: FeedPostTile(post: feedPostOf(post)),
      );
      await tester.tapOnText(find.textRange.ofSubstring('#petra'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.hashtag('petra'));
      router.pop();
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring('@omar'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.userProfile('omar'));
      router.pop();
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring('#other'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
    });

    testWidgets('Arabic RTL at 360 dp and text scale 1.3: no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      setViewport(tester, GoldenViewport.android);
      final repo = FakePostsRepository()
        ..tags = const [Hashtag(tag: 'البتراء', postCount: 12345)];
      await pump(tester, repo: repo, language: AppLanguage.ar);
      setViewport(tester, GoldenViewport.android);
      await tester.pumpAndSettle();
      await type(tester, '#الب');
      await tester.tap(find.byKey(DiscoverScreen.typeKey(SearchType.hashtags)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('#البتراء'), findsOneWidget);
    });
  });
}
