// KL-060 part E3: drafts and scheduled posts — GET /me/posts?status=,
// the Drafts screen, and posting, scheduling or unscheduling them from the
// edit screen (PATCH /posts/{id} with `status`).

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
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
import 'package:kabso_live/features/posts/application/my_posts_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/drafts_screen.dart';
import 'package:kabso_live/features/posts/presentation/edit_post_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

Post _draft(String id, {String text = 'Draft words', int photos = 0}) =>
    testPost(
      id,
      text: text,
      isSelf: true,
      photos: photos,
    ).copyWithForTest(status: 'DRAFT');

Post _scheduled(String id, DateTime at) => testPost(
  id,
  text: 'Later words',
  isSelf: true,
).copyWithForTest(status: 'SCHEDULED', publishAt: at);

void main() {
  test('wire: createPost sends status and publishAt; /me/posts sends the '
      'status', () async {
    final http = FakeHttpAdapter()
      ..on(
        'POST',
        '/api/v1/posts',
        (_) => FakeResponse(201, body: postJson('p1')),
      )
      ..on(
        'GET',
        '/api/v1/me/posts',
        (_) => const FakeResponse(
          200,
          body: {
            'data': <Object?>[],
            'page': {'nextCursor': null, 'hasMore': false},
          },
        ),
      );
    final repo = PostsRepositoryImpl(
      Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
        ..httpClientAdapter = http,
    );
    await repo.createPost(
      idempotencyKey: 'k',
      text: 'Hi',
      status: 'SCHEDULED',
      publishAt: DateTime.utc(2026, 10, 22, 8),
    );
    expect(http.requests.last.data, {
      'text': 'Hi',
      'status': 'SCHEDULED',
      'publishAt': '2026-10-22T08:00:00.000Z',
    });
    await repo.createPost(idempotencyKey: 'k2', text: 'Now');
    expect(http.requests.last.data, {'text': 'Now'});
    await repo.myPosts('DRAFT', cursor: 'c');
    expect(http.requests.last.queryParameters, {
      'status': 'DRAFT',
      'cursor': 'c',
    });
  });

  group('screens', () {
    Future<(FakePostsRepository, GoRouter)> pump(
      WidgetTester tester,
      FakePostsRepository repo, {
      AppLanguage language = AppLanguage.en,
    }) async {
      final router = GoRouter(
        initialLocation: AppRoutes.drafts,
        routes: [
          GoRoute(
            path: AppRoutes.drafts,
            builder: (_, _) => const DraftsScreen(),
          ),
          GoRoute(
            path: AppRoutes.editPostPattern,
            builder: (_, s) =>
                EditPostScreen(postId: s.pathParameters['postId']!),
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
      return (repo, router);
    }

    testWidgets('drafts and scheduled lists; empty states say so', (
      tester,
    ) async {
      final repo = FakePostsRepository()
        ..myPostLists['DRAFT'] = [_draft('d1'), _draft('d2', text: '')]
        ..myPostLists['SCHEDULED'] = [];
      await pump(tester, repo);
      expect(repo.calls, contains('myPosts:DRAFT:'));
      expect(find.byKey(DraftsScreen.rowKey('d1')), findsOneWidget);
      expect(find.text('Draft words'), findsOneWidget);
      expect(find.text(_en.draftsNoText), findsOneWidget);
      await tester.tap(find.byKey(DraftsScreen.tabKey(MyPostsList.scheduled)));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('myPosts:SCHEDULED:'));
      expect(find.byKey(DraftsScreen.emptyKey), findsOneWidget);
      expect(find.text(_en.scheduledEmpty), findsOneWidget);
    });

    testWidgets('delete asks first, then the row leaves', (tester) async {
      final repo = FakePostsRepository()
        ..myPostLists['DRAFT'] = [_draft('d1'), _draft('d2')];
      await pump(tester, repo);
      await tester.tap(find.byKey(DraftsScreen.deleteKey('d1')));
      await tester.pumpAndSettle();
      expect(find.text(_en.draftsDeleteConfirm), findsOneWidget);
      await tester.tap(find.byKey(DraftsScreen.deleteConfirmKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('delete:d1'));
      expect(find.byKey(DraftsScreen.rowKey('d1')), findsNothing);
      expect(find.byKey(DraftsScreen.rowKey('d2')), findsOneWidget);
    });

    testWidgets('a draft opens its edit screen; Post now publishes it with '
        'the changed caption and it leaves Drafts', (tester) async {
      final repo = FakePostsRepository()..myPostLists['DRAFT'] = [_draft('d1')];
      await pump(tester, repo);
      await tester.tap(find.byKey(DraftsScreen.rowKey('d1')));
      await tester.pumpAndSettle();
      expect(find.text(_en.editPostDraftBadge), findsOneWidget);
      expect(find.byKey(EditPostScreen.toDraftsKey), findsNothing);
      await tester.enterText(find.byKey(EditPostScreen.textKey), 'Final');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(EditPostScreen.publishNowKey));
      await tester.tap(find.byKey(EditPostScreen.publishNowKey));
      await tester.pumpAndSettle();
      expect(repo.updates.single.$2, {'text': 'Final', 'status': 'PUBLISHED'});
      expect(find.text(_en.editPostPublished), findsOneWidget);
      expect(find.byKey(DraftsScreen.rowKey('d1')), findsNothing);
      expect(find.byKey(DraftsScreen.emptyKey), findsOneWidget);
    });

    testWidgets('a scheduled post moves back to drafts; a draft is '
        'scheduled with the picked time', (tester) async {
      final now = DateTime(2026, 10, 21, 10, 7);
      await withClock(Clock.fixed(now), () async {
        final at = DateTime(2026, 10, 23, 9);
        final repo = FakePostsRepository()
          ..myPostLists['DRAFT'] = []
          ..myPostLists['SCHEDULED'] = [_scheduled('s1', at)];
        await pump(tester, repo);
        await tester.tap(
          find.byKey(DraftsScreen.tabKey(MyPostsList.scheduled)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(DraftsScreen.rowKey('s1')));
        await tester.pumpAndSettle();
        expect(find.text(_en.editPostReschedule), findsOneWidget);
        await tester.ensureVisible(find.byKey(EditPostScreen.toDraftsKey));
        await tester.tap(find.byKey(EditPostScreen.toDraftsKey));
        await tester.pumpAndSettle();
        expect(repo.updates.last.$2, {'status': 'DRAFT'});
        expect(find.byKey(DraftsScreen.emptyKey), findsOneWidget);

        await tester.tap(find.byKey(DraftsScreen.tabKey(MyPostsList.drafts)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(DraftsScreen.rowKey('s1')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(EditPostScreen.scheduleKey));
        await tester.tap(find.byKey(EditPostScreen.scheduleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(repo.updates.last.$2, {
          'status': 'SCHEDULED',
          'publishAt': DateTime(2026, 10, 21, 11, 7).toUtc().toIso8601String(),
        });
      });
    });

    testWidgets('Arabic RTL at 360 dp and text scale 1.3: drafts and the '
        'draft edit screen do not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakePostsRepository()
        ..myPostLists['DRAFT'] = [
          _draft('d1', text: 'مسودة طويلة ' * 10, photos: 2),
        ];
      await pump(tester, repo, language: AppLanguage.ar);
      setViewport(tester, GoldenViewport.android);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(DraftsScreen.rowKey('d1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(EditPostScreen.publishNowKey), findsOneWidget);
    });
  });
}
