import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/auth/presentation/splash_video.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_splash_video.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Restore controlled by the test: completes, fails or never returns.
class _Repo extends FakeAuthRepository {
  final restore = Completer<User?>();

  @override
  Future<User?> restoreSession() => restore.future;
}

/// Pumps the app on the splash with [video] as the launch video; returns
/// every video the splash asked for.
Future<List<FakeSplashVideo>> _pump(
  WidgetTester tester,
  _Repo repo, {
  FakeSplashVideo Function()? video,
  String language = 'en',
  Map<String, Object> prefs = const {},
  bool silent = false,
}) async {
  final made = <FakeSplashVideo>[];
  await pumpKabsoApp(
    tester,
    language: language,
    prefs: prefs,
    silentMode: FakeSilentMode(silent: silent),
    splashVideo: (asset) {
      final v = (video ?? FakeSplashVideo.new)()..asset = asset;
      made.add(v);
      return v;
    },
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  await tester.pump();
  return made;
}

Finder get _skip => find.byKey(SplashScreen.skipKey);

void main() {
  group('assets and native launch colour (D156)', () {
    test('the video is a fast-start MP4 within 2.5 MB', () {
      final file = File(KSplash.videoAsset);
      final bytes = file.readAsBytesSync();
      expect(bytes.length, lessThanOrEqualTo(2500000));
      // ISO BMFF: 'ftyp' first; 'moov' before 'mdat' (plays while loading).
      expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
      final head = String.fromCharCodes(bytes.sublist(0, 64 * 1024));
      final moov = head.indexOf('moov');
      expect(moov, greaterThan(0));
      final mdat = head.indexOf('mdat');
      expect(mdat == -1 || moov < mdat, isTrue);
      expect(File(KSplash.endFrameAsset).existsSync(), isTrue);
    });

    test('Android and iOS launch screens use the video background', () {
      final argb = KSplash.videoBackground.toARGB32();
      String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;
      final colors = File('android/app/src/main/res/values/colors.xml')
          .readAsStringSync();
      expect(
        colors,
        contains(
          '<color name="launch_background">#FF${hex(r)}${hex(g)}${hex(b)}'
          '</color>',
        ),
      );
      for (final dir in ['values-v31', 'values-night-v31']) {
        final styles = File('android/app/src/main/res/$dir/styles.xml')
            .readAsStringSync();
        expect(styles, contains('@color/launch_background'), reason: dir);
        expect(styles, contains('@drawable/splash_icon_blank'), reason: dir);
      }
      expect(
        File('android/app/src/main/res/drawable/splash_icon_blank.xml')
            .existsSync(),
        isTrue,
      );
      final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
          .readAsStringSync();
      final match = RegExp(
        r'key="backgroundColor" red="([\d.]+)" green="([\d.]+)" '
        r'blue="([\d.]+)"',
      ).firstMatch(storyboard)!;
      expect(
        [for (var i = 1; i <= 3; i++) (double.parse(match[i]!) * 255).round()],
        [r, g, b],
      );
    });
  });

  group('authRedirect while the intro plays', () {
    test('the splash stays, whatever the auth state', () {
      for (final state in [
        const AuthRestoring(),
        const AuthRestoreFailed(NetworkFailure.offline()),
        const Unauthenticated(),
        Authenticated(testUser()),
      ]) {
        expect(
          authRedirect(state, AppRoutes.splash, introDone: false),
          isNull,
          reason: '$state',
        );
      }
    });

    test('other routes keep their rules', () {
      expect(
        authRedirect(const Unauthenticated(), AppRoutes.home, introDone: false),
        AppRoutes.welcome,
      );
      expect(
        authRedirect(
          Authenticated(testUser()),
          AppRoutes.home,
          introDone: false,
        ),
        isNull,
      );
    });
  });

  testWidgets('signed out: the whole video plays with its sound, then '
      'welcome', (tester) async {
    final repo = _Repo()..restore.complete(null);
    final videos = await _pump(tester, repo);
    expect(videos, hasLength(1));
    final video = videos.single;
    expect(video.asset, KSplash.videoAsset);
    expect(video.volumes, [1]);
    expect(video.plays, 1);
    expect(find.byKey(SplashScreen.videoKey), findsOneWidget);

    // The session is known long before the video ends: it keeps playing.
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);

    video.end();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(video.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in: home when the video ends', (tester) async {
    final repo = _Repo()..restore.complete(testUser());
    final video = (await _pump(tester, repo)).single;
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(SplashScreen), findsOneWidget);

    video.end();
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
  });

  group('Skip', () {
    testWidgets('appears after 0.5 s at the top end and leaves at once', (
      tester,
    ) async {
      final repo = _Repo()..restore.complete(null);
      final video = (await _pump(tester, repo)).single;
      expect(_skip, findsNothing);

      await tester.pump(const Duration(milliseconds: 450));
      expect(_skip, findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_skip, findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      final box = tester.getRect(_skip);
      final screen = tester.getSize(find.byType(SplashScreen));
      expect(box.center.dx, greaterThan(screen.width / 2), reason: 'end (LTR)');
      expect(box.top, lessThan(screen.height / 5));

      await tester.tap(_skip);
      await tester.pumpAndSettle();
      expect(video.pauses, 1, reason: 'the sound stops');
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('Arabic: «تخطي» at the top end (left)', (tester) async {
      final repo = _Repo()..restore.complete(null);
      await _pump(tester, repo, language: 'ar');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('تخطي'), findsOneWidget);
      final box = tester.getRect(_skip);
      final screen = tester.getSize(find.byType(SplashScreen));
      expect(box.center.dx, lessThan(screen.width / 2));
    });

    testWidgets('while the session restores: last frame held, spinner, no '
        'Skip', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(_skip);
      await tester.pump();
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byKey(SplashScreen.videoKey), findsOneWidget);
      expect(find.byKey(SplashScreen.loadingKey), findsOneWidget);
      expect(_skip, findsNothing);

      repo.restore.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  testWidgets('a slow restore: the last frame stays with the loading '
      'indicator, then moves on', (tester) async {
    final repo = _Repo();
    final video = (await _pump(tester, repo)).single;
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(SplashScreen.loadingKey), findsNothing);

    video.end();
    await tester.pump();
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byKey(SplashScreen.videoKey), findsOneWidget);
    expect(find.byKey(FakeSplashVideo.viewKey), findsOneWidget);
    expect(find.byKey(SplashScreen.loadingKey), findsOneWidget);

    repo.restore.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('a failed restore shows the error state only after the video', (
    tester,
  ) async {
    final repo = _Repo();
    final video = (await _pump(tester, repo)).single;
    repo.restore.completeError(const NetworkFailure.offline());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FailureErrorState), findsNothing);
    expect(find.byKey(SplashScreen.videoKey), findsOneWidget);

    video.end();
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(FailureErrorState), findsOneWidget);
  });

  group('the video cannot play: a still and on at once', () {
    testWidgets('it does not load', (tester) async {
      final repo = _Repo()..restore.complete(null);
      final video = (await _pump(
        tester,
        repo,
        video: () => FakeSplashVideo(failOnInit: true),
      )).single;
      expect(video.plays, 0);
      expect(find.byKey(SplashScreen.stillKey), findsOneWidget);
      expect(_skip, findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('it fails while playing; a slow restore keeps the still', (
      tester,
    ) async {
      final repo = _Repo();
      final video = (await _pump(tester, repo)).single;
      await tester.pump(const Duration(seconds: 2));
      video.fail();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(SplashScreen.stillKey), findsOneWidget);
      expect(find.byKey(SplashScreen.videoKey), findsNothing);
      expect(find.byKey(SplashScreen.loadingKey), findsOneWidget);

      repo.restore.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('it never reports its end: on after its length + grace', (
      tester,
    ) async {
      final repo = _Repo()..restore.complete(null);
      await _pump(tester, repo);
      await tester.pump(
        KSplash.videoLength +
            KSplash.stallGrace -
            const Duration(milliseconds: 100),
      );
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('sound', () {
    testWidgets('muted when Sound effects is off', (tester) async {
      final repo = _Repo()..restore.complete(null);
      final video = (await _pump(
        tester,
        repo,
        prefs: const {PreferenceKeys.soundEffects: false},
      )).single;
      expect(video.volumes, [0]);
      expect(video.plays, 1);
    });

    testWidgets('muted when the phone is silent or on vibrate', (tester) async {
      final repo = _Repo()..restore.complete(null);
      final video = (await _pump(tester, repo, silent: true)).single;
      expect(video.volumes, [0]);
      expect(video.plays, 1);
    });

    test('splashSoundOn: the setting and the ring mode', () async {
      expect(
        await splashSoundOn(
          soundEffects: true,
          silentMode: const FakeSilentMode(),
        ),
        isTrue,
      );
      expect(
        await splashSoundOn(
          soundEffects: false,
          silentMode: const FakeSilentMode(),
        ),
        isFalse,
      );
      expect(
        await splashSoundOn(
          soundEffects: true,
          silentMode: const FakeSilentMode(silent: true),
        ),
        isFalse,
      );
    });
  });

  testWidgets('reduced motion: the last frame for 1.5 s, no video', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final repo = _Repo()..restore.complete(null);
    final videos = await _pump(tester, repo);
    expect(videos, isEmpty);
    expect(find.byKey(SplashScreen.stillKey), findsOneWidget);
    expect(_skip, findsNothing);

    await tester.pump(KSplash.stillHold - const Duration(milliseconds: 100));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  // Measured on the video's last frame (720×1280): the "kabso" wordmark's
  // ink spans x 181–546, the «• LIVE» pill about 255–465 and Kabi about
  // 180–595. Cover crops the sides; these must stay inside.
  const contentLeft = 160.0;
  const contentRight = 610.0;
  for (final size in const [Size(360, 800), Size(393, 852), Size(430, 932)]) {
    testWidgets('cover at ${size.width.toInt()}×${size.height.toInt()}: '
        'fills the screen, centred, Kabi and the wordmark inside', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _Repo();
      await _pump(tester, repo);

      final view = tester.getRect(find.byKey(FakeSplashVideo.viewKey));
      expect(view.height, moreOrLessEquals(size.height));
      expect(view.width, moreOrLessEquals(size.height * 720 / 1280));
      expect(view.center.dx, moreOrLessEquals(size.width / 2));
      final scale = view.height / 1280;
      expect(view.left + contentLeft * scale, greaterThanOrEqualTo(0));
      expect(view.left + contentRight * scale, lessThanOrEqualTo(size.width));
    });
  }

  testWidgets('screen readers hear the brand name once', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = _Repo();
    await _pump(tester, repo);
    expect(find.bySemanticsLabel('Kabso Live'), findsOneWidget);
    handle.dispose();
  });
}
