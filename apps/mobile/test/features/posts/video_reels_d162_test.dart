// D162 (owner): the ➕ menu (post · reel · story · go live), video posts
// from the «فيديو» tab of «منشور جديد», reels (/reel/new) and the reels of
// «لحظات» (Moments) from `GET /feed/reels` with vertical paging and
// playback (v1.41-social, CONVENTIONS §11.14). Real controllers and
// screens; only the repositories, the device library and the video
// plugin are fakes.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/shell/feed_region.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/media/inline_video.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/create_media_step.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/create/new_reel_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/stories/presentation/new_story_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_inline_video.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _unavailable = ServerFailure(
  code: ErrorCode.mediaUploadsUnavailable,
  rawCode: 'MEDIA_UPLOADS_UNAVAILABLE',
  debugMessage: 'off',
  statusCode: 503,
);

void main() {
  group('➕ menu (owner, D162)', () {
    Future<void> pumpShell(WidgetTester tester, AppLanguage language) async {
      setViewport(tester, GoldenViewport.phone);
      await pumpKabsoApp(
        tester,
        language: language.name,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedUser: testUser(), me: testUser()),
          ),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('nav.create')));
      await tester.pumpAndSettle();
    }

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: four choices, localized, no overflow', (
        tester,
      ) async {
        final l10n = l10nFor(language);
        await pumpShell(tester, language);
        await openMenu(tester);
        expect(tester.takeException(), isNull);
        for (final (choice, title, hint) in [
          (CreateChoice.post, l10n.createMenuPost, l10n.createMenuPostHint),
          (CreateChoice.reel, l10n.createMenuReel, l10n.createMenuReelHint),
          (CreateChoice.story, l10n.createMenuStory, l10n.createMenuStoryHint),
          (CreateChoice.live, l10n.createMenuLive, l10n.createMenuLiveHint),
        ]) {
          final tile = find.byKey(CreateMenuSheet.choiceKey(choice));
          expect(tile, findsOneWidget);
          expect(
            find.descendant(of: tile, matching: find.text(title)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: tile, matching: find.text(hint)),
            findsOneWidget,
          );
          expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
        }
        // Order: post, reel, story, live from top to bottom.
        final ys = [
          for (final c in CreateChoice.values)
            tester.getTopLeft(find.byKey(CreateMenuSheet.choiceKey(c))).dy,
        ];
        expect(ys, orderedEquals([...ys]..sort()));
        if (language == AppLanguage.ar) {
          expect(
            Directionality.of(
              tester.element(
                find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
              ),
            ),
            TextDirection.rtl,
          );
        }
      });
    }

    testWidgets('each choice opens its flow; dismissing stays on the tab', (
      tester,
    ) async {
      await pumpShell(tester, AppLanguage.en);
      await openMenu(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(CreateScreen), findsNothing);
      expect(find.byKey(const Key('nav.home')), findsOneWidget);

      for (final (choice, screen) in [
        (CreateChoice.reel, NewReelScreen),
        (CreateChoice.story, NewStoryScreen),
        (CreateChoice.live, GoLiveScreen),
      ]) {
        await openMenu(tester);
        await tester.tap(find.byKey(CreateMenuSheet.choiceKey(choice)));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: '$choice');
        // Back to the shell.
        GoRouter.of(tester.element(find.byType(screen))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsNothing);
      }

      await openMenu(tester);
      await tester.tap(
        find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreateScreen), findsOneWidget);
    });
  });

  group('video posts (the «فيديو» tab)', () {
    Future<(FakeMediaRepository, FakePostsRepository, FakeVideoPicker)> pump(
      WidgetTester tester, {
      FakeMediaLibrary? library,
      AppLanguage language = AppLanguage.en,
      PickedVideo? systemPick,
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final media = FakeMediaRepository();
      final posts = FakePostsRepository();
      final picker = FakeVideoPicker(systemPick);
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
          GoRoute(
            path: '/reels',
            builder: (_, _) => const Scaffold(body: Text('moments')),
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
            mediaRepositoryProvider.overrideWithValue(media),
            postsRepositoryProvider.overrideWithValue(posts),
            videoPickerProvider.overrideWithValue(picker),
            mediaLibraryProvider.overrideWithValue(
              library ?? FakeMediaLibrary(),
            ),
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
              brightness: Brightness.dark,
              locale: language.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (media, posts, picker);
    }

    FakeMediaLibrary library({Map<String, PickedVideo?>? videos}) =>
        FakeMediaLibrary(
          access: LibraryAccess.granted,
          ids: ['p1', 'p2'],
          videos: videos ?? {'v1': testVideo(sourceId: 'v1')},
        );

    Future<void> videoTab(WidgetTester tester) async {
      await tester.tap(find.byKey(CreateMediaStep.tabVideoKey));
      await tester.pumpAndSettle();
    }

    testWidgets('the Video tab lists videos with their length; one video '
        'posts with progress and the poster; review notice', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final lib = library();
      final (media, posts, _) = await pump(tester, library: lib);
      await videoTab(tester);
      expect(lib.calls, contains('page:0:videos'));
      expect(find.byKey(CreateMediaStep.itemKey('p1')), findsNothing);
      final tile = find.byKey(CreateMediaStep.itemKey('v1'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('0:08')),
        findsOneWidget,
      );
      expect(find.text(en.createVideoUpTo), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byKey(CreateMediaStep.trayVideoKey), findsOneWidget);
      expect(lib.calls, contains('video:v1'));

      await tester.tap(find.byKey(CreateMediaStep.nextKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('create.video')), findsOneWidget);
      await tester.enterText(find.byKey(CreateScreen.textKey), 'my clip');
      media.gate = Completer<void>();
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pump();
      // The upload's progress, from the storage PUT.
      expect(find.text(en.createUploadingVideo(100)), findsOneWidget);
      expect(media.videoProgress, [0, 0.5, 1]);
      media.gate!.complete();
      await tester.pumpAndSettle();
      expect(media.videoUploads, ['post:video/mp4:4096:poster:image/jpeg']);
      expect(posts.created.single.mediaIds, ['v1']);
      expect(posts.created.single.reel, isFalse);
      expect(posts.created.single.text, 'my clip');
      // D162a: visible at once — the plain notice, not the review one.
      expect(find.text(en.createPosted), findsOneWidget);
      expect(find.text(en.createPostedVideoInReview), findsNothing);
    });

    testWidgets('a post holds photos or one video; limits are checked on the '
        'device', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final lib = library(
        videos: {
          'v1': testVideo(sourceId: 'v1'),
          'long': testVideo(sourceId: 'long', seconds: 200),
          'big': testVideo(sourceId: 'big', bytes: maxPostVideoBytes + 1),
          'gone': null,
        },
      );
      await pump(tester, library: lib);
      // All: photos and videos together.
      expect(find.byKey(CreateMediaStep.itemKey('p1')), findsOneWidget);
      expect(find.byKey(CreateMediaStep.itemKey('v1')), findsOneWidget);
      await tester.tap(find.byKey(CreateMediaStep.itemKey('p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CreateMediaStep.itemKey('v1')));
      await tester.pumpAndSettle();
      expect(find.text(en.createVideoOrPhotos), findsOneWidget);
      expect(find.byKey(CreateMediaStep.trayVideoKey), findsNothing);
      await tester.tap(find.byKey(CreateMediaStep.itemKey('p1')));
      await tester.pumpAndSettle();

      for (final (id, message) in [
        ('long', en.createVideoTooLong),
        ('big', en.createVideoTooLarge),
        ('gone', en.createVideoUnreadable),
      ]) {
        await tester.tap(find.byKey(CreateMediaStep.itemKey(id)));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget, reason: id);
        expect(find.byKey(CreateMediaStep.trayVideoKey), findsNothing);
      }

      // A video, then a photo: refused the other way round too.
      await tester.tap(find.byKey(CreateMediaStep.itemKey('v1')));
      await tester.pumpAndSettle();
      expect(find.byKey(CreateMediaStep.trayVideoKey), findsOneWidget);
      await tester.tap(find.byKey(CreateMediaStep.itemKey('p2')));
      await tester.pumpAndSettle();
      expect(find.text(en.createVideoOrPhotos), findsOneWidget);
      await tester.tap(find.byKey(CreateMediaStep.trayVideoRemoveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CreateMediaStep.trayVideoKey), findsNothing);
    });

    testWidgets('uploads switched off: the honest notice, no post, Retry', (
      tester,
    ) async {
      final en = l10nFor(AppLanguage.en);
      final (media, posts, _) = await pump(tester, library: library());
      await videoTab(tester);
      await tester.tap(find.byKey(CreateMediaStep.itemKey('v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CreateMediaStep.nextKey));
      await tester.pumpAndSettle();
      media.failWith = _unavailable;
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CreateScreen.failureKey), findsOneWidget);
      expect(find.text(en.createVideoUploadsUnavailable), findsOneWidget);
      expect(find.text(en.createPosted), findsNothing);
      expect(posts.created, isEmpty);
      expect(find.byKey(const Key('create.video')), findsOneWidget);
      // Retry when it works again: one video, one post.
      await tester.tap(find.byKey(CreateScreen.retryKey));
      await tester.pumpAndSettle();
      expect(media.videoUploads, hasLength(1));
      expect(posts.created, hasLength(1));
    });

    testWidgets('without a library: the system video picker', (tester) async {
      final (media, _, picker) = await pump(
        tester,
        systemPick: testVideo(contentType: 'video/quicktime'),
      );
      await videoTab(tester);
      // Only the video picker on the Video tab.
      expect(find.byKey(CreateMediaStep.pickDeviceKey), findsNothing);
      await tester.tap(find.byKey(CreateMediaStep.pickVideoKey));
      await tester.pumpAndSettle();
      expect(picker.calls, [maxPostVideoLength]);
      expect(find.byKey(CreateMediaStep.trayVideoKey), findsOneWidget);
      await tester.tap(find.byKey(CreateMediaStep.nextKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      expect(media.videoUploads.single, startsWith('post:video/quicktime:'));
    });

    testWidgets('Arabic, 360 dp, text ×1.3: Video tab and details fit', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final ar = l10nFor(AppLanguage.ar);
      await pump(
        tester,
        library: library(),
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      await videoTab(tester);
      await tester.tap(find.byKey(CreateMediaStep.itemKey('v1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(ar.createVideoLabel('0:08')), findsOneWidget);
      await tester.tap(find.byKey(CreateMediaStep.nextKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byKey(CreateScreen.textKey))),
        TextDirection.rtl,
      );
    });
  });

  group('reels (/reel/new)', () {
    Future<(FakeMediaRepository, FakePostsRepository, ProviderContainer)> pump(
      WidgetTester tester, {
      FakeMediaLibrary? library,
      AppLanguage language = AppLanguage.en,
    }) async {
      final media = FakeMediaRepository();
      final posts = FakePostsRepository();
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, _) => Scaffold(
              body: TextButton(
                key: const Key('start'),
                onPressed: () => context.push('/reel/new'),
                child: const Text('start'),
              ),
            ),
          ),
          GoRoute(path: '/reel/new', builder: (_, _) => const NewReelScreen()),
        ],
      );
      setViewport(tester, GoldenViewport.phone);
      final prefs = await testPrefs(language: language.name);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaRepositoryProvider.overrideWithValue(media),
          postsRepositoryProvider.overrideWithValue(posts),
          mediaLibraryProvider.overrideWithValue(
            library ??
                FakeMediaLibrary(
                  access: LibraryAccess.granted,
                  videos: {
                    'r1': testVideo(sourceId: 'r1', seconds: 30),
                    'long': testVideo(sourceId: 'long', seconds: 75),
                  },
                ),
          ),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();
      return (media, posts, container);
    }

    Future<void> choose(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(NewReelScreen.pickKey));
      await tester.pumpAndSettle();
      expect(find.byKey(NewReelScreen.sheetKey), findsOneWidget);
      await tester.tap(find.byKey(NewReelScreen.libraryItemKey(id)));
      await tester.pumpAndSettle();
    }

    testWidgets('pick a vertical video, caption, share: a REEL_VIDEO and a '
        'reel post; Moments reloads; back where it started', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final (media, posts, container) = await pump(tester);
      expect(find.text(en.reelNewBody), findsOneWidget);
      await choose(tester, 'r1');
      expect(find.byKey(NewReelScreen.previewKey), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      await tester.enterText(
        find.byKey(NewReelScreen.textKey),
        'sunset #kabso',
      );
      final before = container.read(reelsFeedProvider(HomeFeed.following));
      await tester.tap(find.byKey(NewReelScreen.shareKey));
      await tester.pumpAndSettle();
      expect(media.videoUploads, ['reel:video/mp4:4096:poster:image/jpeg']);
      final created = posts.created.single;
      expect(created.reel, isTrue);
      expect(created.mediaIds, ['v1']);
      expect(created.text, 'sunset #kabso');
      // D162a: visible at once.
      expect(find.text(en.reelShared), findsOneWidget);
      expect(find.byType(NewReelScreen), findsNothing);
      expect(find.byKey(const Key('start')), findsOneWidget);
      expect(before, isA<AsyncValue<Object?>>());
    });

    testWidgets('a reel the server holds (PENDING) says it waits for '
        'review', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final (_, posts, _) = await pump(tester);
      posts.holdNewPosts = true;
      await choose(tester, 'r1');
      await tester.tap(find.byKey(NewReelScreen.shareKey));
      await tester.pumpAndSettle();
      expect(find.text(en.reelSharedInReview), findsOneWidget);
    });

    testWidgets('a reel longer than 60 s is refused on the device', (
      tester,
    ) async {
      final en = l10nFor(AppLanguage.en);
      await pump(tester);
      await choose(tester, 'long');
      expect(find.text(en.reelTooLong), findsOneWidget);
      expect(find.byKey(NewReelScreen.previewKey), findsNothing);
    });

    testWidgets('a failed create keeps the reel; Retry reuses the uploaded '
        'video and the same key', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final (media, posts, _) = await pump(tester);
      await choose(tester, 'r1');
      posts.failWith = const NetworkFailure.offline();
      await tester.tap(find.byKey(NewReelScreen.shareKey));
      await tester.pumpAndSettle();
      expect(find.byKey(NewReelScreen.failureKey), findsOneWidget);
      expect(find.byType(NewReelScreen), findsOneWidget);
      await tester.tap(find.byKey(NewReelScreen.retryKey));
      await tester.pumpAndSettle();
      expect(media.videoUploads, hasLength(1));
      final keys = [
        for (final c in posts.calls)
          if (c.startsWith('create:')) c,
      ];
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(1));
      expect(find.text(en.reelShared), findsOneWidget);
    });

    testWidgets('uploads switched off: the honest notice, nothing shared', (
      tester,
    ) async {
      final en = l10nFor(AppLanguage.en);
      final (media, posts, _) = await pump(tester);
      await choose(tester, 'r1');
      media.failWith = _unavailable;
      await tester.tap(find.byKey(NewReelScreen.shareKey));
      await tester.pumpAndSettle();
      expect(find.text(en.createVideoUploadsUnavailable), findsOneWidget);
      expect(posts.created, isEmpty);
      expect(find.text(en.reelShared), findsNothing);
    });

    testWidgets('Arabic: the screen and the library sheet are RTL', (
      tester,
    ) async {
      final ar = l10nFor(AppLanguage.ar);
      await pump(tester, language: AppLanguage.ar);
      expect(find.text(ar.reelNewTitle), findsWidgets);
      await choose(tester, 'r1');
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byKey(NewReelScreen.textKey))),
        TextDirection.rtl,
      );
    });
  });

  group('Moments reels (GET /feed/reels)', () {
    Post reel(String id, {bool pending = false, bool isSelf = false}) =>
        testPost(id, reel: true, pending: pending, isSelf: isSelf);

    Future<FakeInlineVideos> pump(
      WidgetTester tester,
      FakePostsRepository posts,
    ) async {
      final videos = FakeInlineVideos();
      setViewport(tester, GoldenViewport.phone);
      await withClock(Clock.fixed(DateTime.utc(2026, 10, 21)), () async {
        await pumpScreen(
          tester,
          const FeedScreen(initialTab: HomeTab.reels, showSearch: false),
          postsRepository: posts,
          inlineVideos: videos,
        );
        await tester.pumpAndSettle();
      });
      return videos;
    }

    testWidgets('real reels page vertically; only the current one plays, '
        'muted first; the speaker unmutes', (tester) async {
      final posts = FakePostsRepository()
        ..reels[PostsFeedTab.trending] = [reel('r1'), reel('r2'), reel('r3')];
      final videos = await pump(tester, posts);
      expect(posts.calls, contains('reels:trending:'));
      expect(find.byType(HomeReelPage), findsWidgets);
      final first = videos.created.firstWhere((v) => v.url.contains('r1-v'));
      expect(first.plays, 1);
      expect(first.volumes, [0]);
      // Swipe up: the next reel plays, the first pauses.
      await tester.fling(
        find.byType(HomeReelsPager).first,
        const Offset(0, -600),
        2000,
      );
      await tester.pumpAndSettle();
      final second = videos.created.firstWhere((v) => v.url.contains('r2-v'));
      expect(second.plays, 1);
      expect(first.pauses, greaterThanOrEqualTo(1));
      // The speaker turns sound on.
      await tester.tap(find.byKey(InlineVideo.muteKey).hitTestable().first);
      await tester.pumpAndSettle();
      expect(second.volumes.last, 1);
    });

    testWidgets('your own reel waiting for review says so', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final posts = FakePostsRepository()
        ..reels[PostsFeedTab.trending] = [
          reel('mine', pending: true, isSelf: true),
        ];
      await pump(tester, posts);
      expect(find.byKey(HomeReelPage.pendingKey), findsOneWidget);
      expect(find.text(en.feedPostPending), findsOneWidget);
    });

    testWidgets('a reel that cannot play says so over its poster', (
      tester,
    ) async {
      final en = l10nFor(AppLanguage.en);
      final posts = FakePostsRepository()
        ..reels[PostsFeedTab.trending] = [reel('bad')];
      final videos = FakeInlineVideos()
        ..failing.add('https://media.example.test/media/bad-v/video.mp4');
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const FeedScreen(initialTab: HomeTab.reels, showSearch: false),
        postsRepository: posts,
        inlineVideos: videos,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(InlineVideo.errorKey), findsOneWidget);
      expect(find.text(en.videoCannotPlay), findsOneWidget);
    });

    testWidgets('a failed reels feed is an error with Try again, never '
        'fixtures', (tester) async {
      final en = l10nFor(AppLanguage.en);
      final posts = FakePostsRepository()
        ..reelsFailWith = const NetworkFailure.offline();
      await pump(tester, posts);
      expect(find.byType(HomeReelPage), findsNothing);
      // Offline has its own state (FeedRegion), with Try again.
      expect(find.byKey(FeedRegion.offlineKey), findsOneWidget);
      expect(find.text(en.homeReelsEmptyTitle), findsNothing);
      // Back online: Try again loads the real reels.
      posts.reels[PostsFeedTab.trending] = [reel('r9')];
      await tester.tap(find.text(en.actionRetry).first);
      await tester.pumpAndSettle();
      expect(find.byType(HomeReelPage), findsOneWidget);
    });

    testWidgets('a video post in the posts feed plays in place on tap', (
      tester,
    ) async {
      final posts = FakePostsRepository(
        feeds: {
          PostsFeedTab.trending: [testPost('vp', video: true)],
        },
      );
      final videos = FakeInlineVideos();
      setViewport(tester, GoldenViewport.phone);
      await pumpScreen(
        tester,
        const FeedScreen(showSearch: false),
        postsRepository: posts,
        inlineVideos: videos,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(FeedPostTile.videoKey), findsOneWidget);
      expect(find.byKey(InlineVideo.playKey), findsOneWidget);
      // Not autoplayed in the posts feed.
      expect(videos.created, isEmpty);
      // A double tap likes the post, so a single tap lands after the
      // double-tap window.
      await tester.tap(find.byKey(FeedPostTile.videoKey));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(videos.created.single.url, endsWith('/vp-v/video.mp4'));
      expect(videos.created.single.plays, 1);
      expect(find.byKey(InlineVideo.playKey), findsNothing);
      // A second tap pauses.
      await tester.tap(find.byKey(FeedPostTile.videoKey));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(videos.created.single.pauses, 1);
    });
  });
}
