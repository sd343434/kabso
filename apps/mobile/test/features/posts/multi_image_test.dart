// Owner (real phone): "with more than one image the scroll does not work".
// Viewing side: a post with several photos showed only the first one
// (`feedPostOf` kept `media.first` and the tile drew one Image), so there
// was nothing to swipe. These tests drag with real gestures, in Arabic and
// English, on the feed, on the post screen and from the profile grid.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/presentation/post_screen.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final Finder _pager = find.byKey(FeedPostTile.mediaPagerKey);

String _counter(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(FeedPostTile.mediaCounterKey),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// The "next photo" swipe: right to left in English, left to right in
/// Arabic (the reading direction).
Offset _next(AppLanguage language, [double dx = 300]) =>
    Offset(language == AppLanguage.ar ? dx : -dx, 0);

ScrollPosition _verticalOf(WidgetTester tester, Finder inside) {
  final scrollables = find.ancestor(
    of: inside,
    matching: find.byType(Scrollable),
  );
  for (final e in scrollables.evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (state.position.axis == Axis.vertical) return state.position;
  }
  throw StateError('no vertical scrollable');
}

void main() {
  test('feedPostOf keeps every photo in post order; one photo stays a '
      'single image', () {
    final many = feedPostOf(testPost('p1', photos: 3));
    expect(many.gallery, hasLength(3));
    expect(
      [for (final g in many.gallery) (g as NetworkImage).url],
      [
        for (var i = 0; i < 3; i++)
          'https://media.example.test/media/p1-m$i/1080.webp',
      ],
    );
    expect((many.media! as NetworkImage).url, contains('p1-m0'));
    expect(feedPostOf(testPost('p2', photos: 1)).gallery, isEmpty);
  });

  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    group('${language.name}:', () {
      testWidgets('feed: a horizontal swipe changes the photo (counter and '
          'dots), a vertical drag on it still scrolls the feed', (
        tester,
      ) async {
        final repo = FakePostsRepository(
          feeds: {
            PostsFeedTab.trending: [
              testPost('p1', text: 'Four photos', photos: 4),
              testPost('p2', text: 'One photo', photos: 1),
              testPost('p3', text: 'Text only'),
            ],
          },
        );
        setViewport(tester, GoldenViewport.phone);
        await withClock(Clock.fixed(fixtureNow), () async {
          await pumpScreen(
            tester,
            const FeedScreen(),
            language: language,
            postsRepository: repo,
            overrides: [
              secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            ],
          );
          await tester.pumpAndSettle();
        });
        // Only the four-photo post pages; the one-photo post does not.
        expect(_pager, findsOneWidget);
        expect(find.byKey(FeedPostTile.mediaDotsKey), findsOneWidget);
        expect(_counter(tester), '1/4');

        await tester.drag(_pager, _next(language));
        await tester.pumpAndSettle();
        expect(_counter(tester), '2/4');
        await tester.fling(_pager, _next(language), 1500);
        await tester.pumpAndSettle();
        expect(_counter(tester), '3/4');
        // The other way goes back.
        await tester.drag(_pager, -_next(language));
        await tester.pumpAndSettle();
        expect(_counter(tester), '2/4');

        // A vertical drag that starts on the photo scrolls the feed and
        // leaves the photo where it was.
        final feed = _verticalOf(tester, _pager);
        expect(feed.pixels, 0);
        await tester.drag(_pager, const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(feed.pixels, greaterThan(100));
        expect(_counter(tester), '2/4');
        // No like from any of these drags.
        expect(repo.calls.where((c) => c.startsWith('like:')), isEmpty);
      });

      testWidgets('post screen: swipes to the last photo and stops there; a '
          'double tap likes, a second one does not unlike', (tester) async {
        final repo = FakePostsRepository(
          feeds: {
            PostsFeedTab.trending: [testPost('p1', text: 'Trip', photos: 3)],
          },
        );
        setViewport(tester, GoldenViewport.phone);
        await withClock(Clock.fixed(fixtureNow), () async {
          await pumpScreen(
            tester,
            const PostScreen(postId: 'p1'),
            language: language,
            postsRepository: repo,
            overrides: [
              secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            ],
          );
          await tester.pumpAndSettle();
        });
        expect(_counter(tester), '1/3');
        for (var i = 0; i < 4; i++) {
          await tester.fling(_pager, _next(language), 1500);
          await tester.pumpAndSettle();
        }
        expect(_counter(tester), '3/3');

        Future<void> doubleTap() async {
          await tester.tap(_pager);
          await tester.pump(const Duration(milliseconds: 60));
          await tester.tap(_pager);
          await tester.pump();
        }

        await doubleTap();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(FeedPostTile.likeBurstKey), findsOneWidget);
        await tester.pumpAndSettle();
        expect(repo.calls, contains('like:p1:true'));
        await doubleTap();
        await tester.pumpAndSettle();
        expect(repo.calls.where((c) => c.startsWith('like:')), [
          'like:p1:true',
        ]);
        // The heart in the action row is a button that still unlikes.
        await tester.tap(find.byKey(FeedPostTile.likeKey));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('like:p1:false'));
        expect(_counter(tester), '3/3');
      });

      testWidgets('profile grid → post: the multi-photo cell opens a post '
          'that swipes', (tester) async {
        final repo = FakePostsRepository();
        repo.profilePosts['sara'] = [testPost('p1', text: 'Album', photos: 5)];
        final router = GoRouter(
          initialLocation: '/grid',
          routes: [
            GoRoute(
              path: '/grid',
              builder: (_, _) => const Scaffold(
                body: CustomScrollView(
                  slivers: [
                    ProfileGrid(username: 'sara', tab: ProfileTab.posts),
                  ],
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
        await tester.tap(find.byKey(ProfileGrid.cellKey('p1')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.post('p1'));
        expect(_counter(tester), '1/5');
        await tester.drag(_pager, _next(language));
        await tester.pumpAndSettle();
        await tester.drag(_pager, _next(language));
        await tester.pumpAndSettle();
        expect(_counter(tester), '3/5');
        final page = tester.widget<PageView>(_pager).controller!.page!.round();
        expect(page, 2);
      });
    });
  }
}
