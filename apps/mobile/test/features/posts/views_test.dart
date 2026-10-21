// KL-060 part E4: post views (POST /views, CONVENTIONS §11.4) — counted
// while at least half of someone else's post is on screen for a second or
// more, sent in batches, once per post per session, best effort.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/application/view_recorder.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

void main() {
  test('wire: POST /views with the items', () async {
    final http = FakeHttpAdapter()
      ..on('POST', '/api/v1/views', (_) => const FakeResponse(204));
    final repo = PostsRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
        ..httpClientAdapter = http,
    );
    await repo.recordViews(const [
      (postId: 'p1', watchedMs: 1500),
      (postId: 'p2', watchedMs: 4000),
    ]);
    expect(http.requests.single.data, {
      'items': [
        {'postId': 'p1', 'watchedMs': 1500},
        {'postId': 'p2', 'watchedMs': 4000},
      ],
    });
  });

  // testWidgets runs on fake time, which also drives `clock`.
  testWidgets('a view needs a second on screen; batches go after 10 s; a '
      'post is sent once per session', (tester) async {
    final repo = FakePostsRepository();
    final r = ViewRecorder(repo);
    addTearDown(r.dispose);
    r.visible('a');
    await tester.pump(const Duration(milliseconds: 1500));
    r
      ..hidden('a')
      ..visible('b');
    await tester.pump(const Duration(milliseconds: 500));
    r.hidden('b');
    await tester.pump(const Duration(seconds: 9));
    expect(repo.viewBatches, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.viewBatches.single, [(postId: 'a', watchedMs: 1500)]);

    r.visible('a');
    await tester.pump(const Duration(seconds: 3));
    r.hidden('a');
    await tester.pump(ViewRecorder.flushDelay);
    expect(repo.viewBatches, hasLength(1));
  });

  testWidgets('50 views go at once; a failed batch is dropped quietly; '
      'flush ends the watches in progress', (tester) async {
    final repo = FakePostsRepository();
    final r = ViewRecorder(repo);
    addTearDown(r.dispose);
    for (var i = 0; i < ViewRecorder.maxBatch; i++) {
      r.visible('p$i');
    }
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < ViewRecorder.maxBatch; i++) {
      r.hidden('p$i');
    }
    await tester.pump();
    expect(repo.viewBatches.single, hasLength(ViewRecorder.maxBatch));

    repo.failWith = const NetworkFailure.offline();
    r.visible('x');
    await tester.pump(const Duration(seconds: 2));
    await r.flush();
    expect(repo.calls.last, 'views:1');
    expect(repo.viewBatches, hasLength(1));
  });

  group('tile', () {
    Future<void> pump(
      WidgetTester tester,
      FakePostsRepository repo,
      FeedPostData post,
    ) async {
      setViewport(tester, GoldenViewport.phone);
      final prefs = await testPrefs(language: AppLanguage.en.name);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postsRepositoryProvider.overrideWithValue(repo),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
          ],
          child: MaterialApp(
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.light,
              locale: AppLanguage.en.locale,
            ),
            home: Scaffold(
              body: ListView(children: [FeedPostTile(post: post)]),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("someone else's post on screen is recorded; it is sent "
        'when the session ends', (tester) async {
      final repo = FakePostsRepository();
      await pump(tester, repo, feedPostOf(testPost('p1')));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(repo.viewBatches.single.single.postId, 'p1');
      expect(
        repo.viewBatches.single.single.watchedMs,
        greaterThanOrEqualTo(2000),
      );
    });

    testWidgets('your own post is never recorded', (tester) async {
      final repo = FakePostsRepository();
      await pump(tester, repo, feedPostOf(testPost('p1', isSelf: true)));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(repo.viewBatches, isEmpty);
    });
  });
}
