// KL-060 part C: comments on the posts API (CONVENTIONS §11.5) — the wire
// calls, and the comments sheet opened from a post: list, paging, replies,
// like, reply, pin, delete, report, closed comments and errors.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

const _forbidden = ServerFailure(
  code: ErrorCode.authForbidden,
  rawCode: 'AUTH_FORBIDDEN',
  debugMessage: 'followers only',
  statusCode: 403,
);

Map<String, Object?> _commentJson(String id, {String? parentId}) => {
  'id': id,
  'postId': 'p1',
  'author': {
    'id': 'u2',
    'username': 'omar',
    'displayName': 'Omar',
    'avatarUrl': null,
  },
  'text': 'Nice',
  'createdAt': '2026-10-20T10:00:00.000Z',
  'likeCount': 3,
  'viewerHasLiked': false,
  'viewerHasDisliked': false,
  'replyCount': 1,
  'parentId': parentId,
  'mentions': <Object>[],
  'pinned': false,
  'canDelete': true,
};

void main() {
  group('repository (wire)', () {
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

    test('lists comments and replies by cursor', () async {
      http
        ..on(
          'GET',
          '$base/posts/p1/comments',
          (_) => FakeResponse(
            200,
            body: {
              'data': [_commentJson('c1')],
              'page': {'nextCursor': 'n2', 'hasMore': true},
            },
          ),
        )
        ..on(
          'GET',
          '$base/comments/c1/replies',
          (_) => FakeResponse(
            200,
            body: {
              'data': [_commentJson('r1', parentId: 'c1')],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        );
      final page = await repo.comments('p1', cursor: 'n1');
      expect(page.items.single.id, 'c1');
      expect(page.items.single.replyCount, 1);
      expect(page.next, 'n2');
      expect(
        http
            .requestsTo('GET', '$base/posts/p1/comments')
            .single
            .queryParameters,
        {'cursor': 'n1'},
      );
      final replies = await repo.replies('c1');
      expect(replies.items.single.parentId, 'c1');
      expect(replies.next, isNull);
      expect(
        http
            .requestsTo('GET', '$base/comments/c1/replies')
            .single
            .queryParameters,
        isEmpty,
      );
    });

    test(
      'creates a comment or a reply; like, pin, delete and report',
      () async {
        http
          ..on(
            'POST',
            '$base/posts/p1/comments',
            (_) => FakeResponse(201, body: _commentJson('r9', parentId: 'c1')),
          )
          ..on(
            'PUT',
            '$base/comments/c1/like',
            (_) =>
                const FakeResponse(200, body: {'liked': true, 'likeCount': 4}),
          )
          ..on(
            'DELETE',
            '$base/comments/c1/like',
            (_) =>
                const FakeResponse(200, body: {'liked': false, 'likeCount': 3}),
          )
          ..on(
            'PUT',
            '$base/comments/c1/pin',
            (_) => FakeResponse(
              200,
              body: {..._commentJson('c1'), 'pinned': true},
            ),
          )
          ..on('DELETE', '$base/comments/c1', (_) => const FakeResponse(204))
          ..on(
            'POST',
            '$base/reports',
            (_) => const FakeResponse(201, body: {'id': 'rep1'}),
          );
        final reply = await repo.createComment('p1', 'Thanks', parentId: 'c1');
        expect(reply.parentId, 'c1');
        final post = http.requestsTo('POST', '$base/posts/p1/comments').single;
        expect(post.data, {'text': 'Thanks', 'parentId': 'c1'});
        await repo.createComment('p1', 'Top');
        expect(http.requestsTo('POST', '$base/posts/p1/comments').last.data, {
          'text': 'Top',
        });
        expect(await repo.setCommentLiked('c1', liked: true), (
          liked: true,
          likeCount: 4,
        ));
        expect(await repo.setCommentLiked('c1', liked: false), (
          liked: false,
          likeCount: 3,
        ));
        expect(
          (await repo.setCommentPinned('c1', pinned: true)).pinned,
          isTrue,
        );
        await repo.deleteComment('c1');
        await repo.reportComment('c1', ReportReason.spam);
        expect(http.requestsTo('POST', '$base/reports').single.data, {
          'targetType': 'COMMENT',
          'targetId': 'c1',
          'reason': 'SPAM',
        });
      },
    );

    test('403 on a comment is AUTH_FORBIDDEN', () async {
      http.on(
        'POST',
        '$base/posts/p1/comments',
        (_) => FakeResponse(
          403,
          body: errorEnvelope('AUTH_FORBIDDEN', 'Comments are closed'),
        ),
      );
      await expectLater(
        repo.createComment('p1', 'Hi'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.authForbidden,
          ),
        ),
      );
    });

    test('@handles are isolated left-to-right for display', () {
      expect(
        isolateHandles('@sara_3d1c شكراً'),
        '\u2066@sara_3d1c\u2069 شكراً',
      );
      expect(isolateHandles('mail a@b.c'), 'mail a@b.c');
    });

    test('D364: sort=NEWEST is sent (RELEVANT is the default and is not); '
        'the dislike answers its own state', () async {
      http
        ..on(
          'GET',
          '$base/posts/p1/comments',
          (_) => const FakeResponse(
            200,
            body: {
              'data': <Object>[],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        )
        ..on(
          'PUT',
          '$base/comments/c1/dislike',
          (_) => const FakeResponse(
            200,
            body: {'disliked': true, 'liked': false, 'likeCount': 2},
          ),
        )
        ..on(
          'DELETE',
          '$base/comments/c1/dislike',
          (_) => const FakeResponse(
            200,
            body: {'disliked': false, 'liked': false, 'likeCount': 2},
          ),
        );
      await repo.comments('p1', sort: CommentSort.newest, cursor: 'n1');
      await repo.comments('p1');
      final sent = http.requestsTo('GET', '$base/posts/p1/comments');
      expect(sent.first.queryParameters, {'sort': 'NEWEST', 'cursor': 'n1'});
      expect(sent.last.queryParameters, isEmpty);
      expect(await repo.setCommentDisliked('c1', disliked: true), (
        disliked: true,
        liked: false,
        likeCount: 2,
      ));
      expect(await repo.setCommentDisliked('c1', disliked: false), (
        disliked: false,
        liked: false,
        likeCount: 2,
      ));
      expect(http.requestsTo('PUT', '$base/comments/c1/dislike'), hasLength(1));
      expect(
        http.requestsTo('DELETE', '$base/comments/c1/dislike'),
        hasLength(1),
      );
    });

    test('Comment.fromJson reads viewerHasDisliked (false when absent)', () {
      final json = _commentJson('c1');
      expect(
        Comment.fromJson({...json, 'viewerHasDisliked': true})
            .viewerHasDisliked,
        isTrue,
      );
      expect(
        Comment.fromJson({...json}..remove('viewerHasDisliked'))
            .viewerHasDisliked,
        isFalse,
      );
    });

    test('Comment.fromJson reads the contract shape', () {
      final c = Comment.fromJson(
        jsonDecode(jsonEncode(_commentJson('c1'))) as Map<String, dynamic>,
      );
      expect(c.author.username, 'omar');
      expect(c.canDelete, isTrue);
      expect(c.parentId, isNull);
    });
  });

  group('sheet', () {
    final me = testUser();

    Future<FakePostsRepository> pump(
      WidgetTester tester, {
      Post? post,
      FakePostsRepository? repo,
      AppLanguage language = AppLanguage.en,
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final posts = repo ?? FakePostsRepository();
      setViewport(tester, viewport);
      await pumpScreen(
        tester,
        Scaffold(
          body: ListView(
            children: [FeedPostTile(post: feedPostOf(post ?? testPost('p1')))],
          ),
        ),
        language: language,
        postsRepository: posts,
        overrides: [
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(me),
        ],
      );
      await tester.pumpAndSettle();
      return posts;
    }

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byKey(FeedPostTile.commentKey));
      await tester.pumpAndSettle();
    }

    String inputText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(CommentsSheet.inputKey))
        .controller!
        .text;

    testWidgets('no comments yet: the first comment appears and the counts '
        'follow', (tester) async {
      final repo = await pump(tester, post: testPost('p1', commentCount: 0));
      await open(tester);
      expect(find.text(_en.commentsEmpty), findsOneWidget);
      expect(find.text(_en.commentsSheetTitle(0)), findsOneWidget);
      final post = tester.widget<IconButton>(find.byKey(CommentsSheet.postKey));
      expect(post.onPressed, isNull);
      await tester.enterText(find.byKey(CommentsSheet.inputKey), ' First! ');
      await tester.pump();
      await tester.tap(find.byKey(CommentsSheet.postKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('createComment:p1::First!'));
      expect(find.text('First!'), findsOneWidget);
      expect(find.text(_en.commentsSheetTitle(1)), findsOneWidget);
      expect(inputText(tester), isEmpty);
      await tester.tap(find.byKey(CommentsSheet.closeKey));
      await tester.pumpAndSettle();
      // The post's comment count follows.
      expect(
        find.descendant(
          of: find.byKey(FeedPostTile.commentKey),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pinned and creator labels; like is immediate and comes back '
        'when it fails', (tester) async {
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [
        testComment('c1', likes: 2),
        testComment(
          'c2',
          pinned: true,
          author: const UserSummary(
            id: 'u-sara',
            username: 'sara',
            displayName: 'Sara',
            avatarUrl: null,
          ),
          text: 'Thanks all',
        ),
      ];
      await pump(tester, repo: repo);
      await open(tester);
      // The pinned comment comes first; Sara wrote the post.
      expect(
        tester.getTopLeft(find.text('Thanks all')).dy,
        lessThan(tester.getTopLeft(find.text('Nice')).dy),
      );
      expect(find.text(_en.commentsPinned), findsOneWidget);
      expect(find.text(_en.commentsCreator), findsOneWidget);

      await tester.tap(find.byKey(CommentsSheet.likeKey('c1')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('likeComment:c1:true'));
      expect(find.bySemanticsLabel(_en.commentsLike('3')), findsOneWidget);

      repo.failWith = const NetworkFailure.offline();
      await tester.tap(find.byKey(CommentsSheet.likeKey('c1')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(_en.commentsLike('3')), findsOneWidget);
    });

    testWidgets('replies open on demand; Reply answers the comment with '
        'parentId and can be cancelled', (tester) async {
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [testComment('c1', replies: 1)];
      repo.commentReplies['c1'] = [
        testComment('r1', parentId: 'c1', text: 'Agreed'),
      ];
      await pump(tester, repo: repo);
      await open(tester);
      expect(find.text('Agreed'), findsNothing);
      await tester.tap(find.byKey(CommentsSheet.repliesKey('c1')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('replies:c1:'));
      expect(find.text('Agreed'), findsOneWidget);

      // Reply to the reply: it joins the top-level comment.
      await tester.tap(find.byKey(CommentsSheet.replyKey('r1')));
      await tester.pumpAndSettle();
      expect(find.text(_en.commentsReplyingTo('Omar')), findsOneWidget);
      expect(inputText(tester), '@omar ');
      await tester.tap(find.byKey(CommentsSheet.cancelReplyKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.commentsReplyingTo('Omar')), findsNothing);

      await tester.tap(find.byKey(CommentsSheet.replyKey('c1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(CommentsSheet.inputKey), '@omar yes');
      await tester.pump();
      await tester.tap(find.byKey(CommentsSheet.postKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('createComment:p1:c1:@omar yes'));
      expect(find.text(isolateHandles('@omar yes')), findsOneWidget);
      expect(find.text(_en.commentsSheetTitle(3)), findsOneWidget);

      await tester.tap(find.byKey(CommentsSheet.repliesKey('c1')));
      await tester.pumpAndSettle();
      expect(find.text('Agreed'), findsNothing);
      expect(find.text(_en.commentsViewReplies(2)), findsOneWidget);
    });

    testWidgets('the post author pins; delete removes a comment and its '
        'replies from the count; others are reported', (tester) async {
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [
        testComment('c1', text: 'First', replies: 2, canDelete: true),
        testComment('c2', text: 'Second', canDelete: true),
      ];
      await pump(
        tester,
        repo: repo,
        post: testPost('p1', isSelf: true, commentCount: 4),
      );
      await open(tester);
      // Pin the second: it moves to the top.
      await tester.tap(find.byKey(CommentsSheet.moreKey('c2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comments.action.pin')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('pinComment:c2:true'));
      expect(
        tester.getTopLeft(find.text('Second')).dy,
        lessThan(tester.getTopLeft(find.text('First')).dy),
      );

      await tester.tap(find.byKey(CommentsSheet.moreKey('c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('comments.action.delete')));
      await tester.pumpAndSettle();
      expect(find.text(_en.commentsDeleteWithReplies), findsOneWidget);
      await tester.tap(find.byKey(CommentsSheet.deleteConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('deleteComment:c1'));
      expect(find.text('First'), findsNothing);
      expect(find.text(_en.commentsSheetTitle(1)), findsOneWidget);

      // Someone else's comment: report, not delete.
      repo.postComments['p1']!.add(testComment('c3', text: 'Spam here'));
      await tester.tap(find.byKey(CommentsSheet.closeKey));
      await tester.pumpAndSettle();
      await open(tester);
      await tester.tap(find.byKey(CommentsSheet.moreKey('c3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('comments.action.delete')), findsNothing);
      await tester.tap(find.byKey(const Key('comments.action.report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('reportComment:c3:SPAM'));
      expect(find.text(_en.feedPostReported), findsOneWidget);
    });

    testWidgets('closed comments show why and no field; a refused comment '
        'says so', (tester) async {
      await pump(
        tester,
        post: testPost('p1', whoCanComment: WhoCanComment.nobody),
      );
      await open(tester);
      expect(find.byKey(CommentsSheet.closedKey), findsOneWidget);
      expect(find.byKey(CommentsSheet.inputKey), findsNothing);
      expect(find.byKey(CommentsSheet.replyKey('c1')), findsNothing);
      await tester.tap(find.byKey(CommentsSheet.closeKey));
      await tester.pumpAndSettle();

      final repo = FakePostsRepository();
      await pump(
        tester,
        repo: repo,
        post: testPost('p2', whoCanComment: WhoCanComment.followers),
      );
      await open(tester);
      // "Followers only" is decided by the server: 403.
      repo.failWith = _forbidden;
      await tester.enterText(find.byKey(CommentsSheet.inputKey), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(CommentsSheet.postKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.commentsNotAllowed), findsOneWidget);
      expect(inputText(tester), 'Hi');
    });

    testWidgets('a failed load offers Retry; later pages load on scroll', (
      tester,
    ) async {
      final repo = FakePostsRepository()
        ..failWith = const NetworkFailure.offline();
      repo.postComments['p1'] = [
        for (var i = 0; i < 25; i++) testComment('c$i', text: 'Comment $i'),
      ];
      await pump(tester, repo: repo);
      await open(tester);
      expect(find.text(_en.commentsFailed), findsOneWidget);
      await tester.tap(find.byKey(CommentsSheet.retryKey));
      await tester.pumpAndSettle();
      expect(find.text('Comment 0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Comment 24'),
        300,
        scrollable: find.descendant(
          of: find.byKey(CommentsSheet.listKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(repo.calls, contains('comments:p1:20'));
    });

    testWidgets('Arabic RTL at 360 dp and text scale 1.3: no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [
        testComment(
          'c1',
          replies: 12,
          likes: 1240,
          pinned: true,
          text: 'تعليق أطول قليلًا ليظهر كيف يلتف النص على سطرين',
        ),
      ];
      await pump(
        tester,
        repo: repo,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      await open(tester);
      await tester.tap(find.byKey(CommentsSheet.replyKey('c1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byKey(CommentsSheet.inputKey))),
        TextDirection.rtl,
      );
      // A reply starts with a lone Latin @handle: the field reads left to
      // right so the handle keeps its @ in front; Arabic text turns it back.
      TextDirection? fieldDirection() => tester
          .widget<TextField>(find.byKey(CommentsSheet.inputKey))
          .textDirection;
      expect(fieldDirection(), TextDirection.ltr);
      await tester.enterText(find.byKey(CommentsSheet.inputKey), '@omar شكراً');
      await tester.pump();
      expect(fieldDirection(), TextDirection.rtl);
      await tester.enterText(find.byKey(CommentsSheet.inputKey), '');
      await tester.pump();
      expect(fieldDirection(), isNull);
    });

    testWidgets('D364: the order menu lists «Most relevant» and «Newest»; a '
        'choice reloads from the first page and is kept', (tester) async {
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [
        testComment('c1', text: 'Older, liked', likes: 5),
        testComment(
          'c2',
          text: 'Newer',
          createdAt: DateTime.utc(2026, 10, 21, 10),
        ),
      ];
      await pump(tester, repo: repo);
      await open(tester);
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(y('Older, liked'), lessThan(y('Newer')));
      expect(find.text(_en.commentsSortRelevant), findsOneWidget);

      await tester.tap(find.byKey(CommentsSheetFrame.sortKey));
      await tester.pumpAndSettle();
      expect(
        find.byKey(CommentsSheetFrame.sortOptionKey(CommentSort.relevant)),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(CommentsSheetFrame.sortOptionKey(CommentSort.newest)),
      );
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'comments:p1::NEWEST');
      expect(repo.commentSorts.last, CommentSort.newest);
      expect(find.text(_en.commentsSortNewest), findsOneWidget);
      expect(y('Newer'), lessThan(y('Older, liked')));

      // Choosing the same order again does not reload.
      final before = repo.calls.length;
      await tester.tap(find.byKey(CommentsSheetFrame.sortKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(CommentsSheetFrame.sortOptionKey(CommentSort.newest)),
      );
      await tester.pumpAndSettle();
      expect(repo.calls.length, before);

      // A like keeps the chosen order (no reload).
      await tester.tap(find.byKey(CommentsSheet.likeKey('c2')));
      await tester.pumpAndSettle();
      expect(find.text(_en.commentsSortNewest), findsOneWidget);
      expect(y('Newer'), lessThan(y('Older, liked')));

      await tester.tap(find.byKey(CommentsSheetFrame.sortKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(CommentsSheetFrame.sortOptionKey(CommentSort.relevant)),
      );
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'comments:p1:');
      expect(y('Older, liked'), lessThan(y('Newer')));
    });

    testWidgets('D364: a failed reload in the new order offers Retry in '
        'that order', (tester) async {
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [testComment('c1')];
      await pump(tester, repo: repo);
      await open(tester);
      await tester.tap(find.byKey(CommentsSheetFrame.sortKey));
      await tester.pumpAndSettle();
      repo.failWith = const NetworkFailure.offline();
      await tester.tap(
        find.byKey(CommentsSheetFrame.sortOptionKey(CommentSort.newest)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(CommentsSheet.retryKey), findsOneWidget);
      await tester.tap(find.byKey(CommentsSheet.retryKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'comments:p1::NEWEST');
      expect(find.text('Nice'), findsOneWidget);
    });

    testWidgets('D364: dislike is immediate, removes the like, has no count, '
        'and comes back when it fails', (tester) async {
      final repo = FakePostsRepository();
      repo.postComments['p1'] = [testComment('c1', likes: 3, liked: true)];
      await pump(tester, repo: repo);
      await open(tester);
      final dislike = find.byKey(CommentsSheet.dislikeKey('c1'));
      void selected({required bool on}) => expect(
        tester.getSemantics(dislike),
        isSemantics(label: _en.commentsDislike, isButton: true, isSelected: on),
      );
      expect(find.bySemanticsLabel(_en.commentsLike('3')), findsOneWidget);
      selected(on: false);

      await tester.tap(dislike);
      await tester.pumpAndSettle();
      expect(repo.calls, contains('dislikeComment:c1:true'));
      expect(find.bySemanticsLabel(_en.commentsLike('2')), findsOneWidget);
      selected(on: true);
      // Private: the dislike shows no number.
      expect(
        find.descendant(of: dislike, matching: find.byType(Text)),
        findsNothing,
      );

      // A like takes the dislike away.
      await tester.tap(find.byKey(CommentsSheet.likeKey('c1')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(_en.commentsLike('3')), findsOneWidget);
      selected(on: false);

      // A failed dislike comes back as it was.
      repo.failWith = const NetworkFailure.offline();
      await tester.tap(dislike);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(_en.commentsLike('3')), findsOneWidget);
      selected(on: false);

      // Taking it back.
      await tester.tap(dislike);
      await tester.pumpAndSettle();
      await tester.tap(dislike);
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'dislikeComment:c1:false');
      selected(on: false);
    });
  });
}
