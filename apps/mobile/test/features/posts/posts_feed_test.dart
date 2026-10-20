// KL-060: the Posts feed on the real posts API (v1.5-social) — pagination,
// like / save, hide, report, delete, moderation and hidden like counts.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

const _serverError = ServerFailure(
  code: ErrorCode.internalError,
  rawCode: 'INTERNAL_ERROR',
  debugMessage: 'boom',
  statusCode: 500,
);

const _badCursor = ServerFailure(
  code: ErrorCode.validationFailed,
  rawCode: 'VALIDATION_FAILED',
  debugMessage: 'cursor',
  statusCode: 400,
  details: [FieldIssue(field: 'cursor', issue: 'invalid_value')],
);

Future<FakePostsRepository> _pump(
  WidgetTester tester,
  List<Post> trending, {
  int pageSize = 20,
  AppLanguage language = AppLanguage.en,
}) async {
  final repo = FakePostsRepository(
    feeds: {PostsFeedTab.trending: trending},
    pageSize: pageSize,
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
  return repo;
}

Finder _inPost(String text, Finder matching) => find.descendant(
  of: find.ancestor(
    of: find.textContaining(text, findRichText: true),
    matching: find.byType(FeedPostTile),
  ),
  matching: matching,
);

void main() {
  group('controller (pagination)', () {
    ProviderContainer container(FakePostsRepository repo) =>
        ProviderContainer.test(
          overrides: [
            postsRepositoryProvider.overrideWithValue(repo),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          ],
        );

    test('loads pages by cursor, never twice, and ends', () async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [for (var i = 0; i < 5; i++) testPost('p$i')],
        },
        pageSize: 2,
      );
      final c = container(repo);
      final notifier = c.read(postsFeedProvider(HomeFeed.trending).notifier);
      var page = await c.read(postsFeedProvider(HomeFeed.trending).future);
      expect(page.items.map((p) => p.id), ['p0', 'p1']);
      expect(page.hasMore, isTrue);
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);
      page = c.read(postsFeedProvider(HomeFeed.trending)).requireValue;
      expect(page.items.map((p) => p.id), ['p0', 'p1', 'p2', 'p3']);
      await notifier.loadMore();
      await notifier.loadMore(); // at the end: ignored
      page = c.read(postsFeedProvider(HomeFeed.trending)).requireValue;
      expect(page.items, hasLength(5));
      expect(page.hasMore, isFalse);
      expect(repo.calls, [
        'feed:trending:',
        'feed:trending:2',
        'feed:trending:4',
      ]);
    });

    test('a failed page keeps the list and shows a retryable error', () async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [for (var i = 0; i < 3; i++) testPost('p$i')],
        },
        pageSize: 2,
      );
      final c = container(repo);
      final notifier = c.read(postsFeedProvider(HomeFeed.trending).notifier);
      await c.read(postsFeedProvider(HomeFeed.trending).future);
      repo.failWith = _serverError;
      await notifier.loadMore();
      var page = c.read(postsFeedProvider(HomeFeed.trending)).requireValue;
      expect(page.items, hasLength(2));
      expect(page.loadMoreError, isA<ServerFailure>());
      await notifier.loadMore(); // blocked until Retry
      expect(repo.calls, hasLength(2));
      await notifier.retryLoadMore();
      page = c.read(postsFeedProvider(HomeFeed.trending)).requireValue;
      expect(page.items, hasLength(3));
      expect(page.loadMoreError, isNull);
    });

    test('an expired Trending snapshot (bad cursor) reloads from the first '
        'page', () async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [for (var i = 0; i < 3; i++) testPost('p$i')],
        },
        pageSize: 2,
      );
      final c = container(repo);
      await c.read(postsFeedProvider(HomeFeed.trending).future);
      repo.failWith = _badCursor;
      await c.read(postsFeedProvider(HomeFeed.trending).notifier).loadMore();
      final page = c.read(postsFeedProvider(HomeFeed.trending)).requireValue;
      expect(page.items.map((p) => p.id), ['p0', 'p1']);
      expect(page.loadMoreError, isNull);
      expect(repo.calls.last, 'feed:trending:');
    });
  });

  group('screen', () {
    testWidgets('loading → posts from the API; error → retry', (tester) async {
      final repo = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [testPost('p1', text: 'First post')],
        },
      )..failWith = _serverError;
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(tester, const FeedScreen(), postsRepository: repo);
      await tester.pumpAndSettle();
      expect(find.byKey(FeedRegion.errorKey), findsOneWidget);
      await tester.tap(find.text(_en.actionRetry).first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('First post', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(FeedPostTile.likeKey), findsOneWidget);
      expect(find.byKey(FeedPostTile.saveKey), findsOneWidget);
    });

    testWidgets('like applies at once, uses the server count, and is undone '
        'with a message when refused', (tester) async {
      final repo = await _pump(tester, [
        testPost('p1', text: 'Hi there', likes: 4),
      ]);
      repo.likeCounts['p1'] = 4;
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.likeKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'like:p1:true');
      expect(find.text('5'), findsOneWidget);
      expect(find.bySemanticsLabel(_en.feedPostUnlike), findsOneWidget);

      repo.failWith = _serverError;
      await tester.tap(find.byKey(FeedPostTile.likeKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'like:p1:false');
      expect(find.text('5'), findsOneWidget); // undone
      expect(find.bySemanticsLabel(_en.feedPostUnlike), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a hidden like count shows the heart without a number', (
      tester,
    ) async {
      await _pump(tester, [testPost('p1', text: 'Shy', hideLikeCount: true)]);
      final like = find.byKey(FeedPostTile.likeKey);
      expect(like, findsOneWidget);
      expect(
        find.descendant(of: like, matching: find.byType(Text)),
        findsNothing,
      );
    });

    testWidgets('save toggles through the API', (tester) async {
      final repo = await _pump(tester, [testPost('p1', text: 'Keep')]);
      await tester.tap(find.byKey(FeedPostTile.saveKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'save:p1:true');
      expect(find.byTooltip(_en.feedPostUnsave), findsOneWidget);
    });

    testWidgets('hide: the post leaves the feed with a message', (
      tester,
    ) async {
      final repo = await _pump(tester, [
        testPost('p1', text: 'Noise'),
        testPost('p2', text: 'Signal'),
      ]);
      await tester.tap(_inPost('Noise', find.byKey(FeedPostTile.moreKey)));
      await tester.pumpAndSettle();
      expect(find.byKey(FeedPostTile.deleteActionKey), findsNothing);
      await tester.tap(find.byKey(FeedPostTile.hideActionKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'hide:p1:true');
      expect(find.textContaining('Noise', findRichText: true), findsNothing);
      expect(find.textContaining('Signal', findRichText: true), findsOneWidget);
      expect(find.text(_en.feedPostHidden), findsOneWidget);
    });

    testWidgets('report: a reason is required; the post leaves the feed', (
      tester,
    ) async {
      final repo = await _pump(tester, [testPost('p1', text: 'Spammy')]);
      await tester.tap(find.byKey(FeedPostTile.moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.reportActionKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.feedPostReportTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'report:p1:SPAM');
      expect(find.text(_en.feedPostReported), findsOneWidget);
      expect(find.byKey(FeedPostTile.likeKey), findsNothing);
    });

    testWidgets('own post: delete after confirming; no hide or report; a '
        'post in review says so', (tester) async {
      final repo = await _pump(tester, [
        testPost('p1', text: 'Mine', isSelf: true, pending: true),
      ]);
      expect(find.byKey(FeedPostTile.pendingKey), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.moreKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FeedPostTile.hideActionKey), findsNothing);
      expect(find.byKey(FeedPostTile.reportActionKey), findsNothing);
      await tester.tap(find.byKey(FeedPostTile.deleteActionKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.feedPostDeleteConfirm), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.deleteConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'delete:p1');
      expect(find.textContaining('Mine', findRichText: true), findsNothing);
      expect(find.byKey(FeedRegion.emptyKey), findsOneWidget);
    });

    testWidgets('prefetch (HL-H5): a short first page pulls the next one; '
        'the list ends with every post once', (tester) async {
      final repo = await _pump(tester, [
        for (var i = 0; i < 6; i++) testPost('p$i', text: 'Post $i'),
      ], pageSize: 3);
      expect(repo.calls, [
        'feed:trending:',
        'feed:following:',
        'feed:trending:3',
      ]);
      final content = ProviderScope.containerOf(
        tester.element(find.byType(FeedScreen)),
      ).read(homePostsProvider(HomeFeed.trending)).requireValue;
      final items = (content as FeedItems<FeedPostData>).items;
      expect(items.map((p) => p.postId), ['p0', 'p1', 'p2', 'p3', 'p4', 'p5']);
      expect(content.hasMore, isFalse);
    });

    testWidgets('Arabic RTL: actions and menu are localized', (tester) async {
      final ar = l10nFor(AppLanguage.ar);
      await _pump(tester, [
        testPost('p1', text: 'مرحبا'),
      ], language: AppLanguage.ar);
      expect(find.bySemanticsLabel(ar.feedPostLike), findsOneWidget);
      expect(find.byTooltip(ar.feedPostSave), findsOneWidget);
      await tester.tap(find.byKey(FeedPostTile.moreKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.feedPostHide), findsOneWidget);
      expect(find.text(ar.feedPostReport), findsOneWidget);
    });
  });
}
