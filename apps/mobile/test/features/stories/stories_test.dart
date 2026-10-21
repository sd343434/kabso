// CP-008 (D91): photo stories in the app — the tray on the Posts page, the
// full-screen viewer (seen, next/previous, viewers, delete, report, mute),
// posting a story and the archive.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/presentation/new_story_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_archive_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_viewers_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

const _omar = UserSummary(
  id: 'u-omar',
  username: 'omar',
  displayName: 'Omar',
  avatarUrl: null,
);

void main() {
  group('wire', () {
    late FakeHttpAdapter http;
    late StoriesRepositoryImpl repo;
    const base = '/api/v1';
    Map<String, Object?> storyJson(String id) => {
      'id': id,
      'author': {
        'id': 'u1',
        'username': 'sara',
        'displayName': 'Sara',
        'avatarUrl': null,
      },
      'media': {
        'id': 'm1',
        'type': 'IMAGE',
        'status': 'READY',
        'width': 1080,
        'height': 1920,
        'blurhash': null,
        'url': 'https://media.example.test/media/m1/1920.webp',
        'thumbUrl': 'https://media.example.test/media/m1/320.webp',
      },
      'text': 'hi',
      'mentions': <Object?>[],
      'createdAt': '2026-10-21T09:00:00.000Z',
      'expiresAt': '2026-10-22T09:00:00.000Z',
      'viewerHasSeen': false,
      'isSelf': false,
      'viewCount': null,
    };

    setUp(() {
      http = FakeHttpAdapter();
      repo = StoriesRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
    });

    test('tray, user stories, create with its key, seen, report', () async {
      http
        ..on(
          'GET',
          '$base/feed/stories',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'user': {
                    'id': 'u1',
                    'username': 'sara',
                    'displayName': 'Sara',
                    'avatarUrl': null,
                  },
                  'storyCount': 2,
                  'hasUnseen': true,
                  'latestAt': '2026-10-21T09:00:00.000Z',
                },
              ],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        )
        ..on(
          'GET',
          '$base/users/sara/stories',
          (_) => FakeResponse(
            200,
            body: {
              'data': [storyJson('s1')],
            },
          ),
        )
        ..on(
          'POST',
          '$base/stories',
          (_) => FakeResponse(201, body: storyJson('s2')),
        )
        ..on('PUT', '$base/stories/s1/seen', (_) => const FakeResponse(204))
        ..on(
          'POST',
          '$base/reports',
          (_) => const FakeResponse(
            201,
            body: {
              'id': 'r1',
              'targetType': 'STORY',
              'targetId': 's1',
              'reason': 'SPAM',
              'note': null,
              'status': 'OPEN',
              'createdAt': '2026-10-21T09:00:00.000Z',
              'resolvedAt': null,
            },
          ),
        );
      final tray = await repo.tray(limit: 50);
      expect(tray.items.single.storyCount, 2);
      expect(http.requests.last.queryParameters, {'limit': 50});
      final list = await repo.userStories('sara');
      expect(list.single.media.url, endsWith('/1920.webp'));
      await repo.createStory(idempotencyKey: 'k1', mediaId: 'm1', text: 'hey');
      expect(http.requests.last.headers['Idempotency-Key'], 'k1');
      expect(http.requests.last.data, {'mediaId': 'm1', 'text': 'hey'});
      await repo.createStory(idempotencyKey: 'k2', mediaId: 'm1');
      expect(http.requests.last.data, {'mediaId': 'm1'});
      await repo.markSeen('s1');
      expect(http.requests.last.method, 'PUT');
      await repo.reportStory('s1', ReportReason.spam);
      expect(http.requests.last.data, {
        'targetType': 'STORY',
        'targetId': 's1',
        'reason': 'SPAM',
      });
    });
  });

  group('screens', () {
    Future<(FakeStoriesRepository, GoRouter)> pump(
      WidgetTester tester, {
      required FakeStoriesRepository repo,
      String initial = '/home',
      AppLanguage language = AppLanguage.en,
      List<FeedStoryData>? tray,
      FakeMediaRepository? media,
      FakePhotoPicker? picker,
      FakeSafetyRepository? safety,
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => FeedStoriesTray(
                  stories: tray ?? const [],
                  onOpen: (s) => context.push(AppRoutes.stories(s.username!)),
                  onAdd: () => context.push(AppRoutes.newStory),
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.reels,
            builder: (_, _) => const Scaffold(body: Text('posts tab')),
          ),
          GoRoute(
            path: AppRoutes.storiesPattern,
            builder: (_, s) =>
                StoryViewerScreen(username: s.pathParameters['username']!),
          ),
          GoRoute(
            path: AppRoutes.newStory,
            builder: (_, _) => const NewStoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.storyArchive,
            builder: (_, _) => const StoryArchiveScreen(),
          ),
        ],
      );
      setViewport(tester, viewport);
      final prefs = await testPrefs(language: language.name);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            storiesRepositoryProvider.overrideWithValue(repo),
            mediaRepositoryProvider.overrideWithValue(
              media ?? FakeMediaRepository(),
            ),
            photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
            safetyRepositoryProvider.overrideWithValue(
              safety ?? FakeSafetyRepository(),
            ),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
            homeStoriesProvider.overrideWith(
              (_) async => FeedItems(tray ?? const <FeedStoryData>[]),
            ),
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
              brightness: Brightness.dark,
              locale: language.locale,
            ),
          ),
        ),
      );
      // The viewer runs timers: settle with bounded pumps only.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return (repo, router);
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    const sara = FeedStoryData(authorName: 'Sara', username: 'sara');
    const omar = FeedStoryData(
      authorName: 'Omar',
      username: 'omar',
      seen: true,
    );

    testWidgets('the tray: your entry adds a story; an account opens its '
        'stories', (tester) async {
      final (_, router) = await pump(
        tester,
        repo: FakeStoriesRepository()..stories['sara'] = [testStory('s1')],
        tray: const [
          FeedStoryData(
            authorName: 'Layla',
            username: 'layla.k',
            isSelf: true,
            hasStory: false,
          ),
          sara,
        ],
      );
      expect(find.text(_en.storyYourStory), findsOneWidget);
      await tester.tap(find.byKey(FeedStoriesTray.addKey));
      await settle(tester);
      expect(router.state.uri.path, AppRoutes.newStory);
      router.go('/home');
      await settle(tester);
      expect(find.byKey(FeedStoriesTray.itemKey('sara')), findsOneWidget);
      await tester.tap(find.byKey(FeedStoriesTray.itemKey('sara')));
      await settle(tester);
      expect(router.state.uri.path, '/stories/sara');
    });

    testWidgets('viewer: opens at the first unseen story, marks it seen, '
        'goes forward on the end side and back on the start side, then on '
        'to the next account in tray order, and closes after the last', (
      tester,
    ) async {
      final repo = FakeStoriesRepository()
        ..stories['sara'] = [
          testStory('s1', seen: true),
          testStory('s2', text: 'Second'),
        ]
        ..stories['omar'] = [testStory('o1', username: 'omar')];
      final (_, router) = await pump(
        tester,
        repo: repo,
        tray: const [sara, omar],
        initial: AppRoutes.stories('sara'),
      );
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('s2')), findsOneWidget);
      expect(repo.calls, contains('seen:s2'));
      expect(find.text('Second'), findsOneWidget);

      // Start side (left in English): back to s1, already seen.
      await tester.tapAt(const Offset(40, 400));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('s1')), findsOneWidget);
      expect(repo.calls, isNot(contains('seen:s1')));
      // End side: forward twice — s2, then Omar's o1.
      await tester.tapAt(const Offset(350, 400));
      await settle(tester);
      await tester.tapAt(const Offset(350, 400));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('o1')), findsOneWidget);
      expect(repo.calls, contains('seen:o1'));
      // The photo runs out: the viewer closes after the last account.
      await tester.pump(KStoryViewer.duration);
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.viewerKey), findsNothing);
      expect(router.state.uri.path, AppRoutes.reels);
    });

    testWidgets('viewer in Arabic: the start side is on the right', (
      tester,
    ) async {
      final repo = FakeStoriesRepository()
        ..stories['sara'] = [testStory('s1'), testStory('s2')];
      await pump(
        tester,
        repo: repo,
        tray: const [sara],
        initial: AppRoutes.stories('sara'),
        language: AppLanguage.ar,
      );
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('s1')), findsOneWidget);
      await tester.tapAt(const Offset(40, 400));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('s2')), findsOneWidget);
      await tester.tapAt(const Offset(370, 400));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('s1')), findsOneWidget);
    });

    testWidgets('an account that is gone (404) is skipped', (tester) async {
      final repo = FakeStoriesRepository()
        ..hidden.add('sara')
        ..stories['omar'] = [testStory('o1', username: 'omar')];
      await pump(
        tester,
        repo: repo,
        tray: const [sara, omar],
        initial: AppRoutes.stories('sara'),
      );
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('o1')), findsOneWidget);
    });

    testWidgets('your story: who saw it, and delete after asking', (
      tester,
    ) async {
      final repo = FakeStoriesRepository()
        ..stories['layla.k'] = [
          testStory('m1', username: 'layla.k', isSelf: true, views: 1),
        ]
        ..viewerLists['m1'] = [_omar];
      final (_, router) = await pump(
        tester,
        repo: repo,
        initial: AppRoutes.stories('layla.k'),
      );
      await settle(tester);
      expect(find.text(_en.storyViewCount(1)), findsOneWidget);
      await tester.tap(find.byKey(StoryViewerScreen.viewersKey));
      await settle(tester);
      expect(find.byKey(StoryViewersSheet.userKey('omar')), findsOneWidget);
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);

      await tester.tap(find.byKey(StoryViewerScreen.moreKey));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.reportKey), findsNothing);
      await tester.tap(find.byKey(StoryViewerScreen.deleteKey));
      await settle(tester);
      expect(find.text(_en.storyDeleteConfirm), findsOneWidget);
      await tester.tap(find.byKey(StoryViewerScreen.deleteConfirmKey));
      await settle(tester);
      expect(repo.calls, contains('deleteStory:m1'));
      expect(router.state.uri.path, AppRoutes.reels);
    });

    testWidgets("someone else's story: report with a reason; mute", (
      tester,
    ) async {
      final repo = FakeStoriesRepository()..stories['sara'] = [testStory('s1')];
      final safety = FakeSafetyRepository();
      await pump(
        tester,
        repo: repo,
        safety: safety,
        initial: AppRoutes.stories('sara'),
      );
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.viewersKey), findsNothing);
      await tester.tap(find.byKey(StoryViewerScreen.moreKey));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.deleteKey), findsNothing);
      await tester.tap(find.byKey(StoryViewerScreen.reportKey));
      await settle(tester);
      await tester.tap(find.text(_en.reportReasonSpam));
      await settle(tester);
      expect(repo.calls, contains('report:s1:SPAM'));
      expect(find.text(_en.storyReported), findsOneWidget);

      await tester.tap(find.byKey(StoryViewerScreen.moreKey));
      await settle(tester);
      await tester.tap(find.byKey(StoryViewerScreen.muteKey));
      await settle(tester);
      expect(safety.calls, contains('mute:sara:true'));
    });

    testWidgets('new story: pick a photo, add text, share as a story photo '
        '(STORY_IMAGE) with an Idempotency-Key', (tester) async {
      final media = FakeMediaRepository();
      final repo = FakeStoriesRepository();
      final (_, router) = await pump(
        tester,
        repo: repo,
        media: media,
        picker: FakePhotoPicker([jpegBytes]),
        tray: const [
          FeedStoryData(
            authorName: 'Layla',
            username: 'layla.k',
            isSelf: true,
            hasStory: false,
          ),
        ],
      );
      await tester.tap(find.byKey(FeedStoriesTray.addKey));
      await settle(tester);
      expect(find.text(_en.storyNewTitle), findsOneWidget);
      expect(find.byKey(NewStoryScreen.shareKey), findsNothing);
      await tester.tap(find.byKey(NewStoryScreen.pickKey));
      await settle(tester);
      expect(find.byKey(NewStoryScreen.previewKey), findsOneWidget);
      await tester.enterText(find.byKey(NewStoryScreen.textKey), '  Hello  ');
      await tester.tap(find.byKey(NewStoryScreen.shareKey));
      await settle(tester);
      expect(media.storyUploads, 1);
      expect(repo.created.single.text, 'Hello');
      expect(repo.created.single.key, isNotEmpty);
      expect(find.text(_en.storyShared), findsOneWidget);
      expect(router.state.uri.path, '/home');
    });

    testWidgets('archive: covers with dates open the viewer; empty says so', (
      tester,
    ) async {
      final repo = FakeStoriesRepository()
        ..archived = [
          testStory('a1', username: 'layla.k', isSelf: true),
          testStory('a2', username: 'layla.k', isSelf: true),
        ];
      await pump(tester, repo: repo, initial: AppRoutes.storyArchive);
      await settle(tester);
      expect(find.byKey(StoryArchiveScreen.cellKey('a1')), findsOneWidget);
      await tester.tap(find.byKey(StoryArchiveScreen.cellKey('a2')));
      await settle(tester);
      expect(find.byKey(StoryViewerScreen.storyKey('a2')), findsOneWidget);
      await tester.tap(find.byKey(StoryViewerScreen.closeKey));
      await settle(tester);

      await pump(
        tester,
        repo: FakeStoriesRepository(),
        initial: AppRoutes.storyArchive,
      );
      await settle(tester);
      expect(find.byKey(StoryArchiveScreen.emptyKey), findsOneWidget);
    });

    testWidgets('Arabic RTL at 360 dp and text scale 1.3: viewer and new '
        'story do not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = FakeStoriesRepository()
        ..stories['sara'] = [
          testStory('s1', text: 'نص قصير على الصورة مع @omar للتجربة'),
        ];
      await pump(
        tester,
        repo: repo,
        tray: const [sara],
        initial: AppRoutes.stories('sara'),
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(StoryViewerScreen.textKey), findsOneWidget);

      await pump(
        tester,
        repo: repo,
        initial: AppRoutes.newStory,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
        picker: FakePhotoPicker([jpegBytes]),
      );
      await tester.tap(find.byKey(NewStoryScreen.pickKey));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(NewStoryScreen.shareKey), findsOneWidget);
    });
  });
}
