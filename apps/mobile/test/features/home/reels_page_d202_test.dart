// D202 (owner reference, v1.68-social): the reels page — the floating
// header, the real rail (like with double tap and rollback, comments, save,
// share, follow / request), the caption's hashtags and «المزيد», the sound
// line, and both languages at 360×800 ×1.3.
// D294 (v1.92-social, owner: «اجعل فلتر فقط منشورات وريلز»): the header is
// the posts page's bar (Search, «Posts | Reels» with Reels selected, the
// bell); the tabs Following · For You · Nearby, the Posts chip and Nearby's
// country prompt are gone; the page reads `GET /feed/reels?tab=mixed` only.
// D298 (owner: «اجعل الريلز بحجم الشاشة»): the reel fills the whole screen
// from the very top; the header floats over it on a soft scrim that fades
// to nothing (no band), its row under the status bar.

import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/media/inline_video.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/fake_inline_video.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

/// Records what the share sheet was given; [dismiss] answers "dismissed".
class _FakeSharer implements ReelSharer {
  final List<String> texts = [];
  bool dismiss = false;

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    texts.add(text);
    return !dismiss;
  }
}

/// The reels page inside a router whose other routes only say where they
/// are, so taps that navigate can be checked.
class _Routed extends StatelessWidget {
  const new({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return MaterialApp.router(
      routerConfig: router,
      locale: locale,
      supportedLocales: KabsoApp.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildAppTheme(brightness: Brightness.light, locale: locale),
    );
  }
}

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const FeedScreen(initialTab: HomeTab.reels),
    ),
    GoRoute(
      path: '/:a',
      builder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
    ),
    GoRoute(
      path: '/:a/:b',
      builder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
    ),
  ],
);

Post _reel(
  String id, {
  String username = 'sara',
  String text = 'Golden hour #kabso',
  List<String> hashtags = const ['kabso'],
  bool liked = false,
  bool saved = false,
  int likes = 128,
}) => testPost(
  id,
  reel: true,
  username: username,
  text: text,
  hashtags: hashtags,
  liked: liked,
  saved: saved,
  likes: likes,
  commentCount: 14,
);

class _Env {
  new({
    List<Post>? trending,
    List<Post>? following,
    bool privateAuthor = false,
    bool followingAuthor = false,
  }) : posts = FakePostsRepository(),
       profiles = FakeProfileRepository(
         apiProfile(isPrivate: privateAuthor, isFollowing: followingAuthor),
       ) {
    posts.reels[PostsFeedTab.trending] = trending ?? [_reel('r1')];
    posts.reels[PostsFeedTab.following] = following ?? const [];
  }

  final FakePostsRepository posts;
  final FakeProfileRepository profiles;
  final sharer = _FakeSharer();

  List<Override> get overrides => [
    profileRepositoryProvider.overrideWithValue(profiles),
    reelSharerProvider.overrideWithValue(sharer),
    // D294: no country (the default test user has none) — the reels page
    // never asks for one any more.
    currentUserProvider.overrideWithValue(testUser()),
    homeStoriesProvider.overrideWith(
      (ref) => FeedItems<FeedStoryData>([
        const FeedStoryData(authorName: 'Omar', username: 'omar'),
        ...feedStories(AppLanguage.en),
      ]),
    ),
  ];
}

Future<_Env> _pump(
  WidgetTester tester, {
  _Env? env,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  GoRouter? router,
  FakeInlineVideos? videos,
}) async {
  final e = env ?? _Env();
  setViewport(tester, viewport);
  await withClock(Clock.fixed(fixtureNow), () async {
    await pumpScreen(
      tester,
      router != null
          ? _Routed(router: router)
          : const FeedScreen(initialTab: HomeTab.reels),
      language: language,
      postsRepository: e.posts,
      overrides: e.overrides,
      inlineVideos: videos,
    );
    await tester.pumpAndSettle();
  });
  return e;
}

Finder _tab(String label) => find.descendant(
  of: find.byKey(FeedScreen.tabsKey),
  matching: find.text(label),
);

bool _selected(WidgetTester tester, String label) =>
    tester.getSemantics(_tab(label)).flagsCollection.isSelected ==
    Tristate.isTrue;

Finder _onPage(Finder f) =>
    find.descendant(of: find.byType(HomeReelPage).first, matching: f);

