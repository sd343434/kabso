// D168 (owner, from the phone): the profile polish —
// 1. media grids list the newest photo or video first;
// 3. post videos at most 90 s, reels 60 s: library tiles over the limit are
//    faded, marked and say why;
// 4. the own profile page shows the photo without the heart frame;
// 5. «تعديل الملف الشخصي» works: name, bio, username, photo (library or
//    camera, square crop, AVATAR upload, PUT / DELETE /me/avatar), honest
//    states, RTL / LTR, 360×800 at ×1.3.
// (2, the Me hub's profile icon, is in me_hub_screen_test.dart.)

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/create/create_media_step.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/create/new_reel_screen.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/avatar_crop_screen.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import '../premium/premium_harness.dart' show FixedSession;

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

const _unavailable = ServerFailure(
  code: ErrorCode.mediaUploadsUnavailable,
  rawCode: 'MEDIA_UPLOADS_UNAVAILABLE',
  debugMessage: 'uploads off',
  statusCode: 503,
);

User _user({String? avatarUrl, String? bio = 'Music every evening'}) =>
    testUser().copyWith(avatarUrl: avatarUrl, bio: bio);

/// Records the calls; answers like the server.
class _FakeProfileEdit implements ProfileEditRepository {
  new(this.user);

  User user;
  final List<String> calls = [];
  AppFailure? failWith;

  void _fail() {
    if (failWith case final f?) {
      failWith = null;
      throw f;
    }
  }

  @override
  Future<User> updateDisplayName(String displayName) async {
    calls.add('name:$displayName');
    _fail();
    return user = user.copyWith(displayName: displayName);
  }

  @override
  Future<User> updateBio(String? bio) async {
    calls.add('bio:$bio');
    _fail();
    return user = user.copyWith(bio: bio);
  }

  @override
  Future<User> updateProfileFields(ProfileFieldsChange change) async {
    calls.add('fields:${change.toJson()}');
    _fail();
    return user;
  }

  @override
  Future<String> setAvatar(String mediaId) async {
    calls.add('avatar:$mediaId');
    _fail();
    final url = 'https://media.example.test/media/$mediaId/640.webp';
    user = user.copyWith(avatarUrl: url);
    return url;
  }

  @override
  Future<void> removeAvatar() async {
    calls.add('remove');
    _fail();
    user = user.copyWith(avatarUrl: null);
  }
}

class _FakePicker implements AvatarPhotoPicker {
  new(this.bytes);

  final Uint8List? bytes;
  final List<AvatarSource> calls = [];

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    calls.add(source);
    return bytes;
  }
}

/// A real [width] × [height] PNG (decodable by the crop screen).
Future<Uint8List> _png(WidgetTester tester, int width, int height) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder)
        ..drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..color = const Color(0xFF2266AA),
        )
        ..drawRect(
          Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
          Paint()..color = const Color(0xFFAA2266),
        );
      final image = await recorder.endRecording().toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

/// Lets the platform decode / encode, then settles.
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

class _Edit {
  new(this.repo, this.media, this.picker);

  final _FakeProfileEdit repo;
  final FakeMediaRepository media;
  final _FakePicker picker;
}

