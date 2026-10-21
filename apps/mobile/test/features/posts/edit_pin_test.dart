// KL-060 part E2: author controls — pin a post on the profile
// (PUT/DELETE /posts/{id}/pin, at most 3) and edit its caption, place and
// settings (PATCH /posts/{id}); feeds, the post screen and grids follow.

import 'dart:async';

import 'package:dio/dio.dart';
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
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/edit_post_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

void main() {
  test('PostUpdate sends only what is set; an empty place clears it', () {
    expect(const PostUpdate().isEmpty, isTrue);
    expect(const PostUpdate(text: 'Hi', location: '').toJson(), {
      'text': 'Hi',
      'location': null,
    });
    expect(
      const PostUpdate(
        location: 'Amman',
        whoCanComment: WhoCanComment.followers,
        hideLikeCount: true,
      ).toJson(),
      {
        'location': 'Amman',
        'settings': {'whoCanComment': 'FOLLOWERS', 'hideLikeCount': true},
      },
    );
    expect(
      PostUpdate(
        status: 'SCHEDULED',
        publishAt: DateTime.utc(2026, 10, 22, 9, 30),
      ).toJson(),
      {'status': 'SCHEDULED', 'publishAt': '2026-10-22T09:30:00.000Z'},
    );
  });

  test(
    'wire: PATCH /posts/{id} with the body; pin is PUT, unpin DELETE',
    () async {
      final http = FakeHttpAdapter();
      final repo = PostsRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
      for (final m in ['PATCH', 'PUT', 'DELETE']) {
        http.on(
          m,
          m == 'PATCH' ? '/api/v1/posts/p1' : '/api/v1/posts/p1/pin',
          (_) => FakeResponse(200, body: postJson('p1', text: 'New')),
        );
      }
      final post = await repo.updatePost('p1', const PostUpdate(text: 'New'));
      expect(post.text, 'New');
      expect(http.requests.last.data, {'text': 'New'});
      await repo.setPinned('p1', pinned: true);
      expect(http.requests.last.method, 'PUT');
      await repo.setPinned('p1', pinned: false);
      expect(http.requests.last.method, 'DELETE');
    },
  );

  test('a pin reloads the profile grid that shows the post', () async {
    final repo = FakePostsRepository();
    final c = ProviderContainer.test(
      overrides: [
        postsRepositoryProvider.overrideWithValue(repo),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    repo.profilePosts['sara'] = [testPost('p1'), testPost('p2')];
    const key = (username: 'sara', tab: ProfileTab.posts);
    c.listen(profileGridProvider(key), (_, _) {});
    await c.read(profileGridProvider(key).future);
    expect(repo.calls.where((x) => x == 'userPosts:sara:'), hasLength(1));
    c
        .read(postEditsProvider.notifier)
        .put(testPost('p2').copyWithForTest(pinned: true));
    await c.read(profileGridProvider(key).future);
    expect(repo.calls.where((x) => x == 'userPosts:sara:'), hasLength(2));
  });

  group('screens', () {
    Future<(FakePostsRepository, GoRouter)> pump(
      WidgetTester tester,
      FakePostsRepository repo, {
      AppLanguage language = AppLanguage.en,
    }) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) =>
                    switch (ref.watch(homePostsProvider(HomeFeed.trending))) {
                      AsyncValue(value: FeedItems(:final items)) => ListView(
                        children: [
                          for (final p in items)
                            FeedPostTile(key: ValueKey(p.postId), post: p),
                        ],
                      ),
                      _ => const SizedBox.shrink(),
                    },
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.editPostPattern,
            builder: (_, s) =>
                EditPostScreen(postId: s.pathParameters['postId']!),
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

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(FeedPostTile.moreKey).first);
      await tester.pumpAndSettle();
    }

    testWidgets("others' posts offer no pin or edit", (tester) async {
      await pump(
        tester,
        FakePostsRepository(
          feeds: {
            PostsFeedTab.trending: [testPost('p1')],
          },
        ),
      );
      await openMenu(tester);
      expect(find.byKey(FeedPostTile.pinActionKey), findsNothing);
      expect(find.byKey(FeedPostTile.editActionKey), findsNothing);
    });

    testWidgets('pin, then unpin; a fourth pin says the limit', (tester) async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [testPost('p1', isSelf: true)],
        },
      );
      await pump(tester, repo);
      await openMenu(tester);
      expect(find.text(_en.feedPostPin), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.pinActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'pin:p1:true');
      expect(find.text(_en.feedPostPinned), findsOneWidget);

      await openMenu(tester);
      expect(find.text(_en.feedPostUnpin), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.pinActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'pin:p1:false');

      repo.pins.addAll(['a', 'b', 'c']);
      await openMenu(tester);
      await tester.tap(find.byKey(FeedPostTile.pinActionKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.errorPinLimitReached), findsOneWidget);
      await openMenu(tester);
      expect(find.text(_en.feedPostPin), findsOneWidget);
    });

    testWidgets('edit: only the caption is sent; the feed shows it, marked '
        'Edited', (tester) async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [
            testPost('p1', isSelf: true, text: 'Old words', photos: 1),
          ],
        },
      );
      await pump(tester, repo);
      expect(find.byKey(FeedPostTile.editedKey), findsNothing);
      await openMenu(tester);
      await tester.tap(find.byKey(FeedPostTile.editActionKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.editPostTitle), findsOneWidget);
      expect(find.text(_en.editPostPhotosFixed), findsOneWidget);

      // Nothing changed: Save is off.
      final save = find.byKey(EditPostScreen.saveKey);
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(find.byKey(EditPostScreen.textKey), 'New words');
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.updates.single.$1, 'p1');
      expect(repo.updates.single.$2, {'text': 'New words'});
      expect(find.text(_en.editPostSaved), findsOneWidget);
      expect(find.byKey(FeedPostTile.editedKey), findsOneWidget);
      expect(
        find.textContaining('New words', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('edit: the place can be removed; a text post cannot be '
        'emptied; leaving with changes asks first', (tester) async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [
            testPost('p1', isSelf: true, text: 'Just text', location: 'Petra'),
          ],
        },
      );
      await pump(tester, repo);
      await openMenu(tester);
      await tester.tap(find.byKey(FeedPostTile.editActionKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(EditPostScreen.textKey), '  ');
      await tester.pumpAndSettle();
      expect(find.text(_en.editPostTextRequired), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byKey(EditPostScreen.saveKey)).onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(EditPostScreen.textKey), 'Just text');
      await tester.tap(find.byKey(EditPostScreen.removePlaceKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.editPostNoPlace), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(_en.editPostDiscardTitle), findsOneWidget);
      await tester.tap(find.text(_en.editPostKeep));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EditPostScreen.saveKey));
      await tester.pumpAndSettle();
      expect(repo.updates.single.$2, {'location': null});
    });

    testWidgets('edit screen: Arabic RTL at 360 dp and text scale 1.3', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [
            testPost('p1', isSelf: true, photos: 3, location: 'البتراء'),
          ],
        },
      );
      final (_, router) = await pump(tester, repo, language: AppLanguage.ar);
      setViewport(tester, GoldenViewport.android);
      unawaited(router.push(AppRoutes.editPost('p1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(EditPostScreen.placeKey), findsOneWidget);
    });
  });
}
