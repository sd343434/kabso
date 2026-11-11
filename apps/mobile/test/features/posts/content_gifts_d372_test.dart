// D372 «هدية الدعم» (owner 2026-11-11, CONVENTIONS §10.164): gifts on posts
// and reels — the wire call and models, the composer's gift box (only on a
// host's or creator's post), the live gift panel in its content mode (the
// catalogue and the bag without lucky gifts, quips or recipients), the gold
// gift line, and the cherry counter on the post footer and the reel rail.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/posts/content_gifts_d372_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_inline_video.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

void main() {
  group('models and wire', () {
    test('Post reads giftCherries and giftable (absent: 0 and false)', () {
      final json =
          jsonDecode(jsonEncode(postJson('p1'))) as Map<String, dynamic>;
      expect(Post.fromJson(json).giftCherries, 0);
      expect(Post.fromJson(json).giftable, isFalse);
      final post = Post.fromJson({
        ...json,
        'giftCherries': 12600,
        'giftable': true,
      });
      expect(post.giftCherries, 12600);
      expect(post.giftable, isTrue);
    });

    test('a GIFT comment carries its gift; an unknown kind reads as text', () {
      final line = Comment.fromJson(d372GiftCommentJson());
      expect(line.isGift, isTrue);
      expect(line.gift!.name, 'Rose');
      expect(line.gift!.quantity, 10);
      final odd = Comment.fromJson({...d372GiftCommentJson(), 'kind': 'POLL'});
      expect(odd.isGift, isFalse);
    });

    test('sendContentGift posts the body and reads the result', () async {
      final http = FakeHttpAdapter();
      final repo = PostsRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
      Object? sent;
      http.on('POST', '/api/v1/posts/p1/gifts', (req) {
        sent = req.data;
        return FakeResponse(
          201,
          body: {
            'comment': d372GiftCommentJson(),
            'giftCherries': 2100,
            'coins': 700,
            'bagQuantity': 0,
          },
        );
      });
      final result = await repo.sendContentGift(
        'p1',
        giftCode: 'rose',
        quantity: 10,
        source: 'COINS',
        clientId: '0190d4a8-0000-7000-8000-000000000001',
      );
      expect(jsonDecode(jsonEncode(sent)), {
        'giftCode': 'rose',
        'quantity': 10,
        'source': 'COINS',
        'clientId': '0190d4a8-0000-7000-8000-000000000001',
      });
      expect(result.giftCherries, 2100);
      expect(result.coins, 700);
      expect(result.comment.isGift, isTrue);
    });

    test('CONTENT_GIFT_RECIPIENT_UNAVAILABLE has its own message', () {
      expect(
        ErrorCode.fromWire('CONTENT_GIFT_RECIPIENT_UNAVAILABLE'),
        ErrorCode.contentGiftRecipientUnavailable,
      );
      expect(_en.errorContentGiftRecipientUnavailable, isNotEmpty);
    });
  });

  group('post footer and comments sheet', () {
    Future<(FakePostsRepository, FakeLiveGiftRepository)> pump(
      WidgetTester tester, {
      required Post post,
      AppLanguage language = AppLanguage.en,
    }) async {
      final posts = FakePostsRepository()
        ..giftCherriesAfter = 12600
        ..giftCoinsAfter = 999
        ..commenter = const UserSummary(
          id: 'u-me',
          username: 'me',
          displayName: 'Me',
          avatarUrl: null,
        );
      final gifts = FakeLiveGiftRepository(
        codes: ['rose', 'crown', 'lucky_clover', 'quip_ghazal_01'],
        coins: 1000,
      )..categories = const ['POPULAR', 'EVENT', 'FUN', 'LUCKY', 'QUIPS'];
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(children: [FeedPostTile(post: feedPostOf(post))]),
        ),
        language: language,
        postsRepository: posts,
        liveGiftRepository: gifts,
        overrides: [
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      await tester.pumpAndSettle();
      return (posts, gifts);
    }

    testWidgets('a creator\'s post: the counter, the gift box, the content '
        'panel (no lucky, no quips, no recipients), the send and the gold '
        'line', (tester) async {
      final (posts, gifts) = await pump(
        tester,
        post: testPost(
          'p1',
          commentCount: 0,
          giftCherries: 9500,
          giftable: true,
        ),
      );
      // The counter: the cherries the author earned, compact.
      final counter = find.byKey(FeedPostTile.giftCherriesKey);
      expect(counter, findsOneWidget);
      expect(
        find.descendant(of: counter, matching: find.text('9,500')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(FeedPostTile.commentKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CommentsSheet.giftKey), findsOneWidget);
      await tester.tap(find.byKey(CommentsSheet.giftKey));
      await tester.pumpAndSettle();
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
      // No lucky or quips tab, no recipients row; the bag stays.
      expect(find.byKey(KLiveGiftSheet.tabKey('LUCKY')), findsNothing);
      expect(find.byKey(KLiveGiftSheet.tabKey('QUIPS')), findsNothing);
      expect(
        find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.bagTab)),
        findsOneWidget,
      );
      expect(find.byKey(KLiveGiftSheet.allKey), findsNothing);
      final rose = find.byKey(KLiveGiftSheet.cellKey('rose'));
      await tester.ensureVisible(rose);
      await tester.tap(rose);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await tester.pumpAndSettle();
      expect(posts.calls, contains('sendContentGift:p1:rose:1:COINS'));
      // Nothing went to a live room; the panel closed.
      expect(gifts.sends, isEmpty);
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsNothing);
      // The gold line is listed and counted.
      expect(find.byKey(CommentGiftLine.lineKey), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          _en.commentsGiftSent(
            KFormat.bidiIsolate('Me'),
            KFormat.bidiIsolate('Rose'),
            KFormat.bidiIsolate('×1'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(_en.commentsSheetTitle(1)), findsOneWidget);
      await tester.tap(find.byKey(CommentsSheet.closeKey));
      await tester.pumpAndSettle();
      // The counter follows the server's total.
      expect(
        find.descendant(
          of: find.byKey(FeedPostTile.giftCherriesKey),
          matching: find.text(KFormat.compact(12600, _en)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a post whose author is not a host or creator: no gift box, '
        'no counter', (tester) async {
      await pump(tester, post: testPost('p1'));
      expect(find.byKey(FeedPostTile.giftCherriesKey), findsNothing);
      await tester.tap(find.byKey(FeedPostTile.commentKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CommentsSheet.emojiKey), findsOneWidget);
      expect(find.byKey(CommentsSheet.giftKey), findsNothing);
    });

    testWidgets('a refused send says why and keeps the panel open', (
      tester,
    ) async {
      final (posts, _) = await pump(
        tester,
        post: testPost('p1', giftable: true),
      );
      const refusal = ServerFailure(
        code: ErrorCode.contentGiftRecipientUnavailable,
        rawCode: 'CONTENT_GIFT_RECIPIENT_UNAVAILABLE',
        debugMessage: 'not_creator',
        statusCode: 409,
      );
      await tester.tap(find.byKey(FeedPostTile.commentKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CommentsSheet.giftKey));
      await tester.pumpAndSettle();
      final rose = find.byKey(KLiveGiftSheet.cellKey('rose'));
      await tester.ensureVisible(rose);
      await tester.tap(rose);
      await tester.pumpAndSettle();
      posts.failWith = refusal;
      await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
      await tester.pumpAndSettle();
      expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
      expect(find.text(_en.errorContentGiftRecipientUnavailable), findsWidgets);
      expect(find.byKey(CommentGiftLine.lineKey), findsNothing);
      // Let the toast's timer end.
      await tester.pump(KLiveGiftSheet.toastTime);
    });

    testWidgets('Arabic RTL: the gift line reads «… أرسل … ×N» without '
        'overflow', (tester) async {
      final ar = l10nFor(AppLanguage.ar);
      final (posts, _) = await pump(
        tester,
        post: testPost('p1', giftable: true, commentCount: 3),
        language: AppLanguage.ar,
      );
      posts.postComments['p1'] = d372Comments(ar: true);
      await tester.tap(find.byKey(FeedPostTile.commentKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CommentGiftLine.lineKey), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(
          ar.commentsGiftSent(
            KFormat.bidiIsolate('عمر'),
            KFormat.bidiIsolate('وردة'),
            KFormat.bidiIsolate('×10'),
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('reel rail', () {
    testWidgets('the cherry counter sits under the comments, compact; hidden '
        'at 0', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await withClock(Clock.fixed(d372Now), () async {
        await pumpScreen(
          tester,
          HomeReelPage(
            reel: feedReelOf(
              testPost('r1', reel: true, giftCherries: 1260000, giftable: true),
            ),
          ),
          inlineVideos: FakeInlineVideos(),
        );
        await tester.pumpAndSettle();
      });
      final counter = find.byKey(HomeReelPage.giftCherriesKey);
      expect(counter, findsOneWidget);
      expect(
        find.descendant(
          of: counter,
          matching: find.text(KFormat.compact(1260000, _en)),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no counter without gifts', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        HomeReelPage(reel: feedReelOf(testPost('r1', reel: true))),
        inlineVideos: FakeInlineVideos(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(HomeReelPage.giftCherriesKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
