// D52: the Reels shell tab — header (Search, title, Posts/Reels switch next
// to Create), button-only switching, kept scroll position and pager page,
// no re-fetch on a switch, post cards and the stories tray, full-bleed
// Reels, honest production providers, states, RTL/LTR and small screens.
// Live hub tabs: test/features/home_live/feed_screens_test.dart.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

double _topInset(WidgetTester tester) =>
    MediaQuery.paddingOf(tester.element(find.byType(FeedScreen))).top;

/// The mode on screen, read from the switch word (it names the other mode).
HomeTab _mode(WidgetTester tester) {
  final word = tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(FeedScreen.switchKey),
          matching: find.byType(Text),
        ),
      )
      .data;
  final posts = {for (final l in AppLanguage.values) l10nFor(l).homeTabPosts};
  return posts.contains(word) ? HomeTab.reels : HomeTab.posts;
}

Finder _feedTab(String label) => find.descendant(
  of: find.byKey(FeedScreen.tabsKey),
  matching: find.text(label),
);

bool _selected(WidgetTester tester, String label) =>
    tester.getSemantics(_feedTab(label)).flagsCollection.isSelected ==
    Tristate.isTrue;

Future<void> _selectFeed(WidgetTester tester, String label) async {
  await tester.tap(_feedTab(label));
  await tester.pumpAndSettle();
}

/// Every source populated; [calls] counts provider builds per source
/// (`posts.trending`, `reels.following`, `stories`, …). Following gets a
/// shorter list than Trending, so the two are told apart.
List<Override> _populated(
  AppLanguage language, {
  Map<String, int>? calls,
  int postCopies = 1,
  List<FeedPostData>? posts,
  bool stories = true,
}) {
  void count(String source) =>
      calls?.update(source, (n) => n + 1, ifAbsent: () => 1);
  return [
    homePostsProvider.overrideWith((ref, feed) {
      count('posts.${feed.name}');
      final all =
          posts ??
          [for (var i = 0; i < postCopies; i++) ...feedPosts(language)];
      return FeedItems<FeedPostData>(
        feed == HomeFeed.trending ? all : all.sublist(1),
      );
    }),
    homeStoriesProvider.overrideWith((ref) {
      count('stories');
      return stories
          ? FeedItems<FeedStoryData>(feedStories(language))
          : const FeedUnavailable<FeedStoryData>();
    }),
    homeReelsProvider.overrideWith((ref, feed) {
      count('reels.${feed.name}');
      final reels = feedReels(language);
      return FeedItems<FeedReelData>(
        feed == HomeFeed.trending ? reels : reels.reversed.toList(),
      );
    }),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<Override> overrides = const [],
  HomeTab initialTab = HomeTab.initial,
  GoldenViewport viewport = GoldenViewport.phone,
  bool showSearch = true,
}) async {
  setViewport(tester, viewport);
  await withClock(Clock.fixed(fixtureNow), () async {
    await pumpScreen(
      tester,
      FeedScreen(initialTab: initialTab, showSearch: showSearch),
      language: language,
      overrides: overrides,
    );
    await tester.pumpAndSettle();
  });
}