Future<_Edit> _pumpEdit(
  WidgetTester tester, {
  User? user,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Uint8List? pick,
}) async {
  final start = user ?? _user();
  final repo = _FakeProfileEdit(start);
  final media = FakeMediaRepository();
  final picker = _FakePicker(pick);
  final router = GoRouter(
    initialLocation: AppRoutes.editProfile,
    routes: [
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.changeUsername,
        builder: (_, _) => const Text('page username'),
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        sessionControllerProvider.overrideWith(() => FixedSession(start)),
        meProvider.overrideWith((ref) => start),
        profileStatsProvider.overrideWith((ref, _) => apiProfile(isSelf: true)),
        profileEditRepositoryProvider.overrideWithValue(repo),
        mediaRepositoryProvider.overrideWithValue(media),
        avatarPhotoPickerProvider.overrideWithValue(picker),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Edit(repo, media, picker);
}

Finder _inRow(Key row, String text) =>
    find.descendant(of: find.byKey(row), matching: find.text(text));

void main() {
  group('1. media grids: newest first', () {
    const channel = MethodChannel('com.fluttercandies/photo_manager');
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    for (final filter in LibraryFilter.values) {
      testWidgets('the device library asks for creation date, descending '
          '(${filter.name})', (tester) async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              throw PlatformException(code: 'stop');
            });
        await expectLater(
          DeviceMediaLibrary().page(0, filter: filter),
          throwsA(isA<PlatformException>()),
        );
        final call = calls.singleWhere((c) => c.method == 'getAssetPathList');
        final option =
            ((call.arguments as Map)['option'] as Map)['child'] as Map;
        // OrderOptionType.createDate (index 0), not ascending.
        expect(option['orders'], [
          {'type': 0, 'asc': false},
        ]);
        // No date window that would hide photos taken later.
        expect((option['createDate'] as Map)['ignore'], isTrue);
      });
    }

    test('one shared order for every grid', () {
      expect(DeviceMediaLibrary.newestFirst.orders, hasLength(1));
      expect(DeviceMediaLibrary.newestFirst.orders.single.asc, isFalse);
    });
  });

  group('3. videos over the limit are marked in the library', () {
    test('limits: posts 90 s, reels 60 s, + 500 ms padding', () {
      expect(maxPostVideoLength, const Duration(seconds: 90));
      expect(maxReelVideoLength, const Duration(seconds: 60));
      expect(isVideoTooLong(const Duration(seconds: 90), reel: false), false);
      expect(
        isVideoTooLong(const Duration(milliseconds: 90500), reel: false),
        false,
      );
      expect(
        isVideoTooLong(const Duration(milliseconds: 90501), reel: false),
        true,
      );
      expect(isVideoTooLong(const Duration(seconds: 61), reel: true), true);
      expect(
        checkVideo(testVideo(seconds: 91), reel: false),
        VideoRejection.tooLong,
      );
      expect(checkVideo(testVideo(seconds: 90), reel: false), isNull);
    });

    Future<FakeMediaLibrary> pumpCreate(
      WidgetTester tester, {
      AppLanguage language = AppLanguage.en,
      GoldenViewport viewport = GoldenViewport.phone,
      double textScale = 1,
    }) async {
      final library = FakeMediaLibrary(
        access: LibraryAccess.granted,
        videos: {
          'ok': testVideo(sourceId: 'ok', seconds: 90),
          'long': testVideo(sourceId: 'long', seconds: 91),
        },
      );
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
        ],
      );
      await loadAppFonts();
      setViewport(tester, viewport);
      final prefs = await testPrefs(language: language.name);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaRepositoryProvider.overrideWithValue(FakeMediaRepository()),
            postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
            mediaLibraryProvider.overrideWithValue(library),
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CreateMediaStep.tabVideoKey));
      await tester.pumpAndSettle();
      return library;
    }

    for (final language in AppLanguage.values) {
      testWidgets('Create: a 91 s video is faded, marked and says why; '
          '90 s is fine (${language.name})', (tester) async {
        final semantics = tester.ensureSemantics();
        final l10n = l10nFor(language);
        final library = await pumpCreate(tester, language: language);
        expect(find.text(l10n.createVideoUpTo), findsOneWidget);
        final long = find.byKey(CreateMediaStep.itemKey('long'));
        final ok = find.byKey(CreateMediaStep.itemKey('ok'));
        expect(
          tester.getSemantics(long).label,
          l10n.createLibraryVideoTooLong('1:31', 90),
        );
        expect(tester.getSemantics(ok).label, l10n.createVideoLabel('1:30'));
        expect(
          find.descendant(
            of: long,
            matching: find.byIcon(Icons.timer_off_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: ok,
            matching: find.byIcon(Icons.timer_off_rounded),
          ),
          findsNothing,
        );
        await tester.tap(long);
        await tester.pumpAndSettle();
        expect(find.text(l10n.createVideoTooLong), findsOneWidget);
        // Nothing was read from the device for it.
        expect(library.calls, isNot(contains('video:long')));
        expect(find.byKey(CreateMediaStep.trayVideoKey), findsNothing);
        await tester.tap(ok);
        await tester.pumpAndSettle();
        expect(find.byKey(CreateMediaStep.trayVideoKey), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('Create: Arabic 360×800 at ×1.3 — no overflow', (tester) async {
      await pumpCreate(
        tester,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(_ar.createVideoUpTo), findsOneWidget);
    });

    testWidgets('the reel sheet: 61 s is marked and stays; 60 s is chosen', (
      tester,
    ) async {
      final library = FakeMediaLibrary(
        access: LibraryAccess.granted,
        videos: {
          'r60': testVideo(sourceId: 'r60', seconds: 60),
          'r61': testVideo(sourceId: 'r61', seconds: 61),
        },
      );
      final router = GoRouter(
        initialLocation: '/reel/new',
        routes: [
          GoRoute(path: '/reel/new', builder: (_, _) => const NewReelScreen()),
        ],
      );
      setViewport(tester, GoldenViewport.phone);
      final prefs = await testPrefs();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaRepositoryProvider.overrideWithValue(FakeMediaRepository()),
            postsRepositoryProvider.overrideWithValue(FakePostsRepository()),
            mediaLibraryProvider.overrideWithValue(library),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            currentUserProvider.overrideWithValue(testUser()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: buildAppTheme(
              brightness: Brightness.dark,
              locale: AppLanguage.en.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.tap(find.byKey(NewReelScreen.pickKey));
      await tester.pumpAndSettle();
      final long = find.byKey(NewReelScreen.libraryItemKey('r61'));
      expect(
        tester.getSemantics(long).label,
        _en.createLibraryVideoTooLong('1:01', 60),
      );
      await tester.tap(long);
      await tester.pumpAndSettle();
      expect(find.text(_en.reelTooLong), findsOneWidget);
      expect(find.byKey(NewReelScreen.sheetKey), findsOneWidget);
      expect(library.calls, isNot(contains('video:r61')));
      await tester.tap(find.byKey(NewReelScreen.libraryItemKey('r60')));
      await tester.pumpAndSettle();
      expect(find.byKey(NewReelScreen.sheetKey), findsNothing);
      expect(find.byKey(NewReelScreen.previewKey), findsOneWidget);
      semantics.dispose();
    });
  });

  group('4. the own profile page: the photo without a frame', () {
    for (final language in AppLanguage.values) {
      testWidgets('a couple with the Special Frame: the plain photo '
          '(${language.name})', (tester) async {
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          const ProfileScreen(),
          language: language,
          overrides: [
            meProvider.overrideWith((ref) => _user()),
            profileStatsProvider.overrideWith(
              (ref, _) => apiProfile(isSelf: true).copyWith(
                cp: ProfileCp(
                  id: 'cp-1',
                  partner: const UserSummary(
                    id: 'u-omar',
                    username: 'omar',
                    displayName: 'Omar',
                    avatarUrl: null,
                  ),
                  since: DateTime.utc(2026, 10, 2),
                  level: 4,
                  levelName: 'Diamond couple',
                  points: 6000,
                  privileges: const ['SPECIAL_FRAME'],
                ),
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ProfileHeaderView.cpFrameKey), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(ProfileHeaderView.avatarKey),
            matching: find.byType(KAvatar),
          ),
          findsOneWidget,
        );
      });
    }
  });

  group('5. edit profile', () {
    for (final language in AppLanguage.values) {
      // D175: the owner answered the D168 questions — links, gender and
      // category are editors now, the grid row is the pin hint and Privacy
      // opens the privacy settings (they were "Coming soon" rows here).
      testWidgets('rows: name, username and bio open editors; no row is '
          '"Coming soon" any more; no dead Save (${language.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final l10n = l10nFor(language);
        await _pumpEdit(tester, language: language);
        expect(find.text(l10n.profileEditTitle), findsOneWidget);
        expect(find.text(l10n.profileEditSave), findsNothing);
        for (final (key, value) in [
          (EditProfileScreen.nameKey, 'Layla'),
          (EditProfileScreen.usernameKey, 'layla.k'),
          (EditProfileScreen.bioKey, 'Music every evening'),
        ]) {
          expect(_inRow(key, value), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(InkWell),
            ),
            findsOneWidget,
          );
          expect(
            tester.getSemantics(find.byKey(key)).flagsCollection.isButton,
            isTrue,
          );
        }
        // The chevron points to the reading end (the icon mirrors in RTL).
        final chevron = find.descendant(
          of: find.byKey(EditProfileScreen.nameKey),
          matching: find.byIcon(Icons.chevron_right_rounded),
        );
        expect(chevron, findsOneWidget);
        expect(Icons.chevron_right_rounded.matchTextDirection, isTrue);
        expect(
          Directionality.of(tester.element(chevron)),
          language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
        );
        for (final key in [
          EditProfileScreen.linksKey,
          EditProfileScreen.genderKey,
          EditProfileScreen.categoryKey,
          EditProfileScreen.privacyKey,
        ]) {
          await tester.scrollUntilVisible(find.byKey(key), 100);
          expect(_inRow(key, l10n.profileEditSoon), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(InkWell),
            ),
            findsOneWidget,
          );
        }
        await tester.scrollUntilVisible(
          find.byKey(EditProfileScreen.gridKey),
          100,
        );
        expect(
          _inRow(EditProfileScreen.gridKey, l10n.profileEditPinHint),
          findsOneWidget,
        );
        expect(find.text(l10n.profileEditSoon), findsNothing);
        expect(
          _inRow(EditProfileScreen.privacyKey, l10n.profilePrivacyPublic),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextButton>(find.byKey(EditProfileScreen.photoKey))
              .onPressed,
          isNotNull,
        );
        semantics.dispose();
      });
    }

    testWidgets('the name: saved with PATCH /me, shown at once', (
      tester,
    ) async {
      final edit = await _pumpEdit(tester);
      await tester.tap(find.byKey(EditProfileScreen.nameKey));
      await tester.pumpAndSettle();
      final save = find.byKey(EditProfileFieldKeys.save);
      // Unchanged: nothing to save.
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(find.byKey(EditProfileFieldKeys.field), '');
      await tester.pump();
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(find.byKey(EditProfileFieldKeys.field), 'x' * 51);
      await tester.pump();
      expect(find.text(_en.displayNameTooLong), findsOneWidget);
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(
        find.byKey(EditProfileFieldKeys.field),
        '  Nour  ',
      );
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(edit.repo.calls, ['name:Nour']);
      expect(find.text(_en.profileEditSaved), findsOneWidget);
      expect(_inRow(EditProfileScreen.nameKey, 'Nour'), findsOneWidget);
    });

    testWidgets("the name: the server's reserved_term shows under the field", (
      tester,
    ) async {
      final edit = await _pumpEdit(tester);
      edit.repo.failWith = const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'reserved',
        statusCode: 400,
        details: [FieldIssue(field: 'displayName', issue: 'reserved_term')],
      );
      await tester.tap(find.byKey(EditProfileScreen.nameKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EditProfileFieldKeys.field), 'Admin');
      await tester.pump();
      await tester.tap(find.byKey(EditProfileFieldKeys.save));
      await tester.pumpAndSettle();
      expect(find.text(_en.displayNameReserved), findsOneWidget);
      expect(find.byKey(EditProfileFieldKeys.field), findsOneWidget);
      // Typing clears the server's message.
      await tester.enterText(find.byKey(EditProfileFieldKeys.field), 'Adam');
      await tester.pump();
      expect(find.text(_en.displayNameReserved), findsNothing);
    });

    testWidgets('the bio: up to 300 characters and 5 lines; empty clears it', (
      tester,
    ) async {
      final edit = await _pumpEdit(tester);
      await tester.tap(find.byKey(EditProfileScreen.bioKey));
      await tester.pumpAndSettle();
      final field = find.byKey(EditProfileFieldKeys.field);
      final save = find.byKey(EditProfileFieldKeys.save);
      await tester.enterText(field, '1\n2\n3\n4\n5\n6');
      await tester.pump();
      expect(find.text(_en.profileEditBioTooLong(300, 5)), findsOneWidget);
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(field, 'ب' * 301);
      await tester.pump();
      expect(tester.widget<TextButton>(save).onPressed, isNull);
      await tester.enterText(field, 'Line one  \nLine two\n\n');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(edit.repo.calls, ['bio:Line one\nLine two']);
      await tester.tap(find.byKey(EditProfileScreen.bioKey));
      await tester.pumpAndSettle();
      await tester.enterText(field, '   ');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(edit.repo.calls.last, 'bio:null');
      expect(
        _inRow(EditProfileScreen.bioKey, _en.profileEditBioPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('the username opens the D146 change screen', (tester) async {
      await _pumpEdit(tester);
      await tester.tap(find.byKey(EditProfileScreen.usernameKey));
      await tester.pumpAndSettle();
      expect(find.text('page username'), findsOneWidget);
    });

    testWidgets('the photo: from the photos, cropped square, uploaded as an '
        'AVATAR, set, shown at once', (tester) async {
      final png = await _png(tester, 300, 200);
      final edit = await _pumpEdit(tester, pick: png);
      await tester.tap(find.byKey(EditProfileScreen.photoKey));
      await tester.pumpAndSettle();
      // No photo yet: nothing to remove.
      expect(find.byKey(EditProfileScreen.photoRemoveKey), findsNothing);
      await tester.tap(find.byKey(EditProfileScreen.photoLibraryKey));
      await _settleImages(tester);
      expect(edit.picker.calls, [AvatarSource.library]);
      expect(find.byType(AvatarCropScreen), findsOneWidget);
      expect(find.text(_en.profileEditCropHint), findsOneWidget);
      // Move the photo; the square stays covered.
      await tester.drag(
        find.byKey(AvatarCropScreen.viewportKey),
        const Offset(-400, 0),
      );
      await tester.pump();
      await tester.tap(find.byKey(AvatarCropScreen.doneKey));
      await _settleImages(tester);
      expect(find.byType(AvatarCropScreen), findsNothing);
      // A 200 px square PNG (the photo's short side; never enlarged).
      expect(edit.media.avatarUploads, hasLength(1));
      expect(edit.media.avatarUploads.single, startsWith('image/png:'));
      expect(edit.repo.calls, ['avatar:av1']);
      expect(find.text(_en.profileEditPhotoUpdated), findsOneWidget);
      final avatar = tester.widget<KAvatar>(
        find.descendant(
          of: find.byKey(EditProfileScreen.avatarKey),
          matching: find.byType(KAvatar),
        ),
      );
      expect(avatar.imageUrl, 'https://media.example.test/media/av1/640.webp');
    });

    testWidgets('the photo: the camera; cancelling the crop changes nothing', (
      tester,
    ) async {
      final png = await _png(tester, 120, 160);
      final edit = await _pumpEdit(tester, pick: png);
      await tester.tap(find.byKey(EditProfileScreen.photoKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditProfileScreen.photoCameraKey));
      await _settleImages(tester);
      expect(edit.picker.calls, [AvatarSource.camera]);
      await tester.tap(find.byKey(AvatarCropScreen.cancelKey));
      await tester.pumpAndSettle();
      expect(edit.media.avatarUploads, isEmpty);
      expect(edit.repo.calls, isEmpty);
    });

    testWidgets('uploads off: the honest message; the photo stays', (
      tester,
    ) async {
      final png = await _png(tester, 100, 100);
      final edit = await _pumpEdit(tester, pick: png);
      edit.media.failWith = _unavailable;
      await tester.tap(find.byKey(EditProfileScreen.avatarKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditProfileScreen.photoLibraryKey));
      await _settleImages(tester);
      await tester.tap(find.byKey(AvatarCropScreen.doneKey));
      await _settleImages(tester);
      expect(find.text(_en.errorMediaUploadsUnavailable), findsOneWidget);
      expect(edit.repo.calls, isEmpty);
      expect(find.text(_en.profileEditPhotoUpdated), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(EditProfileScreen.photoKey))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a file that is not a photo is refused before the crop', (
      tester,
    ) async {
      await _pumpEdit(tester, pick: Uint8List.fromList([1, 2, 3, 4]));
      await tester.tap(find.byKey(EditProfileScreen.photoKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditProfileScreen.photoLibraryKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.createPhotoUnsupported), findsOneWidget);
      expect(find.byType(AvatarCropScreen), findsNothing);
    });

    testWidgets('remove the photo (Arabic): DELETE /me/avatar, the initial '
        'shows again', (tester) async {
      final edit = await _pumpEdit(
        tester,
        language: AppLanguage.ar,
        user: _user(avatarUrl: 'https://media.example.test/media/x/640.webp'),
      );
      await tester.tap(find.byKey(EditProfileScreen.photoKey));
      await tester.pumpAndSettle();
      expect(find.text(_ar.profileEditPhotoSheetTitle), findsOneWidget);
      await tester.tap(find.byKey(EditProfileScreen.photoRemoveKey));
      await tester.pumpAndSettle();
      expect(edit.repo.calls, ['remove']);
      expect(find.text(_ar.profileEditPhotoRemoved), findsOneWidget);
      final avatar = tester.widget<KAvatar>(
        find.descendant(
          of: find.byKey(EditProfileScreen.avatarKey),
          matching: find.byType(KAvatar),
        ),
      );
      expect(avatar.imageUrl, isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('360×800 at ×1.3 (${language.name}): no overflow, the '
          'editors fit', (tester) async {
        await _pumpEdit(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(EditProfileScreen.privacyKey),
          100,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(EditProfileScreen.bioKey),
          -100,
        );
        await tester.tap(find.byKey(EditProfileScreen.bioKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(EditProfileFieldKeys.field), findsOneWidget);
      });
    }
  });

  group('the crop maths', () {
    test('the visible square in photo pixels', () {
      // 300 × 200 in a 100 px square: scale 0.5, centred → x 50.
      final c = AvatarCrop.of(
        width: 300,
        height: 200,
        viewport: 100,
        zoom: 1,
        offset: const Offset(-25, 0),
      );
      expect([c.left, c.top, c.side], [50, 0, 200]);
      final z = AvatarCrop.of(
        width: 300,
        height: 200,
        viewport: 100,
        zoom: 2,
        offset: const Offset(-100, -50),
      );
      expect([z.left, z.top, z.side], [100, 50, 100]);
    });

    test('the photo always covers the square', () {
      expect(
        clampAvatarOffset(
          const Offset(30, -500),
          width: 300,
          height: 200,
          scale: 0.5,
          viewport: 100,
        ),
        Offset.zero,
      );
      expect(
        clampAvatarOffset(
          const Offset(-80, 0),
          width: 300,
          height: 200,
          scale: 0.5,
          viewport: 100,
        ),
        const Offset(-50, 0),
      );
    });
  });
}
