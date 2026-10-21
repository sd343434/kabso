// KL-060 part B: creating a post — the upload flow (presigned PUT, no token
// to storage), device checks on picked photos, idempotent publishing and the
// Create screen's states.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

abstract final class KComposeTest {
  /// Photo width + gap in the strip.
  static const double step = 88 + 6;
}

const _uploadsOff = ServerFailure(
  code: ErrorCode.mediaUploadsUnavailable,
  rawCode: 'MEDIA_UPLOADS_UNAVAILABLE',
  debugMessage: 'off',
  statusCode: 503,
);

const _serverError = ServerFailure(
  code: ErrorCode.internalError,
  rawCode: 'INTERNAL_ERROR',
  debugMessage: 'boom',
  statusCode: 500,
);

void main() {
  group('sniffImageType (the bytes decide, §11.1)', () {
    test('JPEG, PNG and WebP; anything else is refused', () {
      expect(sniffImageType(jpegBytes), 'image/jpeg');
      expect(
        sniffImageType(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 13, 10, 26, 10, 0]),
        ),
        'image/png',
      );
      expect(
        sniffImageType(
          Uint8List.fromList([
            ...'RIFF'.codeUnits,
            0,
            0,
            0,
            0,
            ...'WEBP'.codeUnits,
          ]),
        ),
        'image/webp',
      );
      expect(sniffImageType(heicBytes), isNull);
      expect(sniffImageType(Uint8List.fromList('GIF89a'.codeUnits)), isNull);
      expect(sniffImageType(Uint8List(0)), isNull);
    });
  });

  group('MediaRepositoryImpl', () {
    test('slot → PUT to the presigned URL with exactly its headers and no '
        'bearer token → complete', () async {
      final http = FakeHttpAdapter()
        ..on('POST', '/api/v1/media/uploads', (o) {
          expect(o.data, {
            'kind': 'POST_IMAGE',
            'contentType': 'image/jpeg',
            'byteSize': jpegBytes.length,
          });
          return FakeResponse(
            201,
            body: {
              'uploadId': 'u1',
              'uploadUrl': 'https://storage.example.test/uploads/me/u1?sig=x',
              'method': 'PUT',
              'headers': {
                'Content-Type': 'image/jpeg',
                'Content-Length': '${jpegBytes.length}',
              },
              'expiresAt': '2026-10-20T10:00:00Z',
            },
          );
        })
        ..on('PUT', '/uploads/me/u1', (_) => const FakeResponse(200))
        ..on(
          'POST',
          '/api/v1/media/uploads/u1/complete',
          (_) => const FakeResponse(
            200,
            body: {
              'id': 'u1',
              'type': 'IMAGE',
              'status': 'READY',
              'width': 1080,
              'height': 810,
              'blurhash': 'L00',
              'url': 'https://cdn.example.test/media/u1/1080.webp',
              'thumbUrl': 'https://cdn.example.test/media/u1/320.webp',
            },
          ),
        );
      final api = Dio(
        BaseOptions(
          baseUrl: 'https://api.example.test/api/v1',
          headers: {'Authorization': 'Bearer secret-token'},
        ),
      )..httpClientAdapter = http;
      final storage = Dio()..httpClientAdapter = http;
      final asset = await MediaRepositoryImpl(
        api,
        storage,
      ).uploadPhoto(jpegBytes, 'image/jpeg');
      expect(asset.id, 'u1');
      expect(asset.aspect, closeTo(1080 / 810, 1e-9));
      final put = http.requestsTo('PUT', '/uploads/me/u1').single;
      expect(put.uri.host, 'storage.example.test');
      expect(put.uri.queryParameters['sig'], 'x');
      expect(put.headers['Authorization'], isNull);
      expect(put.headers['Content-Type'] ?? put.contentType, 'image/jpeg');
      expect(put.headers['Content-Length'], '${jpegBytes.length}');
      expect(http.requests.map((r) => '${r.method} ${r.uri.path}'), [
        'POST /api/v1/media/uploads',
        'PUT /uploads/me/u1',
        'POST /api/v1/media/uploads/u1/complete',
      ]);
    });

    test('a 503 MEDIA_UPLOADS_UNAVAILABLE becomes its failure', () async {
      final http = FakeHttpAdapter()
        ..on(
          'POST',
          '/api/v1/media/uploads',
          (_) => FakeResponse(
            503,
            body: errorEnvelope('MEDIA_UPLOADS_UNAVAILABLE', 'off'),
          ),
        );
      final api = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
        ..httpClientAdapter = http;
      await expectLater(
        MediaRepositoryImpl(api, Dio()).uploadPhoto(jpegBytes, 'image/jpeg'),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.code,
            'code',
            ErrorCode.mediaUploadsUnavailable,
          ),
        ),
      );
    });

    test(
      'createPost sends the Idempotency-Key and only the set fields',
      () async {
        final http = FakeHttpAdapter()
          ..on('POST', '/api/v1/posts', (o) {
            expect(o.headers['Idempotency-Key'], 'k-1');
            expect(o.data, {
              'text': 'hi',
              'mediaIds': ['a1'],
            });
            return FakeResponse(201, body: postJson('p1'));
          });
        final api = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http;
        final post = await PostsRepositoryImpl(api).createPost(
          idempotencyKey: 'k-1',
          text: 'hi',
          mediaIds: const ['a1'],
          location: '',
        );
        expect(post.id, 'p1');
      },
    );
  });

  group('ComposeController', () {
    late FakeMediaRepository media;
    late FakePostsRepository posts;
    late ProviderContainer c;

    setUp(() {
      media = FakeMediaRepository();
      posts = FakePostsRepository();
      c = ProviderContainer.test(
        overrides: [
          mediaRepositoryProvider.overrideWithValue(media),
          postsRepositoryProvider.overrideWithValue(posts),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
    });

    ComposeController ctl() => c.read(composeControllerProvider.notifier);

    test('refuses HEIC (by bytes) and more than 10 photos', () {
      final rejected = ctl().addPhotos([
        heicBytes,
        for (var i = 0; i < 11; i++) jpegBytes,
      ]);
      expect(rejected, {
        PhotoRejection.unsupportedType,
        PhotoRejection.tooMany,
      });
      expect(c.read(composeControllerProvider).photos, hasLength(10));
    });

    test('photos upload, then the post is created with them', () async {
      ctl().addPhotos([jpegBytes, jpegBytes]);
      final post = await ctl().publish(text: ' Sunset ', location: ' Amman ');
      expect(post, isNotNull);
      expect(media.uploads, ['image/jpeg', 'image/jpeg']);
      expect(posts.created.single.text, 'Sunset');
      expect(posts.created.single.location, 'Amman');
      expect(posts.created.single.mediaIds, ['a1', 'a2']);
      // The draft starts clean.
      expect(c.read(composeControllerProvider).photos, isEmpty);
    });

    test('a failed create keeps the draft; Retry reuses the key and does not '
        're-upload; changed content gets a new key', () async {
      ctl().addPhotos([jpegBytes]);
      posts.failWith = _serverError;
      expect(await ctl().publish(text: 'one', location: ''), isNull);
      final failed = c.read(composeControllerProvider);
      expect(failed.failure, isA<ServerFailure>());
      expect(failed.photos.single.assetId, 'a1');
      expect(await ctl().publish(text: 'one', location: ''), isNotNull);
      expect(media.uploads, hasLength(1));
      final firstKey = posts.calls.first.split(':').last;
      expect(posts.calls, ['create:$firstKey', 'create:$firstKey']);

      // A new draft, failed once, then edited: a new key.
      posts.failWith = _serverError;
      await ctl().publish(text: 'two', location: '');
      await ctl().publish(text: 'two edited', location: '');
      final keys = posts.calls.map((s) => s.split(':').last).toList();
      expect(keys[2], isNot(firstKey));
      expect(keys[3], isNot(keys[2]));
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(keys[3]), isTrue);
    });

    test('uploads switched off: the draft and its photos are kept', () async {
      ctl().addPhotos([jpegBytes]);
      media.failWith = _uploadsOff;
      expect(await ctl().publish(text: 'x', location: ''), isNull);
      final s = c.read(composeControllerProvider);
      expect(
        (s.failure! as ServerFailure).code,
        ErrorCode.mediaUploadsUnavailable,
      );
      expect(s.photos, hasLength(1));
      expect(posts.created, isEmpty);
    });

    test('empty drafts are not sent', () async {
      expect(await ctl().publish(text: '   ', location: 'x'), isNull);
      expect(posts.calls, isEmpty);
    });
  });

  group('CreateScreen', () {
    Future<
      (FakeMediaRepository, FakePostsRepository, FakePhotoPicker, GoRouter)
    >
    pump(
      WidgetTester tester, {
      AppLanguage language = AppLanguage.en,
      List<Uint8List> picks = const [],
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final media = FakeMediaRepository();
      final posts = FakePostsRepository();
      final picker = FakePhotoPicker(picks);
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
          GoRoute(
            path: '/reels',
            builder: (_, _) => const Scaffold(body: Text('posts tab')),
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
            photoPickerProvider.overrideWithValue(picker),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
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
      return (media, posts, picker, router);
    }

    InkWell shareInk(WidgetTester tester) => tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(CreateScreen.shareKey),
        matching: find.byType(InkWell),
      ),
    );
    bool shareEnabled(WidgetTester tester) => shareInk(tester).onTap != null;
    bool shareBusy() => find
        .descendant(
          of: find.byKey(CreateScreen.shareKey),
          matching: find.byType(CircularProgressIndicator),
        )
        .evaluate()
        .isNotEmpty;

    testWidgets('Share is off for an empty draft; a text post is shared and '
        'Posts opens with a message', (tester) async {
      final (_, posts, _, router) = await pump(tester);
      expect(shareEnabled(tester), isFalse);
      await tester.enterText(find.byKey(CreateScreen.textKey), 'Hello #kabso');
      await tester.pump();
      expect(shareEnabled(tester), isTrue);
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      expect(posts.created.single.text, 'Hello #kabso');
      expect(router.state.uri.path, '/reels');
      expect(find.text(_en.createPosted), findsOneWidget);
    });

    testWidgets('photos: added, removed, uploaded; the message says the post '
        'waits for review', (tester) async {
      final (media, posts, picker, _) = await pump(
        tester,
        picks: [jpegBytes, jpegBytes, heicBytes],
      );
      await tester.tap(find.byKey(CreateScreen.addPhotosKey));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.text(_en.createPhotoUnsupported), findsOneWidget);
      expect(find.byKey(CreateScreen.photoKey(0)), findsOneWidget);
      expect(find.byKey(CreateScreen.photoKey(1)), findsOneWidget);
      await tester.tap(find.byKey(CreateScreen.removePhotoKey(0)));
      await tester.pumpAndSettle();
      expect(find.byKey(CreateScreen.photoKey(0)), findsNothing);
      // Photos alone can be shared.
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      expect(media.uploads, ['image/jpeg']);
      expect(posts.created.single.mediaIds, ['a1']);
      expect(find.text(_en.createPostedInReview), findsOneWidget);
    });

    testWidgets('progress while uploading; failure banner with Retry keeps '
        'the draft', (tester) async {
      final (media, posts, _, router) = await pump(tester, picks: [jpegBytes]);
      await tester.tap(find.byKey(CreateScreen.addPhotosKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(CreateScreen.textKey), 'Dead Sea');
      media.failWith = _uploadsOff;
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      expect(find.byKey(CreateScreen.failureKey), findsOneWidget);
      expect(find.text(_en.createUploadsUnavailable), findsOneWidget);
      expect(find.text('Dead Sea'), findsOneWidget);
      expect(router.state.uri.path, '/create');

      final gate = media.gate = Completer<void>();
      await tester.tap(find.byKey(CreateScreen.retryKey));
      await tester.pump();
      expect(find.byKey(CreateScreen.progressKey), findsOneWidget);
      expect(find.text(_en.createUploading(1, 1)), findsOneWidget);
      expect(shareBusy(), isTrue);
      gate.complete();
      await tester.pumpAndSettle();
      expect(posts.created.single.text, 'Dead Sea');
      expect(router.state.uri.path, '/reels');
    });

    // ReorderableListView splits `padding` between header and list as if
    // the strip were LTR; in Arabic that once put 16 lp between the add
    // tile and the first photo. The gaps must be the same in both
    // directions.
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('strip insets and gaps (${language.name})', (tester) async {
        await pump(tester, language: language, picks: [jpegBytes, jpegBytes]);
        await tester.tap(find.byKey(CreateScreen.addPhotosKey));
        await tester.pumpAndSettle();
        final width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final add = tester.getRect(find.byKey(CreateScreen.addPhotosKey));
        // The photo's key sits on the card plus its end gap.
        final p0 = tester.getRect(find.byKey(CreateScreen.photoKey(0)));
        final rtl = language == AppLanguage.ar;
        expect(rtl ? width - add.right : add.left, KCompose.inset);
        expect(add.width, KCompose.addWidth);
        expect(
          rtl ? add.left - p0.right : p0.left - add.right,
          KCompose.stripGap,
        );
        expect(p0.width, KCompose.photoWidth + KCompose.stripGap);
      });
    }

    testWidgets('photos scroll sideways; the handle reorders them (post '
        'order)', (tester) async {
      final (_, posts, _, _) = await pump(
        tester,
        picks: [for (var i = 0; i < 4; i++) jpegBytes],
      );
      await tester.tap(find.byKey(CreateScreen.addPhotosKey));
      await tester.pumpAndSettle();
      final strip = find.descendant(
        of: find.byKey(CreateScreen.stripKey),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(strip.first).position;
      expect(position.maxScrollExtent, greaterThan(0));
      // Drag photo 0 past photo 1 by its handle.
      final handle = find.byKey(CreateScreen.handleKey(0));
      await tester.timedDrag(
        handle,
        const Offset(KComposeTest.step * 2, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CreateScreen)),
      );
      final order = container
          .read(composeControllerProvider)
          .photos
          .map((p) => p.localId)
          .toList();
      expect(order, isNot([0, 1, 2, 3]));
      expect(order.toSet(), {0, 1, 2, 3});
      await tester.enterText(find.byKey(CreateScreen.textKey), 'x');
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      // Uploaded in the new order: a1 is the first photo of the post.
      expect(posts.created.single.mediaIds, ['a1', 'a2', 'a3', 'a4']);
    });

    testWidgets('caption tools: # inserts a tag that appears in the hashtag '
        'row; @ inserts a searched person; emoji inserts', (tester) async {
      final (_, posts, _, _) = await pump(tester);
      posts.people = const [
        UserSummary(
          id: 'u-omar',
          username: 'omar',
          displayName: 'Omar',
          avatarUrl: null,
        ),
      ];
      await tester.enterText(find.byKey(CreateScreen.textKey), 'Sunset');
      await tester.tap(find.byKey(CreateScreen.hashtagToolKey));
      await tester.pump();
      tester.testTextInput.enterText('Sunset #petra');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(CreateScreen.hashtagsRowKey),
          matching: find.text('#petra'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(CreateScreen.mentionToolKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create.mention.query')),
        'om',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(posts.calls, contains('searchUsers:om'));
      await tester.tap(find.byKey(const ValueKey('create.mention.omar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CreateScreen.emojiKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create.emoji.🔥')));
      await tester.pumpAndSettle();
      final text = tester
          .widget<TextField>(find.byKey(CreateScreen.textKey))
          .controller!
          .text;
      expect(text, contains('#petra'));
      expect(text, contains('@omar'));
      expect(text, contains('🔥'));
      expect(find.text(_en.createMentionSome), findsOneWidget);
    });

    testWidgets('place and advanced settings are sent with the post', (
      tester,
    ) async {
      final (_, posts, _, _) = await pump(tester);
      await tester.tap(find.byKey(CreateScreen.locationKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create.place.field')),
        ' Petra ',
      );
      await tester.tap(find.byKey(const Key('create.place.save')));
      await tester.pumpAndSettle();
      expect(find.text('Petra'), findsOneWidget);
      await tester.ensureVisible(find.byKey(CreateScreen.advancedKey));
      await tester.tap(find.byKey(CreateScreen.advancedKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('create.advanced.who.followers')),
      );
      await tester.tap(find.byKey(const Key('create.advanced.hideLikes')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('create.advanced.save')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(CreateScreen.textKey));
      await tester.enterText(find.byKey(CreateScreen.textKey), 'Rose city');
      await tester.pump();
      await tester.tap(find.byKey(CreateScreen.shareKey));
      await tester.pumpAndSettle();
      final sent = posts.created.single;
      expect(sent.location, 'Petra');
      expect(sent.settings.toJson(), {
        'whoCanComment': 'FOLLOWERS',
        'hideLikeCount': true,
      });
    });

    testWidgets('Close asks before discarding a draft; an empty draft just '
        'leaves', (tester) async {
      final (_, posts, _, router) = await pump(tester);
      await tester.enterText(find.byKey(CreateScreen.textKey), 'half');
      await tester.tap(find.byKey(CreateScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.createDiscardTitle), findsOneWidget);
      await tester.tap(find.text(_en.createKeepEditing));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/create');
      await tester.tap(find.byKey(CreateScreen.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create.discard')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/reels');
      expect(posts.created, isEmpty);
    });

    testWidgets('short clips and music are disabled ("soon"); 360 dp at '
        'text scale 1.3 does not overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      expect(tester.takeException(), isNull);
      final soon = find.bySemanticsLabel(
        RegExp(l10nFor(AppLanguage.ar).createTypeMusic),
      );
      expect(soon, findsWidgets);
    });

    testWidgets('Arabic RTL: copy is localized, text over the limit blocks '
        'Share with a red counter', (tester) async {
      final ar = l10nFor(AppLanguage.ar);
      await pump(tester, language: AppLanguage.ar);
      expect(find.text(ar.createTitle), findsOneWidget);
      expect(find.text(ar.createAddMore), findsOneWidget);
      expect(find.text('0/$maxPostText'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byKey(CreateScreen.textKey))),
        TextDirection.rtl,
      );
      // The rows' chevron mirrors itself (matchTextDirection); picking the
      // left chevron in RTL flipped it back to point at the start.
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      await tester.enterText(
        find.byKey(CreateScreen.textKey),
        'ا' * (maxPostText + 1),
      );
      await tester.pump();
      expect(find.text('${maxPostText + 1}/$maxPostText'), findsOneWidget);
      expect(shareEnabled(tester), isFalse);
    });
  });
}