/// Taps the Posts/Reels switch.
Future<void> _switch(WidgetTester tester) async {
  // With large text the words scroll; bring the switch word into view.
  await tester.ensureVisible(find.byKey(FeedScreen.switchKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(FeedScreen.switchKey));
  await tester.pumpAndSettle();
}

ScrollPosition _scroll(WidgetTester tester, HomeTab tab) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(FeedScreen.pageKey(tab)),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  test('production providers are honest: reels are unavailable (no API '
      'before M2)', () {
    final container = ProviderContainer.test();
    for (final feed in HomeFeed.values) {
      expect(
        container.read(homeReelsProvider(feed)).value,
        isA<FeedUnavailable<FeedReelData>>(),
      );
    }
  });

  test('CP-008: stories come from the stories API — your entry first ("add" '
      'when you have none), then the tray in order; a failed tray is '
      'unavailable, never fixtures', () async {
    final stories = FakeStoriesRepository()
      ..trayItems = [testTrayItem('sara'), testTrayItem('omar', unseen: false)];
    final me = testUser();
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        storiesRepositoryProvider.overrideWithValue(stories),
        currentUserProvider.overrideWithValue(me),
      ],
    )..listen(homeStoriesProvider, (_, _) {});
    final load = await container.read(homeStoriesProvider.future);
    final items = (load as FeedItems<FeedStoryData>).items;
    expect([for (final s in items) s.username], [me.username, 'sara', 'omar']);
    expect(items.first.isSelf, isTrue);
    expect(items.first.hasStory, isFalse);
    expect([for (final s in items) s.seen], [false, false, true]);

    // Your own active story: your entry has a story.
    stories.trayItems = [testTrayItem(me.username, id: me.id, unseen: false)];
    container.invalidate(storyTrayProvider);
    final mine = await container.read(homeStoriesProvider.future);
    expect((mine as FeedItems<FeedStoryData>).items.single.hasStory, isTrue);

    stories.failWith = const NetworkFailure.offline();
    container.invalidate(storyTrayProvider);
    expect(
      await container.read(homeStoriesProvider.future),
      isA<FeedUnavailable<FeedStoryData>>(),
    );
  });

  test('KL-060: production posts come from the posts API, per feed, as '
      'real (interactive) posts', () async {
    final repo = FakePostsRepository(
      feeds: {
        PostsFeedTab.trending: [testPost('p1', likes: 3, liked: true)],
        PostsFeedTab.following: const [],
      },
    );
    final container = ProviderContainer.test(
      overrides: [
        postsRepositoryProvider.overrideWithValue(repo),
        // Feeds are scoped to the signed-in user: no platform storage.
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    final trending = await container.read(
      homePostsProvider(HomeFeed.trending).future,
    );
    final items = (trending as FeedItems<FeedPostData>).items;
    expect(items.single.postId, 'p1');
    expect(items.single.likes, 3);
    expect(items.single.liked, isTrue);
    expect(trending.hasMore, isFalse);
    final following = await container.read(
      homePostsProvider(HomeFeed.following).future,
    );
    expect((following as FeedItems<FeedPostData>).items, isEmpty);
    expect(repo.calls, ['feed:trending:', 'feed:following:']);
  });

  group('header', () {
    testWidgets('48 dp: Trending · Following · "Reels" centred (Trending '
        'selected; the third word switches mode); no Create (the '
        'bottom bar has it); Search at the start (D55)', (tester) async {
      await _pump(tester);
      expect(find.byKey(FeedScreen.searchKey), findsOneWidget);
      expect(find.byTooltip(_en.feedSearch), findsOneWidget);
      final header = tester.getRect(find.byKey(FeedScreen.headerKey));
      expect(header.height, _topInset(tester) + KMetrics.topBarHeight);
      expect(_mode(tester), HomeTab.posts);
      expect(_selected(tester, _en.homeFeedTrending), isTrue);
      expect(_selected(tester, _en.feedTabFollowing), isFalse);
      final trending = tester.getRect(_feedTab(_en.homeFeedTrending));
      final following = tester.getRect(_feedTab(_en.feedTabFollowing));
      final word = find.byKey(FeedScreen.switchKey);
      expect(trending.right, lessThan(following.left));
      expect(following.right, lessThan(tester.getRect(word).left));
      expect(
        find.descendant(of: word, matching: find.text(_en.homeTabReels)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(_en.homeShowReels), findsOneWidget);
      expect(
        tester.getSize(word).height,
        greaterThanOrEqualTo(KSizes.minTouchTarget),
      );
      // The words fill the space between equal side insets: centred on
      // the screen.
      final tabs = tester.getRect(find.byKey(FeedScreen.tabsKey));
      expect(tabs.center.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
      // The icon buttons are Search (start) and, since CP-009, the
      // notifications bell (end), each a 48 dp target in an equal inset.
      expect(
        find.descendant(
          of: find.byKey(FeedScreen.headerKey),
          matching: find.byType(IconButton),
        ),
        findsNWidgets(2),
      );
      final bell = tester.getRect(find.byKey(NotificationsBell.bellKey));
      expect(bell.size, const Size.square(KSizes.minTouchTarget));
      expect(bell.right, moreOrLessEquals(393 - KSpacing.xs));
      expect(bell.left, greaterThanOrEqualTo(tabs.right));
      expect(find.byTooltip(_en.navCreate), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(KLogo), findsNothing);
      // KL-060: the posts API with no posts yet.
      expect(find.text(_en.homeEmptyTitle), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('mirrors in ${language.name}: Search at the '
          'reading start; Trending, Following, then the switch word in the '
          'reading order', (tester) async {
        await _pump(tester, language: language);
        final l10n = l10nFor(language);
        final trending = tester.getCenter(_feedTab(l10n.homeFeedTrending)).dx;
        final following = tester.getCenter(_feedTab(l10n.feedTabFollowing)).dx;
        expect(
          trending < following,
          language == AppLanguage.en,
          reason: 'Trending at the reading start',
        );
        expect(
          tester.getSize(find.byKey(FeedScreen.searchKey)),
          const Size.square(KSizes.minTouchTarget),
        );
        expect(find.byTooltip(l10nFor(language).feedSearch), findsOneWidget);
        final search = tester.getCenter(find.byKey(FeedScreen.searchKey)).dx;
        final word = tester.getCenter(find.byKey(FeedScreen.switchKey)).dx;
        const edge = KSpacing.xs + KSizes.minTouchTarget / 2;
        if (language == AppLanguage.ar) {
          expect(search, 393 - edge);
          expect(word, lessThan(following));
        } else {
          expect(search, edge);
          expect(word, greaterThan(following));
        }
      });
    }
  });

  group('switching', () {
    testWidgets('the switch toggles Posts and Reels, their title, copy and '
        'its own label', (tester) async {
      await _pump(tester);
      await _switch(tester);
      expect(_mode(tester), HomeTab.reels);
      expect(find.text(_en.homeReelsUnavailableTitle), findsOneWidget);
      expect(find.bySemanticsLabel(_en.homeShowPosts), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(FeedScreen.switchKey),
          matching: find.text(_en.homeTabPosts),
        ),
        findsOneWidget,
      );
      await _switch(tester);
      expect(_mode(tester), HomeTab.posts);
      expect(find.text(_en.homeEmptyTitle), findsOneWidget);
      expect(find.bySemanticsLabel(_en.homeShowReels), findsOneWidget);
    });

    testWidgets('a horizontal swipe does not switch', (tester) async {
      await _pump(tester, overrides: _populated(AppLanguage.en));
      for (final dx in [-300.0, 300.0]) {
        await tester.fling(
          find.byKey(FeedScreen.pageKey(HomeTab.posts)),
          Offset(dx, 0),
          1500,
        );
        await tester.pumpAndSettle();
        expect(_mode(tester), HomeTab.posts);
        expect(_selected(tester, _en.homeFeedTrending), isTrue);
      }
    });

    testWidgets('Posts keeps its scroll position, and switching never '
        're-fetches', (tester) async {
      final calls = <String, int>{};
      await _pump(
        tester,
        overrides: _populated(AppLanguage.en, calls: calls, postCopies: 4),
      );
      await tester.drag(
        find.byKey(FeedScreen.pageKey(HomeTab.posts)),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      final offset = _scroll(tester, HomeTab.posts).pixels;
      expect(offset, greaterThan(100));

      await _switch(tester);
      await _switch(tester);
      expect(_scroll(tester, HomeTab.posts).pixels, offset);
      // One build per source, however often the modes and feeds switch.
      await _selectFeed(tester, _en.feedTabFollowing);
      await _switch(tester);
      await _selectFeed(tester, _en.homeFeedTrending);
      await _switch(tester);
      expect(_scroll(tester, HomeTab.posts).pixels, offset);
      expect(calls, {
        'posts.trending': 1,
        'posts.following': 1,
        'stories': 1,
        'reels.trending': 1,
        'reels.following': 1,
      });
    });

    testWidgets('the reels pager keeps its page across switches', (
      tester,
    ) async {
      await _pump(
        tester,
        initialTab: HomeTab.reels,
        overrides: _populated(AppLanguage.en),
      );
      final reels = feedReels(AppLanguage.en);
      expect(find.text(reels[0].authorName), findsOneWidget);
      await tester.fling(
        find.byType(HomeReelsPager),
        const Offset(0, -500),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.text(reels[1].authorName), findsOneWidget);
      await _switch(tester);
      await _switch(tester);
      expect(find.text(reels[1].authorName), findsOneWidget);
      expect(find.text(reels[0].authorName), findsNothing);
    });
  });

  group('feeds (D53)', () {
    testWidgets('Following shows its own feed; the selected feed is kept '
        'across a mode switch', (tester) async {
      await _pump(tester, overrides: _populated(AppLanguage.en));
      final cards = find.byType(FeedPostTile);
      expect(find.text('Sara'), findsWidgets);
      await _selectFeed(tester, _en.feedTabFollowing);
      expect(_selected(tester, _en.feedTabFollowing), isTrue);
      expect(
        find.descendant(of: cards, matching: find.text('Sara')),
        findsNothing,
      );
      await _switch(tester);
      expect(_mode(tester), HomeTab.reels);
      expect(_selected(tester, _en.feedTabFollowing), isTrue);
      // Reels · Following starts with the last reel of the fixture.
      expect(find.text('Hind'), findsOneWidget);
      await _selectFeed(tester, _en.homeFeedTrending);
      expect(find.text('Layla'), findsOneWidget);
    });

    testWidgets('each feed keeps its own scroll position', (tester) async {
      await _pump(tester, overrides: _populated(AppLanguage.en, postCopies: 4));
      await tester.drag(
        find.byKey(FeedScreen.pageKey(HomeTab.posts)),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      final trending = _scroll(tester, HomeTab.posts).pixels;
      await _selectFeed(tester, _en.feedTabFollowing);
      expect(_scroll(tester, HomeTab.posts).pixels, 0);
      await _selectFeed(tester, _en.homeFeedTrending);
      expect(_scroll(tester, HomeTab.posts).pixels, trending);
    });

    for (final (tab, title) in [
      // KL-060: posts have an API (empty here); reels do not yet.
      (HomeTab.posts, _en.homeFollowingEmptyTitle),
      (HomeTab.reels, _en.homeReelsFollowingUnavailableTitle),
    ]) {
      testWidgets(
        '${tab.name} · Following with nothing to show: its own copy and '
        '"See who\'s live"',
        (tester) async {
          await _pump(tester, initialTab: tab);
          await _selectFeed(tester, _en.feedTabFollowing);
          expect(find.text(title), findsOneWidget);
          expect(find.text(_en.homeSeeWhoIsLive), findsOneWidget);
          expect(find.text(_en.homeWatchLive), findsNothing);
        },
      );
    }
  });

  group('reel rail (D53)', () {
    Future<FakeProfileRepository> pumpReels(
      WidgetTester tester, {
      AppFailure? followFailure,
    }) async {
      final repo = FakeProfileRepository(apiProfile())
        ..followFailure = followFailure;
      await _pump(
        tester,
        initialTab: HomeTab.reels,
        overrides: [
          ..._populated(AppLanguage.en),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      return repo;
    }

    testWidgets('photo with the follow badge, then display-only counts at '
        'the bottom end; the caption stops before the rail', (tester) async {
      await pumpReels(tester);
      final rail = find.byKey(HomeReelPage.railKey).first;
      final railRect = tester.getRect(rail);
      expect(railRect.right, lessThanOrEqualTo(393 - KSpacing.sm));
      expect(railRect.left, greaterThan(393 / 2));
      expect(
        find.bySemanticsLabel(_en.feedPostCounts('432K', '1,230', '980')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.byType(IconButton)),
        findsNothing,
      );
      final caption = tester.getRect(find.textContaining('evening walk'));
      expect(caption.right, lessThan(railRect.left));
      final badge = find.byKey(ReelFollowBadge.badgeKey);
      expect(badge, findsOneWidget);
      expect(tester.getSize(badge), const Size.square(KSizes.minTouchTarget));
      expect(find.bySemanticsLabel(_en.homeFollowAuthor('Layla')), findsOne);
    });

    testWidgets('Follow calls the follow API and turns into a check', (
      tester,
    ) async {
      final repo = await pumpReels(tester);
      await tester.tap(find.byKey(ReelFollowBadge.badgeKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT layla']);
      expect(
        find.bySemanticsLabel(_en.homeFollowingAuthor('Layla')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ReelFollowBadge.badgeKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT layla']);
    });

    testWidgets('a failed follow comes back with a message', (tester) async {
      final repo = await pumpReels(
        tester,
        followFailure: const NetworkFailure.offline(),
      );
      await tester.tap(find.byKey(ReelFollowBadge.badgeKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT layla']);
      expect(find.bySemanticsLabel(_en.homeFollowAuthor('Layla')), findsOne);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('no badge for an author already followed or unknown', (
      tester,
    ) async {
      await pumpReels(tester);
      for (var i = 0; i < 2; i++) {
        await tester.fling(
          find.byType(HomeReelsPager),
          const Offset(0, -500),
          1500,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ReelFollowBadge.badgeKey), findsNothing);
      }
    });
  });

  group('Posts', () {
    testWidgets('stories tray above flat, full-width posts (D54): author, '
        'edge-to-edge media with the video mark, display-only action row, '
        'caption led by the name, then the time', (tester) async {
      await _pump(tester, overrides: _populated(AppLanguage.en));
      final tray = find.byKey(FeedStoriesTray.trayKey);
      expect(tray, findsOneWidget);
      final stories = feedStories(AppLanguage.en);
      expect(
        find.descendant(of: tray, matching: find.byType(KAvatar)),
        findsNWidgets(stories.length),
      );
      final first = find.byType(FeedPostTile).first;
      expect(tester.getRect(tray).bottom, lessThan(tester.getRect(first).top));
      final post = tester.getRect(first);
      expect(post.left, 0);
      expect(post.right, 393);
      final media = tester.getRect(
        find.descendant(of: first, matching: find.byType(Image)).last,
      );
      expect(media.left, 0);
      expect(media.width, 393);
      final name = tester.getRect(
        find.descendant(of: first, matching: find.text('Sara')),
      );
      final counts = tester.getRect(
        find.descendant(
          of: first,
          matching: find.byKey(FeedPostTile.countsKey),
        ),
      );
      final time = tester.getRect(find.text(_en.relativeMinutesAgo(12)));
      expect(name.bottom, lessThanOrEqualTo(media.top));
      expect(counts.top, greaterThanOrEqualTo(media.bottom));
      expect(time.top, greaterThan(counts.bottom));
      // The caption starts with the author's name.
      final caption = tester.widget<RichText>(
        find
            .descendant(
              of: first,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is RichText &&
                    w.text.toPlainText().startsWith('Sara First time'),
              ),
            )
            .first,
      );
      expect(caption.text.toPlainText(), startsWith('Sara '));
      expect(
        find.bySemanticsLabel(_en.feedPostCounts('105', '15', '50')),
        findsOneWidget,
      );
      // The text-only post (no counts from the API) has no counter row.
      final textOnly = find.ancestor(
        of: find.text('عمر'),
        matching: find.byType(FeedPostTile),
      );
      expect(
        find.descendant(
          of: textOnly,
          matching: find.byKey(FeedPostTile.countsKey),
        ),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(FeedPostTile.videoMarkKey),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(FeedScreen.pageKey(HomeTab.posts)),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(FeedPostTile.videoMarkKey), findsOneWidget);
      expect(find.bySemanticsLabel(_en.feedPostVideo), findsOneWidget);
      expect(find.byKey(FeedPostTile.countsKey), findsNWidgets(2));
      // Counts and the video mark are not buttons (no APIs yet): the only
      // buttons are the three dots of posts with a known follow state.
      expect(
        find.descendant(
          of: find.byKey(FeedScreen.pageKey(HomeTab.posts)),
          matching: find.byType(IconButton),
        ),
        findsNWidgets(find.byKey(FeedPostTile.moreKey).evaluate().length),
      );
      expect(
        find.descendant(
          of: find.byKey(FeedPostTile.countsKey).first,
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    Future<FakeProfileRepository> pumpPosts(
      WidgetTester tester, {
      AppFailure? followFailure,
      bool following = false,
    }) async {
      final repo = FakeProfileRepository(apiProfile(isFollowing: following))
        ..followFailure = followFailure;
      await _pump(
        tester,
        overrides: [
          ..._populated(
            AppLanguage.en,
            posts: [
              FeedPostData(
                authorName: 'Sara',
                authorUsername: 'sara',
                isFollowingAuthor: following,
                postedAt: fixtureNow,
                text: 'Hello',
              ),
              FeedPostData(
                authorName: 'Omar',
                postedAt: fixtureNow,
                text: 'No follow data',
              ),
            ],
          ),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );
      return repo;
    }

    Future<void> openMore(WidgetTester tester) async {
      await tester.tap(find.byKey(FeedPostTile.moreKey));
      await tester.pumpAndSettle();
    }

    testWidgets('the three dots sit at the end of the author row (48 dp, '
        'labelled) only when the follow state is known', (tester) async {
      await pumpPosts(tester);
      final more = find.byKey(FeedPostTile.moreKey);
      expect(more, findsOneWidget);
      expect(tester.getSize(more), const Size.square(KSizes.minTouchTarget));
      expect(tester.getRect(more).right, 393 - KSpacing.xs);
      expect(find.byTooltip(_en.feedPostMore), findsOneWidget);
      final sara = find.ancestor(
        of: find.text('Sara'),
        matching: find.byType(FeedPostTile),
      );
      expect(find.descendant(of: sara, matching: more), findsOneWidget);
    });

    testWidgets('Follow from the menu calls the follow API; the menu then '
        'offers Unfollow, which calls it back', (tester) async {
      final repo = await pumpPosts(tester);
      await openMore(tester);
      expect(find.text(_en.homeFollowAuthor('Sara')), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.followActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT sara']);
      await openMore(tester);
      expect(find.text(_en.homeUnfollowAuthor('Sara')), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.followActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT sara', 'DELETE sara']);
    });

    testWidgets('"Follow" before the dots for an author not followed: it '
        'calls the follow API and goes away; the menu then offers Unfollow', (
      tester,
    ) async {
      final repo = await pumpPosts(tester);
      final follow = find.byKey(FeedPostTile.followKey);
      expect(follow, findsOneWidget);
      expect(
        tester.getSize(follow).height,
        greaterThanOrEqualTo(KSizes.minTouchTarget),
      );
      expect(
        tester.getRect(follow).right,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(FeedPostTile.moreKey)).left,
        ),
      );
      expect(find.bySemanticsLabel(_en.homeFollowAuthor('Sara')), findsOne);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT sara']);
      expect(follow, findsNothing);
      await openMore(tester);
      expect(find.text(_en.homeUnfollowAuthor('Sara')), findsOneWidget);
    });

    testWidgets('no "Follow" for an author already followed or without a '
        'follow state', (tester) async {
      await pumpPosts(tester, following: true);
      expect(find.byKey(FeedPostTile.followKey), findsNothing);
      // Omar has no follow state: no dots either.
      final omar = find.ancestor(
        of: find.text('Omar'),
        matching: find.byType(FeedPostTile),
      );
      expect(
        find.descendant(of: omar, matching: find.byKey(FeedPostTile.moreKey)),
        findsNothing,
      );
    });

    testWidgets('a failed follow comes back with a message', (tester) async {
      final repo = await pumpPosts(
        tester,
        followFailure: const NetworkFailure.offline(),
      );
      await openMore(tester);
      await tester.tap(find.byKey(FeedPostTile.followActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls, ['PUT sara']);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(FeedPostTile.followKey), findsOneWidget);
      await openMore(tester);
      expect(find.text(_en.homeFollowAuthor('Sara')), findsOneWidget);
    });

    testWidgets('no stories source: no tray, the posts start under the '
        'header', (tester) async {
      await _pump(
        tester,
        overrides: _populated(AppLanguage.en, stories: false),
      );
      expect(find.byKey(FeedStoriesTray.trayKey), findsNothing);
      expect(
        tester.getRect(find.byType(FeedPostTile).first).top,
        _topInset(tester) + KMetrics.topBarHeight + KSpacing.xs,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('long text collapses to two lines with "see more", which '
          'expands it in place (${language.name})', (tester) async {
        final l10n = l10nFor(language);
        final long = List.filled(
          12,
          language == AppLanguage.ar ? 'نص تجريبي طويل' : 'long test text',
        ).join(' ');
        await _pump(
          tester,
          language: language,
          overrides: _populated(
            language,
            posts: [
              FeedPostData(
                authorName: 'Sara',
                postedAt: fixtureNow,
                text: long,
              ),
              FeedPostData(
                authorName: 'Omar',
                postedAt: fixtureNow,
                text: 'Short',
              ),
            ],
          ),
        );
        final more = find.byKey(FeedPostTile.seeMoreKey);
        expect(more, findsOneWidget);
        final collapsed = tester.getSize(more).height;
        final rich = tester.widget<RichText>(
          find.descendant(of: more, matching: find.byType(RichText)),
        );
        final plain = rich.text.toPlainText();
        expect(plain, startsWith('Sara '));
        expect(plain, endsWith('… ${l10n.feedSeeMore}'));
        final shown = plain.substring(
          'Sara '.length,
          plain.length - 2 - l10n.feedSeeMore.length,
        );
        expect(shown.length, lessThan(long.length));
        // Cut at a word boundary.
        expect(long.startsWith(shown), isTrue);
        expect(long.substring(shown.length), startsWith(' '));
        // One caption line: the short post's caption.
        final line = tester
            .getSize(
              find.byWidgetPredicate(
                (w) => w is RichText && w.text.toPlainText() == 'Omar Short',
              ),
            )
            .height;
        expect(collapsed, moreOrLessEquals(2 * line, epsilon: 1));
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(more, findsNothing);
        final full = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'Sara $long',
        );
        expect(full, findsOneWidget);
        expect(tester.getSize(full).height, greaterThan(collapsed));
      });
    }
  });

  group('Reels', () {
    testWidgets('full-bleed under a floating dark header, light status bar, '
        'author, time and caption; no play or count controls', (tester) async {
      await _pump(
        tester,
        initialTab: HomeTab.reels,
        overrides: _populated(AppLanguage.en),
      );
      final page = tester.getRect(find.byType(HomeReelPage).first);
      expect(page.top, 0);
      expect(page.width, 393);
      final header = tester.getRect(find.byKey(FeedScreen.headerKey));
      expect(header.top, 0);
      expect(header.overlaps(page), isTrue);
      final label = find.descendant(
        of: _feedTab(_en.homeFeedTrending),
        matching: find.byType(RichText),
      );
      expect(
        tester.widget<RichText>(label).text.style?.color,
        KPalette.dark.textPrimary,
      );
      expect(
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
            )
            .value,
        SystemUiOverlayStyle.light,
      );
      expect(find.text('Layla'), findsOneWidget);
      expect(find.text(_en.relativeDaysAgo(2)), findsOneWidget);
      expect(find.textContaining('evening walk'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^${_en.homeReelBy('Layla')}')),
        findsOneWidget,
      );
      final reelsPage = find.byKey(FeedScreen.pageKey(HomeTab.reels));
      expect(
        find.descendant(of: reelsPage, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('loading shows a skeleton, not a state', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const FeedScreen(initialTab: HomeTab.reels),
        overrides: [
          homeReelsProvider.overrideWith(
            (ref, _) => Completer<FeedLoad<FeedReelData>>().future,
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 400));
      final page = find.byKey(FeedScreen.pageKey(HomeTab.reels));
      expect(
        find.descendant(of: page, matching: find.byType(KSkeleton)),
        findsOneWidget,
      );
      expect(find.byKey(FeedRegion.unavailableKey), findsNothing);
      expect(find.byKey(FeedRegion.emptyKey), findsNothing);
    });

    testWidgets('error: Try again re-runs the load, then shows reels', (
      tester,
    ) async {
      var calls = 0;
      var fail = true;
      const AppFailure failure = NetworkFailure.timeout();
      await _pump(
        tester,
        initialTab: HomeTab.reels,
        overrides: [
          homeReelsProvider.overrideWith((ref, feed) {
            if (feed == HomeFeed.following) {
              return const FeedUnavailable<FeedReelData>();
            }
            calls++;
            if (fail) throw failure;
            return FeedItems<FeedReelData>(feedReels(AppLanguage.en));
          }),
        ],
      );
      expect(find.byKey(FeedRegion.errorKey), findsOneWidget);
      expect(find.text(_en.homeReelsErrorTitle), findsOneWidget);
      fail = false;
      await tester.tap(find.text(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(HomeReelsPager), findsOneWidget);
    });
  });

  group('app shell', () {
    Future<void> openReelsTab(WidgetTester tester) async {
      await pumpKabsoApp(
        tester,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedUser: testUser()),
          ),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
    }

    testWidgets('D48: Home is the live hub; the fourth tab is Reels, opening '
        'on Posts', (tester) async {
      await pumpKabsoApp(
        tester,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedUser: testUser()),
          ),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      await tester.pumpAndSettle();
      final xs = <double>[
        for (final key in const [
          'nav.home',
          'nav.reels',
          'nav.create',
          'nav.messages',
          'nav.profile',
        ])
          tester.getCenter(find.byKey(Key(key))).dx,
      ];
      final sorted = [...xs]..sort();
      expect(xs, orderedEquals(sorted));
      expect(find.byType(LiveScreen), findsOneWidget);
      expect(find.byType(FeedScreen), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('nav.reels')),
          matching: find.text(_en.navPosts),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(_mode(tester), HomeTab.posts);
      expect(_selected(tester, _en.homeFeedTrending), isTrue);
    });

    testWidgets('Search opens Discover (D55)', (tester) async {
      await openReelsTab(tester);
      await tester.tap(find.byKey(FeedScreen.searchKey));
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsNothing);
      expect(find.byType(DiscoverScreen), findsOneWidget);
    });

    testWidgets('Create is reached from the bottom bar, not the header', (
      tester,
    ) async {
      await openReelsTab(tester);
      expect(find.byTooltip(_en.navCreate), findsNothing);
      await tester.tap(find.byKey(const Key('nav.create')));
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsNothing);
      expect(find.byType(CreateScreen), findsOneWidget);
    });
  });

  group('small screens', () {
    for (final language in AppLanguage.values) {
      for (final scale in [1.3, 2.0]) {
        for (final populated in [false, true]) {
          testWidgets('360x800 at $scale, ${language.name}, '
              '${populated ? 'populated' : 'unavailable'}: no overflow in '
              'either mode', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await _pump(
              tester,
              language: language,
              viewport: GoldenViewport.android,
              overrides: populated ? _populated(language) : const [],
            );
            final l10n = l10nFor(language);
            for (final tab in HomeTab.values) {
              if (tab != HomeTab.initial) await _switch(tester);
              expect(_mode(tester), tab);
              expect(tester.takeException(), isNull, reason: '$tab');
              if (!populated) {
                final action = find.descendant(
                  of: find.byKey(FeedScreen.pageKey(tab)),
                  matching: find.text(l10n.homeWatchLive),
                );
                await tester.ensureVisible(action);
                await tester.pumpAndSettle();
                expect(tester.getRect(action).bottom, lessThan(800));
              }
            }
          });
        }
      }
    }
  });
}
