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
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
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

/// Where the header row starts: the status bar inset plus the D142 gap.
double _topInset(WidgetTester tester) =>
    KTopInset.of(tester.element(find.byType(FeedScreen)));

/// The mode on screen: only Reels has feed tabs (D218: Posts has one feed,
/// the server's mix, and a top bar with the person and three discs).
HomeTab _mode(WidgetTester tester) =>
    find.byKey(FeedScreen.tabsKey).evaluate().isEmpty
    ? HomeTab.posts
    : HomeTab.reels;

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
    // D218: Posts lists the server's 1 Following : 2 Trending mix.
    homeMixedPostsProvider.overrideWith((ref) {
      count('posts.mixed');
      return FeedItems<FeedPostData>(
        posts ?? [for (var i = 0; i < postCopies; i++) ...feedPosts(language)],
      );
    }),
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
  Brightness brightness = Brightness.dark,
}) async {
  setViewport(tester, viewport);
  final screen = FeedScreen(initialTab: initialTab, showSearch: showSearch);
  await withClock(Clock.fixed(fixtureNow), () async {
    await pumpScreen(
      tester,
      // D202: the light app theme too (pumpScreen is dark).
      brightness == Brightness.dark
          ? screen
          : Builder(
              builder: (context) => Theme(
                data: buildAppTheme(
                  brightness: brightness,
                  locale: Localizations.localeOf(context),
                ),
                child: screen,
              ),
            ),
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
  // D162 (v1.41-social): reels have an API now. Was "reels are
  // unavailable (no API before M2)": the production provider reads
  // `GET /feed/reels`, never fixtures, and an empty feed is empty.
  test('production providers are honest: reels come from the reels API '
      '(D162), each feed its own tab', () async {
    final posts = FakePostsRepository()
      ..reels[PostsFeedTab.trending] = [testPost('r1', reel: true)];
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        postsRepositoryProvider.overrideWithValue(posts),
        currentUserProvider.overrideWithValue(testUser()),
      ],
    );
    final trending = await container.read(
      homeReelsProvider(HomeFeed.trending).future,
    );
    final items = (trending as FeedItems<FeedReelData>).items;
    expect([for (final r in items) r.postId], ['r1']);
    expect(items.single.videoUrl, endsWith('/video.mp4'));
    final following = await container.read(
      homeReelsProvider(HomeFeed.following).future,
    );
    expect((following as FeedItems<FeedReelData>).items, isEmpty);
    expect(posts.calls, containsAll(['reels:trending:', 'reels:following:']));
    expect(posts.calls.where((c) => c.startsWith('feed:')), isEmpty);
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

  test('KL-060 / D218: production posts come from the posts API (the '
      'page reads tab=mixed), as real (interactive) posts', () async {
    final repo = FakePostsRepository(
      feeds: {
        PostsFeedTab.trending: [testPost('p1', likes: 3, liked: true)],
        PostsFeedTab.following: const [],
        PostsFeedTab.mixed: [
          testPost('m1', viewerFollowsAuthor: true),
          testPost('m2', viewerFollowsAuthor: false),
        ],
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
    final mixed = await container.read(homeMixedPostsProvider.future);
    final mix = (mixed as FeedItems<FeedPostData>).items;
    expect([for (final p in mix) p.postId], ['m1', 'm2']);
    // The card's «متابعة» pill and «مقترح لك» read the server's flag.
    expect([for (final p in mix) p.isFollowingAuthor], [true, false]);
    expect(repo.calls, ['feed:trending:', 'feed:following:', 'feed:mixed:']);
  });

  group('header (D218)', () {
    testWidgets('the person (avatar, name, handle) at the reading start, '
        'then Search, the bell and «Reels» as 36 dp discs in 48 dp targets; '
        'no feed tabs, no Create, no messages icon', (tester) async {
      await _pump(
        tester,
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      final me = testUser();
      final header = tester.getRect(find.byKey(FeedScreen.headerKey));
      expect(header.height, _topInset(tester) + KPostsTopBar.height);
      expect(_mode(tester), HomeTab.posts);
      expect(find.byKey(FeedScreen.tabsKey), findsNothing);
      expect(find.text(me.displayName), findsOneWidget);
      expect(find.text(KHandle.isolated(me.username)), findsOneWidget);
      final search = tester.getRect(find.byKey(FeedScreen.searchKey));
      final bell = tester.getRect(find.byKey(NotificationsBell.bellKey));
      final reels = tester.getRect(find.byKey(FeedScreen.switchKey));
      for (final r in [search, bell, reels]) {
        expect(r.size, const Size.square(KSizes.minTouchTarget));
      }
      expect(search.right, lessThanOrEqualTo(bell.left));
      expect(bell.right, lessThanOrEqualTo(reels.left));
      expect(reels.right, moreOrLessEquals(393 - KSpacing.sm));
      expect(find.byTooltip(_en.homeShowReels), findsOneWidget);
      expect(find.byTooltip(_en.navCreate), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      // KL-060: the posts API with no posts yet.
      expect(find.text(_en.homeEmptyTitle), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('real fonts, ${language.name} ${viewport.name}: the '
            'name and handle shrink before the discs move', (tester) async {
          await loadAppFonts();
          await _pump(
            tester,
            language: language,
            viewport: viewport,
            overrides: [
              currentUserProvider.overrideWithValue(
                testUser().copyWith(
                  displayName: 'A very long display name for the bar',
                ),
              ),
            ],
          );
          final width =
              tester.view.physicalSize.width / tester.view.devicePixelRatio;
          final reels = tester.getRect(find.byKey(FeedScreen.switchKey));
          final me = tester.getRect(find.byKey(const Key('home.posts.me')));
          final search = tester.getRect(find.byKey(FeedScreen.searchKey));
          if (language == AppLanguage.ar) {
            expect(reels.left, moreOrLessEquals(KSpacing.sm));
            expect(me.left, greaterThanOrEqualTo(search.right));
            expect(me.right, lessThanOrEqualTo(width - KSpacing.lg + 0.5));
          } else {
            expect(reels.right, moreOrLessEquals(width - KSpacing.sm));
            expect(me.right, lessThanOrEqualTo(search.left));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the person opens their own profile', (tester) async {
      await _pump(
        tester,
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      expect(
        find.bySemanticsLabel(_en.postsTopBarMe(testUser().displayName)),
        findsOneWidget,
      );
    });
  });

  group('switching', () {
    testWidgets('the switch toggles Posts and Reels, their title, copy and '
        'its own label', (tester) async {
      await _pump(tester);
      await _switch(tester);
      expect(_mode(tester), HomeTab.reels);
      // D162: reels have an API (empty here), so the empty copy.
      expect(find.text(_en.homeReelsEmptyTitle), findsOneWidget);
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
      // D218: Posts' «Reels» is a disc (its tooltip names it).
      expect(find.byTooltip(_en.homeShowReels), findsOneWidget);
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
      await _switch(tester);
      await _selectFeed(tester, _en.feedTabFollowing);
      // D202: Reels names Trending «For You» (the reels page's tabs).
      await _selectFeed(tester, _en.reelsTabForYou);
      await _switch(tester);
      expect(_scroll(tester, HomeTab.posts).pixels, offset);
      expect(calls, {
        'posts.mixed': 1,
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
      // D202: a reel shows its author's handle (`@layla`), not the name.
      final reels = feedReels(AppLanguage.en);
      Finder handle(int i) => find.text(KHandle.ltr(reels[i].handle));
      expect(handle(0), findsOneWidget);
      await tester.fling(
        find.byType(HomeReelsPager).first,
        const Offset(0, -500),
        1500,
      );
      await tester.pumpAndSettle();
      expect(handle(1), findsOneWidget);
      await _switch(tester);
      await _switch(tester);
      expect(handle(1), findsOneWidget);
      expect(handle(0), findsNothing);
    });
  });

  group('feeds (D53, Reels only since D218)', () {
    testWidgets('Reels · Following shows its own feed; the selected feed is '
        'kept across a mode switch', (tester) async {
      await _pump(
        tester,
        initialTab: HomeTab.reels,
        overrides: _populated(AppLanguage.en),
      );
      await _selectFeed(tester, _en.feedTabFollowing);
      expect(_selected(tester, _en.feedTabFollowing), isTrue);
      // Reels · Following starts with the last reel of the fixture (no
      // username: its name is shown).
      expect(find.text('Hind'), findsOneWidget);
      await _switch(tester);
      expect(_mode(tester), HomeTab.posts);
      await _switch(tester);
      expect(_selected(tester, _en.feedTabFollowing), isTrue);
      // D202: Reels' Trending is «For You»; a reel shows the handle.
      await _selectFeed(tester, _en.reelsTabForYou);
      expect(find.text(KHandle.ltr('@layla')), findsOneWidget);
    });

    testWidgets('reels · Following with nothing to show: its own copy and '
        '"See who\'s live"', (tester) async {
      await _pump(tester, initialTab: HomeTab.reels);
      await _selectFeed(tester, _en.feedTabFollowing);
      expect(find.text(_en.homeReelsFollowingEmptyTitle), findsOneWidget);
      expect(find.text(_en.homeSeeWhoIsLive), findsOneWidget);
      expect(find.text(_en.homeWatchLive), findsNothing);
    });
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
    testWidgets('stories tray above flat, full-width posts (D54; D218 '
        'order): author, caption (no name before it), time, edge-to-edge '
        'media with the video mark, then the action row', (tester) async {
      await _pump(tester, overrides: _populated(AppLanguage.en));
      final tray = find.byKey(FeedStoriesTray.trayKey);
      expect(tray, findsOneWidget);
      final stories = feedStories(AppLanguage.en);
      expect(
        find.descendant(of: tray, matching: find.byType(KAvatar)),
        findsNWidgets(stories.length),
      );
      final first = find.byType(FeedPostTile).first;
      expect(
        tester.getRect(tray).bottom,
        lessThanOrEqualTo(tester.getRect(first).top),
      );
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
      expect(name.bottom, lessThanOrEqualTo(time.top));
      expect(time.bottom, lessThanOrEqualTo(media.top));
      expect(counts.top, greaterThanOrEqualTo(media.bottom));
      // D218: the caption no longer repeats the author's name.
      expect(
        find.descendant(
          of: first,
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText && w.text.toPlainText().startsWith('First time'),
          ),
        ),
        findsWidgets,
      );
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
        _topInset(tester) + KPostsTopBar.height,
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
        // D218: no name before the caption; «… المزيد» / "… more".
        expect(plain, endsWith('… ${l10n.feedPostSeeMore}'));
        final shown = plain.substring(
          0,
          plain.length - 2 - l10n.feedPostSeeMore.length,
        );
        expect(shown.length, lessThan(long.length));
        // Cut at a word boundary.
        expect(long.startsWith(shown), isTrue);
        expect(long.substring(shown.length), startsWith(' '));
        // One caption line: the short post's caption.
        final line = tester
            .getSize(
              find.byWidgetPredicate(
                (w) => w is RichText && w.text.toPlainText() == 'Short',
              ),
            )
            .height;
        expect(collapsed, moreOrLessEquals(2 * line, epsilon: 1));
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(more, findsNothing);
        final full = find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == long,
        );
        expect(full, findsOneWidget);
        expect(tester.getSize(full).height, greaterThan(collapsed));
      });
    }
  });

  group('Reels', () {
    // D202 (owner reference): was "below the app-themed header, author,
    // time and caption". The reels page is now full bleed and dark in both
    // themes, under a floating header; a reel shows the handle, caption and
    // the sound line (no time).
    for (final brightness in Brightness.values) {
      testWidgets('full bleed and dark under the floating header '
          '(${brightness.name} app theme); handle, caption, sound line', (
        tester,
      ) async {
        await _pump(
          tester,
          initialTab: HomeTab.reels,
          overrides: _populated(AppLanguage.en),
          brightness: brightness,
        );
        final page = tester.getRect(find.byType(HomeReelPage).first);
        expect(page, const Rect.fromLTWH(0, 0, 393, 852));
        final header = tester.getRect(find.byKey(FeedScreen.headerKey));
        expect(header.top, 0);
        final label = find.descendant(
          of: _feedTab(_en.reelsTabForYou),
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
        expect(find.text(KHandle.ltr('@layla')), findsOneWidget);
        expect(find.text(_en.relativeDaysAgo(2)), findsNothing);
        expect(find.textContaining('evening walk'), findsOneWidget);
        expect(find.text(_en.reelsOriginalSound('Layla')), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^${_en.homeReelBy('Layla')}')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      });
    }

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
          matching: find.text(_en.navMoments),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(_mode(tester), HomeTab.posts);
      // D218: the person's own name at the top of Posts.
      expect(find.text(testUser().displayName), findsWidgets);
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
      // D162: ➕ opens the menu; «منشور» (Post) opens Create.
      await tester.tap(
        find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
      );
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
