// D372 (owner 2026-11-11) «هدية الدعم» — gifts on posts and reels:
//
//   content_gifts.comments.<ar|en>  a host's post (the footer's cherry
//                                   counter) with its comments open: two gold
//                                   gift lines around a text comment and the
//                                   composer's gift box beside «+»
//   content_gifts.panel.<ar|en>     the live gift panel in its content mode
//                                   (no recipients row, no lucky or quips
//                                   tab), a gift picked
//   content_gifts.reel.<ar|en>      a reel's rail with the cherry counter
//                                   under the comments
//
// 393 × 852 with the status bar 59 and the home indicator 34; the clock is
// pinned (2026-11-11 09:30 UTC). Regenerate on Linux with the pinned
// Flutter:
//   flutter test --update-goldens test/goldens/content_gifts_d372_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/posts/content_gifts_d372_fixtures.dart';
import '../helpers/fake_inline_video.dart';
import '../helpers/fake_live_gift_repository.dart';
import '../helpers/fake_posts_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

Future<void> _device(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

/// A host's post with its comments sheet open (the gift lines listed).
Future<void> _openComments(WidgetTester tester, AppLanguage language) async {
  final ar = language == AppLanguage.ar;
  final posts = FakePostsRepository()
    ..postComments['p1'] = d372Comments(ar: ar);
  final post = testPost(
    'p1',
    username: d372Host.username,
    displayName: ar ? 'ليلى' : d372Host.displayName,
    text: ar ? 'بث الليلة الساعة ٩' : 'Live tonight at 9',
    likes: 1840,
    commentCount: 3,
    giftCherries: 12600,
    giftable: true,
  );
  await pumpScreen(
    tester,
    Scaffold(
      body: SafeArea(
        child: ListView(children: [FeedPostTile(post: feedPostOf(post))]),
      ),
    ),
    language: language,
    postsRepository: posts,
    liveGiftRepository: FakeLiveGiftRepository(
      codes: ['rose', 'heart_balloon', 'crown', 'sports_car', 'lucky_clover'],
      ar: ar,
      coins: 25000,
    )..categories = const ['POPULAR', 'EVENT', 'FUN', 'LUCKY'],
    overrides: [
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(FeedPostTile.commentKey));
  await tester.pumpAndSettle();
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets(
      'comments with gift lines and the gift box (${language.name})',
      (tester) async {
        await withClock(Clock.fixed(d372Now), () async {
          await _device(tester);
          await _openComments(tester, language);
          expect(find.byKey(CommentsSheet.giftKey), findsOneWidget);
          await precacheImages(tester);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'png/content_gifts.comments.${language.name}.phone.png',
            ),
          );
        });
      },
    );

    testWidgets('the gift panel in content mode (${language.name})', (
      tester,
    ) async {
      await withClock(Clock.fixed(d372Now), () async {
        await _device(tester);
        await _openComments(tester, language);
        await tester.tap(find.byKey(CommentsSheet.giftKey));
        await tester.pumpAndSettle();
        final crown = find.byKey(KLiveGiftSheet.cellKey('crown'));
        await tester.ensureVisible(crown);
        await tester.tap(crown);
        await tester.pumpAndSettle();
        expect(find.byKey(KLiveGiftSheet.tabKey('LUCKY')), findsNothing);
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/content_gifts.panel.${language.name}.phone.png',
          ),
        );
        await tester.pump(KLiveGiftSheet.toastTime);
      });
    });

    testWidgets('a reel with the cherry counter (${language.name})', (
      tester,
    ) async {
      await withClock(Clock.fixed(d372Now), () async {
        await _device(tester);
        final ar = language == AppLanguage.ar;
        final reel = testPost(
          'r1',
          reel: true,
          username: d372Host.username,
          displayName: ar ? 'ليلى' : d372Host.displayName,
          text: ar ? 'تحدي الرقص' : 'Dance challenge',
          likes: 23400,
          commentCount: 412,
          giftCherries: 1260000,
          giftable: true,
        );
        await pumpScreen(
          tester,
          Material(
            color: const Color(0xFF101014),
            child: HomeReelPage(reel: feedReelOf(reel)),
          ),
          language: language,
          inlineVideos: FakeInlineVideos(),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(HomeReelPage.giftCherriesKey), findsOneWidget);
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'png/content_gifts.reel.${language.name}.phone.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  }
}
