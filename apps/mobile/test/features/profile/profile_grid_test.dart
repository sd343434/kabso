// KL-060 part D1: profile grids on the posts API — a user's posts (pinned
// first) and the caller's saved posts, paged; a hidden grid (404) is empty;
// a cell opens the post screen, which says when a post is gone and leaves
// when the post is deleted there.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/presentation/post_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

void main() {
  group('grid pages', () {
    late FakePostsRepository repo;
    late ProviderContainer c;

    setUp(() {
      repo = FakePostsRepository(pageSize: 2);
      c = ProviderContainer.test(
        overrides: [
          postsRepositoryProvider.overrideWithValue(repo),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
    });

    Future<FeedItems<ProfileGridItem>> read(ProfileGridKey key) async =>
        await c.read(profileGridProvider(key).future)
            as FeedItems<ProfileGridItem>;

    test('posts: cells from the API (photo cover, text, pinned, gallery); '
        'the next page appends', () async {
      repo.profilePosts['sara'] = [
        testPost('p1', pinned: true, photos: 2),
        testPost('p2', text: 'Words only'),
        testPost('p3', photos: 1),
      ];
      const key = (username: 'sara', tab: ProfileTab.posts);
      final first = await read(key);
      expect(repo.calls, contains('userPosts:sara:'));
      expect([for (final i in first.items) i.postId], ['p1', 'p2']);
      expect(first.items[0].pinned, isTrue);
      expect(first.items[0].multiple, isTrue);
      expect(
        (first.items[0].cover! as NetworkImage).url,
        'https://media.example.test/media/p1-m0/320.webp',
      );
      expect(first.items[1].cover, isNull);
      expect(first.items[1].text, 'Words only');
      expect(first.hasMore, isTrue);
      await c.read(profileGridPagesProvider(key).notifier).loadMore();
      final all = await read(key);
      expect(repo.calls, contains('userPosts:sara:2'));
      expect([for (final i in all.items) i.postId], ['p1', 'p2', 'p3']);
      expect(all.hasMore, isFalse);
    });

    test('saved reads /me/saved; a hidden grid (404) is empty', () async {
      repo
        ..savedPosts = [testPost('s1', photos: 1)]
        ..hiddenProfiles.add('private.one');
      final saved = await read((username: 'me', tab: ProfileTab.saved));
      expect(repo.calls, contains('saved:'));
      expect(saved.items.single.postId, 's1');
      final hidden = await read((
        username: 'private.one',
        tab: ProfileTab.posts,
      ));
      expect(hidden.items, isEmpty);
    });

    test('a failed next page keeps the cells and offers a retry', () async {
      repo.profilePosts['sara'] = [
        testPost('p1'),
        testPost('p2'),
        testPost('p3'),
      ];
      const key = (username: 'sara', tab: ProfileTab.posts);
      await read(key);
      repo.failWith = Exception('offline');
      await c.read(profileGridPagesProvider(key).notifier).loadMore();
      final s = await read(key);
      expect(s.items, hasLength(2));
      expect(s.loadMoreError, isNotNull);
      await c.read(profileGridPagesProvider(key).notifier).loadMore();
      expect((await read(key)).items, hasLength(3));
    });
  });

  group('screens', () {
    Future<(FakePostsRepository, GoRouter)> pump(
      WidgetTester tester, {
      FakePostsRepository? repo,
    }) async {
      final posts = repo ?? FakePostsRepository();
      final router = GoRouter(
        initialLocation: '/grid',
        routes: [
          GoRoute(
            path: '/grid',
            builder: (_, _) => const Scaffold(
              body: CustomScrollView(
                slivers: [ProfileGrid(username: 'sara', tab: ProfileTab.posts)],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.postPattern,
            builder: (_, state) =>
                PostScreen(postId: state.pathParameters['postId']!),
          ),
        ],
      );
      setViewport(tester, GoldenViewport.phone);
      final prefs = await testPrefs();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postsRepositoryProvider.overrideWithValue(posts),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.light,
              locale: AppLanguage.en.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (posts, router);
    }

    testWidgets('a cell opens the post; deleting it there goes back and the '
        'cell leaves the grid', (tester) async {
      final repo = FakePostsRepository();
      repo.profilePosts['sara'] = [
        testPost('p1', text: 'Mine', isSelf: true),
        testPost('p2', text: 'Other'),
      ];
      final (_, router) = await pump(tester, repo: repo);
      expect(find.text('Mine'), findsOneWidget);
      await tester.tap(find.byKey(ProfileGrid.cellKey('p1')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.post('p1'));
      expect(find.byType(FeedPostTile), findsOneWidget);
      expect(repo.calls, contains('getPost:p1'));

      await tester.tap(find.byKey(FeedPostTile.moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.deleteActionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.deleteConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('delete:p1'));
      expect(router.state.uri.path, '/grid');
      expect(find.byKey(ProfileGrid.cellKey('p1')), findsNothing);
      expect(find.byKey(ProfileGrid.cellKey('p2')), findsOneWidget);
    });

    testWidgets('later pages load as the grid scrolls', (tester) async {
      final repo = FakePostsRepository(pageSize: 9);
      repo.profilePosts['sara'] = [
        for (var i = 0; i < 20; i++) testPost('p$i', photos: 1),
      ];
      await pump(tester, repo: repo);
      await tester.scrollUntilVisible(
        find.byKey(ProfileGrid.cellKey('p19')),
        300,
      );
      expect(
        repo.calls,
        containsAll(['userPosts:sara:9', 'userPosts:sara:18']),
      );
    });

    testWidgets('a post that is gone says so', (tester) async {
      final (_, router) = await pump(tester);
      unawaited(router.push(AppRoutes.post('nope')));
      await tester.pumpAndSettle();
      expect(find.byKey(PostScreen.unavailableKey), findsOneWidget);
      expect(find.text(_en.postUnavailableTitle), findsOneWidget);
    });
  });
}
