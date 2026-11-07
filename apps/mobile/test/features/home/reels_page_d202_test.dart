// D202 (owner reference, v1.68-social): the reels page — the floating
// header, the real rail (like with double tap and rollback, comments, save,
// share, follow / request), the caption's hashtags and «المزيد», the sound
// line, and both languages at 360×800 ×1.3.
// D294 (v1.92-social, owner: «اجعل فلتر فقط منشورات وريلز»): the header is
// the posts page's bar (Search, «Posts | Reels» with Reels selected, the
// bell); the tabs Following · For You · Nearby, the Posts chip and Nearby's
// country prompt are gone; the page reads `GET /feed/reels?tab=mixed` only.

import 'dart:ui' show Tristate;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/format/k_handle.dart';
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
    testWidgets('the posts page bar: Search at the start, «Posts | Reels» '
        'centred with Reels selected, the bell at the end; no feed tabs, no '
        'chip', (tester) async {
      await _pump(tester);
      final search = tester.getRect(find.byKey(FeedScreen.searchKey));
      final bell = tester.getRect(find.byKey(NotificationsBell.bellKey));
      expect(search.size, const Size.square(KSizes.minTouchTarget));
      expect(search.left, KSpacing.xs);
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
        final search = tester.getCenter(find.byKey(FeedScreen.searchKey)).dx;
        expect(search < 180, !ar, reason: 'Search at the reading start');
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