void main() {
  group('header (D294)', () {
    testWidgets('the posts page bar: «+» at the start (owner 2026-11-12), '
        '«Posts | Reels» centred with Reels selected, Search then the bell at '
        'the end; no feed tabs, no chip', (tester) async {
      await _pump(tester);
      final create = tester.getRect(find.byKey(FeedScreen.createKey));
      final search = tester.getRect(find.byKey(FeedScreen.searchKey));
      final bell = tester.getRect(find.byKey(NotificationsBell.bellKey));
      expect(create.size, const Size.square(KSizes.minTouchTarget));
      expect(create.left, KSpacing.xs);
      expect(search.size, const Size.square(KSizes.minTouchTarget));
      expect(search.right, bell.left);
      expect(bell.right, 393 - KSpacing.xs);
      // The same words in the same order as on Posts; Reels is selected,
      // Posts is the switch back (a button, never selected).
      final posts = tester.getCenter(_tab(_en.homeTabPosts)).dx;
      final reels = tester.getCenter(_tab(_en.homeTabReels)).dx;
      expect(posts < reels, isTrue);
      expect(_selected(tester, _en.homeTabReels), isTrue);
      expect(
        find.descendant(
          of: find.byKey(FeedScreen.switchKey),
          matching: find.text(_en.homeTabPosts),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(_en.homeShowPosts), findsOneWidget);
      final tabs = tester.getRect(find.byKey(FeedScreen.tabsKey));
      expect(tabs.center.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
      expect(tabs.top, search.top);
      // D294: Following · For You · Nearby and the Posts chip are gone.
      for (final gone in [_en.feedTabFollowing, _en.liveHubFilterNearby]) {
        expect(find.text(gone), findsNothing);
      }
      expect(find.bySemanticsLabel(_en.reelsOpenStories), findsNothing);
      expect(find.bySemanticsLabel(_en.reelsOpenRooms), findsNothing);
      expect(
        tester.getRect(find.byKey(FeedScreen.switchKey)).bottom,
        lessThanOrEqualTo(bell.bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('one feed: GET /feed/reels?tab=mixed only (no following, '
        'trending or nearby request); no country prompt', (tester) async {
      final env = await _pump(
        tester,
        env:
            _Env(
                following: [_reel('f1', username: 'omar')],
                trending: [_reel('t1', username: 'hind')],
              )
              ..posts.reels[PostsFeedTab.mixed] = [
                _reel('m1', username: 'layla'),
                _reel('m2', username: 'omar'),
              ],
      );
      expect(env.posts.calls.where((c) => c.startsWith('reels:')), [
        'reels:mixed:',
      ]);
      expect(find.text(KHandle.ltr('@layla')), findsOneWidget);
      expect(find.text(KHandle.ltr('@hind')), findsNothing);
      // No country (the default user has none): no «Choose your country».
      expect(find.byIcon(Icons.public_rounded), findsNothing);
    });

    testWidgets('an empty mix says so honestly', (tester) async {
      await _pump(tester, env: _Env(trending: const []));
      expect(find.text(_en.homeReelsEmptyTitle), findsOneWidget);
    });

    testWidgets('Search, the bell, Rooms and a hashtag navigate', (
      tester,
    ) async {
      final router = _router();
      Future<void> back() async {
        router.pop();
        await tester.pumpAndSettle();
      }

      await _pump(tester, router: router);
      await tester.tap(find.byKey(FeedScreen.searchKey));
      await tester.pumpAndSettle();
      expect(find.text('route:/discover'), findsOneWidget);
      await back();
      await tester.tap(find.byKey(NotificationsBell.bellKey));
      await tester.pumpAndSettle();
      expect(find.text('route:/notifications'), findsOneWidget);
      await back();
      await tester.tapOnText(find.textRange.ofSubstring('#kabso'));
      await tester.pumpAndSettle();
      expect(find.text('route:/hashtags/kabso'), findsOneWidget);
      await back();
      // The handle and the rail photo open the profile.
      await tester.tap(_onPage(find.byKey(HomeReelPage.handleKey)));
      await tester.pumpAndSettle();
      expect(find.text('route:/users/sara'), findsOneWidget);
      await back();
      await tester.tap(_onPage(find.byKey(HomeReelPage.authorKey)));
      await tester.pumpAndSettle();
      expect(find.text('route:/users/sara'), findsOneWidget);
    });

    testWidgets('«Posts» switches to Posts and «Reels» back; each page is '
        'kept', (tester) async {
      final env = await _pump(tester);
      await tester.tap(find.byKey(FeedScreen.switchKey));
      await tester.pumpAndSettle();
      // Posts' header: «Posts» selected, «Reels» the switch.
      expect(_selected(tester, _en.homeTabPosts), isTrue);
      expect(
        find.descendant(
          of: find.byKey(FeedScreen.switchKey),
          matching: find.text(_en.homeTabReels),
        ),
        findsOneWidget,
      );
      expect(env.posts.calls, contains('feed:mixed:'));
      await tester.tap(find.byKey(FeedScreen.switchKey));
      await tester.pumpAndSettle();
      expect(_selected(tester, _en.homeTabReels), isTrue);
      // The reels page was kept: the mix is not read again.
      expect(env.posts.calls.where((c) => c == 'reels:mixed:'), hasLength(1));
      expect(find.text(KHandle.ltr('@sara')), findsWidgets);
    });
  });

  group('full screen (D298)', () {
    testWidgets('the reel fills the screen from the very top (behind the '
        'status bar); the header floats over it, its row under the status '
        'bar; the scrim fades to nothing; the rail and bottom block keep '
        'their places', (tester) async {
      tester.view.padding = const FakeViewPadding(
        top: 59 * GoldenViewport.pixelRatio,
        bottom: 34 * GoldenViewport.pixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await _pump(tester);
      const screen = Rect.fromLTWH(0, 0, 393, 852);
      final topInset = KTopInset.of(tester.element(find.byType(FeedScreen)));
      expect(topInset, 59 + KMetrics.statusBarGap);
      // The video (and its poster) edge to edge, from y = 0.
      expect(tester.getRect(find.byType(HomeReelPage).first), screen);
      expect(
        tester.getRect(_onPage(find.byKey(HomeReelPage.mediaKey))),
        screen,
      );
      final video = tester.widget<InlineVideo>(
        _onPage(find.byType(InlineVideo)),
      );
      expect(video.fit, BoxFit.cover);
      // The header overlays the video: it starts at the top, its row
      // starts under the status bar, and it is only the bar (no band).
      final header = tester.getRect(find.byKey(FeedScreen.headerKey));
      expect(header.top, 0);
      expect(header.height, topInset + KMetrics.topBarHeight);
      expect(tester.getRect(find.byKey(FeedScreen.tabsKey)).top, topInset);
      expect(tester.getRect(find.byKey(FeedScreen.searchKey)).top, topInset);
      expect(
        tester.widget(find.byKey(FeedScreen.headerKey)),
        isA<KeyedSubtree>(),
      );
      // Nothing in the header paints a full-width fill.
      final fills = find.descendant(
        of: find.byKey(FeedScreen.headerKey),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox || w is DecoratedBox,
        ),
      );
      for (final e in fills.evaluate()) {
        expect(
          tester.getRect(find.byElementPredicate((x) => x == e)).width,
          lessThan(393),
        );
      }
      // The scrim: dark at the top, still dark at the bar's bottom, then a
      // fade to fully transparent (no visible edge).
      final scrim = find.byKey(FeedScreen.reelsScrimKey);
      expect(
        tester.getRect(scrim),
        Rect.fromLTWH(
          0,
          0,
          393,
          topInset + KMetrics.topBarHeight + KReelsHeader.scrimBelow,
        ),
      );
      final gradient =
          (tester
                          .widget<DecoratedBox>(
                            find.descendant(
                              of: scrim,
                              matching: find.byType(DecoratedBox),
                            ),
                          )
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      final alphas = [for (final c in gradient.colors) c.a];
      expect(alphas.first, greaterThanOrEqualTo(0.6));
      expect(alphas.last, 0);
      for (var i = 1; i < alphas.length; i++) {
        expect(alphas[i], lessThan(alphas[i - 1]));
        // Small steps: no visible edge anywhere in the fade.
        expect(alphas[i - 1] - alphas[i], lessThan(0.15));
      }
      // Flat at the bottom: the last step is the smallest of the fade's
      // second half.
      expect(
        alphas[alphas.length - 2] - alphas.last,
        lessThan(alphas[alphas.length - 3] - alphas[alphas.length - 2]),
      );
      // Still dark behind the bar's row (white text over a bright video).
      final barEnd =
          (topInset + KMetrics.topBarHeight) /
          (topInset + KMetrics.topBarHeight + KReelsHeader.scrimBelow);
      expect(KReelsHeader.scrimOpacityAt(barEnd), greaterThanOrEqualTo(0.35));
      expect(KReelsHeader.scrimOpacityAt(barEnd / 2), greaterThan(0.5));
      expect(
        find.ancestor(of: scrim, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      // The rail and the bottom block keep their places from the bottom.
      final rail = tester.getRect(_onPage(find.byKey(HomeReelPage.railKey)));
      expect(rail.bottom, 852 - KHomeReels.railBottom);
      expect(rail.right, 393 - KHomeReels.railEnd);
      final sound = tester.getRect(_onPage(find.byKey(HomeReelPage.soundKey)));
      expect(sound.bottom, lessThanOrEqualTo(852 - KHomeReels.contentBottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a swipe that starts under the scrim still pages the reels', (
      tester,
    ) async {
      await _pump(tester, env: _Env(trending: [_reel('r1'), _reel('r2')]));
      expect(find.byKey(const ValueKey('home.reel.r1')), findsOneWidget);
      final topInset = KTopInset.of(tester.element(find.byType(FeedScreen)));
      await tester.dragFrom(
        Offset(200, topInset + KMetrics.topBarHeight + 24),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home.reel.r2')), findsOneWidget);
    });

    testWidgets('Posts keep their solid header and no scrim', (tester) async {
      await _pump(tester);
      expect(find.byKey(FeedScreen.reelsScrimKey), findsOneWidget);
      await tester.tap(find.byKey(FeedScreen.switchKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FeedScreen.reelsScrimKey), findsNothing);
      final header = tester.widget(find.byKey(FeedScreen.headerKey));
      expect(header, isA<ColoredBox>());
      final p = tester.element(find.byKey(FeedScreen.headerKey)).palette;
      expect((header as ColoredBox).color, p.background);
    });
  });

  group('progress line and bottom scrim (D298)', () {
    Finder bar() => _onPage(find.byKey(HomeReelPage.progressKey));
    Finder paint() =>
        find.descendant(of: bar(), matching: find.byType(CustomPaint));
    String? value(WidgetTester tester) => tester.getSemantics(paint()).value;

    testWidgets('a thin full-width line on the reel bottom edge once the '
        'video has a length; it follows the player', (tester) async {
      final videos = FakeInlineVideos();
      await _pump(tester, videos: videos);
      final video = videos.created.single;
      expect(video.plays, 1);
      final rect = tester.getRect(paint());
      expect(
        rect,
        const Rect.fromLTWH(
          0,
          852 - KHomeReels.progressHit,
          393,
          KHomeReels.progressHit,
        ),
      );
      expect(value(tester), '1%');
      video.setPosition(const Duration(milliseconds: 3200));
      await tester.pump();
      expect(value(tester), '40%');
      video.setPosition(const Duration(seconds: 8));
      await tester.pump();
      expect(value(tester), '100%');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no line while the length is unknown or the video cannot '
        'play', (tester) async {
      final videos = FakeInlineVideos()
        ..failing.add('https://media.example.test/media/r1-v/video.mp4');
      await _pump(tester, videos: videos);
      expect(videos.created.single.state.initialized, isFalse);
      expect(bar(), findsOneWidget);
      expect(paint(), findsNothing);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: a tap seeks from the reading start '
          '(mirrored in Arabic); a drag scrubs with a thicker line and seeks '
          'on release', (tester) async {
        final videos = FakeInlineVideos();
        await _pump(tester, videos: videos, language: language);
        final video = videos.created.single;
        final ar = language == AppLanguage.ar;
        expect(
          Directionality.of(tester.element(bar())),
          ar ? TextDirection.rtl : TextDirection.ltr,
        );
        const y = 852 - KHomeReels.progressHit / 2;
        // A quarter of the width from the left: 25 % in English, 75 % in
        // Arabic (it grows from the right).
        await tester.tapAt(const Offset(393 * 0.25, y));
        await tester.pump();
        expect(
          video.seeks.last,
          ar ? const Duration(seconds: 6) : const Duration(seconds: 2),
        );
        expect(value(tester), ar ? '75%' : '25%');
        // Scrub from 10 % to 50 % of the width (left to right).
        final gesture = await tester.startGesture(const Offset(393 * 0.1, y));
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        await gesture.moveTo(const Offset(393 * 0.5, y));
        await tester.pump();
        expect(value(tester), '50%');
        final seeks = video.seeks.length;
        await gesture.up();
        await tester.pump();
        expect(video.seeks, hasLength(seeks + 1));
        expect(video.seeks.last, const Duration(seconds: 4));
        expect(video.state.position, const Duration(seconds: 4));
        // The page did not move: the drag was the line's, not the pager's.
        expect(find.byType(HomeReelPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the screen reader moves it 5 s at a time', (tester) async {
      final videos = FakeInlineVideos();
      await _pump(tester, videos: videos);
      final video = videos.created.single
        ..setPosition(const Duration(seconds: 2));
      await tester.pump();
      final node = tester.getSemantics(paint());
      expect(node.label, _en.reelsProgress);
      expect(node.increasedValue, '88%');
      tester
          .widget<Semantics>(
            find.descendant(of: bar(), matching: find.byType(Semantics)).first,
          )
          .properties
          .onIncrease!();
      await tester.pump();
      expect(video.seeks.last, const Duration(seconds: 7));
    });

    testWidgets('the bottom scrim: the top half clear, then dark under the '
        'author, caption and sound line', (tester) async {
      await _pump(tester);
      final box = tester.widget<DecoratedBox>(
        _onPage(find.byKey(HomeReelPage.bottomScrimKey)),
      );
      final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
      final stops = g.stops!;
      final alphas = [for (final c in g.colors) c.a];
      for (var i = 0; i < stops.length; i++) {
        if (stops[i] <= 0.5) expect(alphas[i], 0, reason: 'stop ${stops[i]}');
      }
      expect(alphas.last, greaterThanOrEqualTo(0.8));
      for (var i = 1; i < alphas.length; i++) {
        expect(alphas[i], greaterThanOrEqualTo(alphas[i - 1]));
      }
      // The caption's text sits where the scrim is at least 25 % black.
      final caption = tester.getRect(
        _onPage(find.byKey(HomeReelPage.captionKey)),
      );
      expect(caption.top / 852, greaterThanOrEqualTo(0.68));
    });
  });

  group('rail (D202)', () {
    testWidgets('like: a tap likes (count +1) and unlikes; the API is '
        'called each time', (tester) async {
      final env = await _pump(tester);
      env.posts.likeCounts['r1'] = 128;
      final like = _onPage(find.byKey(HomeReelPage.likeKey));
      expect(find.descendant(of: like, matching: find.text('128')), findsOne);
      await tester.tap(like);
      await tester.pumpAndSettle();
      expect(env.posts.calls, contains('like:r1:true'));
      expect(find.descendant(of: like, matching: find.text('129')), findsOne);
      expect(find.bySemanticsLabel(_en.feedPostUnlike), findsOneWidget);
      await tester.tap(like);
      await tester.pumpAndSettle();
      expect(env.posts.calls, contains('like:r1:false'));
      expect(find.descendant(of: like, matching: find.text('128')), findsOne);
    });

    testWidgets('a failed like comes back (state and count) with a message', (
      tester,
    ) async {
      final env = await _pump(tester);
      final like = _onPage(find.byKey(HomeReelPage.likeKey));
      env.posts.failWith = Exception('offline');
      await tester.tap(like);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(env.posts.calls, contains('like:r1:true'));
      expect(find.descendant(of: like, matching: find.text('128')), findsOne);
      expect(find.bySemanticsLabel(_en.feedPostLike), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('double tap on the video likes with a heart burst; a second '
        'double tap never unlikes', (tester) async {
      final env = await _pump(tester);
      env.posts.likeCounts['r1'] = 128;
      final media = _onPage(find.byKey(HomeReelPage.mediaKey));
      await tester.tap(media);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(media);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(HomeReelPage.burstKey), findsOneWidget);
      await tester.pumpAndSettle();
      expect(env.posts.calls.where((c) => c.startsWith('like:')), [
        'like:r1:true',
      ]);
      await tester.tap(media);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(media);
      await tester.pumpAndSettle();
      expect(env.posts.calls.where((c) => c.startsWith('like:')), [
        'like:r1:true',
      ]);
      expect(find.byKey(HomeReelPage.burstKey), findsNothing);
    });

    testWidgets('comment opens the comments sheet over the reel', (
      tester,
    ) async {
      final env = await _pump(tester);
      await tester.tap(_onPage(find.byKey(HomeReelPage.commentKey)));
      await tester.pumpAndSettle();
      expect(find.byKey(CommentsSheet.sheetKey), findsOneWidget);
      expect(env.posts.calls, contains('comments:r1:'));
    });

    testWidgets('save toggles the bookmark through the API', (tester) async {
      final env = await _pump(tester);
      final save = _onPage(find.byKey(HomeReelPage.saveKey));
      expect(
        find.descendant(of: save, matching: find.text(_en.reelsSave)),
        findsOne,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(env.posts.calls, contains('save:r1:true'));
      expect(
        find.descendant(of: save, matching: find.text(_en.reelsSaved)),
        findsOne,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(env.posts.calls, contains('save:r1:false'));
      // A failure puts it back.
      env.posts.failWith = Exception('offline');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: save, matching: find.text(_en.reelsSave)),
        findsOne,
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('share opens the share sheet with the handle and caption, '
        'then counts the share; a dismissed sheet counts nothing', (
      tester,
    ) async {
      final env = await _pump(tester);
      env.posts.shareCounts['r1'] = 22;
      final share = _onPage(find.byKey(HomeReelPage.shareKey));
      env.sharer.dismiss = true;
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(env.sharer.texts, [
        _en.reelsShareText('@sara', 'Golden hour #kabso'),
      ]);
      expect(env.posts.calls, isNot(contains('share:r1')));
      env.sharer.dismiss = false;
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(env.posts.calls, contains('share:r1'));
      expect(find.descendant(of: share, matching: find.text('23')), findsOne);
    });

    testWidgets('follow: the author profile is read; «+» follows and turns '
        'into a check', (tester) async {
      final env = await _pump(tester);
      expect(env.profiles.calls, contains('GET sara'));
      final badge = find.byKey(ReelFollowBadge.badgeKey);
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pumpAndSettle();
      expect(env.profiles.calls, contains('PUT sara'));
      expect(find.bySemanticsLabel(_en.homeFollowingAuthor('Sara')), findsOne);
    });

    testWidgets('follow a private account (D175): a request, shown as '
        'requested', (tester) async {
      final env = await _pump(tester, env: _Env(privateAuthor: true));
      await tester.tap(find.byKey(ReelFollowBadge.badgeKey));
      await tester.pumpAndSettle();
      expect(env.profiles.calls, contains('PUT sara'));
      expect(find.bySemanticsLabel(_en.reelsFollowRequested('Sara')), findsOne);
    });

    testWidgets('no «+» for an author already followed', (tester) async {
      await _pump(tester, env: _Env(followingAuthor: true));
      expect(find.byKey(ReelFollowBadge.badgeKey), findsNothing);
    });

    testWidgets('a long caption ends in «more», which expands it; the sound '
        'line names the author; no verified tick, no translate', (
      tester,
    ) async {
      final long = List.filled(12, 'Golden hour, good energy').join(' ');
      await _pump(
        tester,
        env: _Env(
          trending: [_reel('r1', text: long, hashtags: const [])],
        ),
      );
      final more = _onPage(find.byKey(HomeReelPage.moreKey));
      expect(more, findsOneWidget);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(_onPage(find.byKey(HomeReelPage.moreKey)), findsNothing);
      expect(find.text(_en.reelsOriginalSound('Sara')), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
      expect(find.textContaining('Translate'), findsNothing);
    });
  });

  group('both languages at 360×800 ×1.3', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: no overflow; the rail at the reading '
          'end (left in Arabic), the bottom block at the start; the chips '
          'scroll before the speaker button', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await loadAppFonts();
        await _pump(
          tester,
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull);
        final rail = tester.getRect(_onPage(find.byKey(HomeReelPage.railKey)));
        final handle = tester.getRect(
          _onPage(find.byKey(HomeReelPage.handleKey)),
        );
        final ar = language == AppLanguage.ar;
        if (ar) {
          expect(rail.left, KHomeReels.railEnd);
          expect(
            handle.right,
            lessThanOrEqualTo(360 - KHomeReels.contentInset),
          );
          expect(handle.left, greaterThan(rail.right));
        } else {
          expect(rail.right, 360 - KHomeReels.railEnd);
          expect(handle.left, greaterThanOrEqualTo(KHomeReels.contentInset));
          expect(handle.right, lessThan(rail.left));
        }
        expect(rail.bottom, 800 - KHomeReels.railBottom);
        final create = tester.getCenter(find.byKey(FeedScreen.createKey)).dx;
        expect(create < 180, !ar, reason: '«+» at the reading start');
        final search = tester.getCenter(find.byKey(FeedScreen.searchKey)).dx;
        expect(search < 180, ar, reason: 'Search at the reading end');
        final l10n = l10nFor(language);
        for (final label in [l10n.homeTabPosts, l10n.homeTabReels]) {
          final r = tester.getRect(_tab(label));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(360));
        }
      });
    }
  });
}
