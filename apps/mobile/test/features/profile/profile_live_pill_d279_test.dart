// D279 / D279b (owner: «في بث الان هكذا ظاهرة بشكل كبير ومزعجة، ضعها في
// الجهة الاخرى المقابلة للإطار ايقونة صغيرة»): while the profile's owner is
// live, a small red «مباشر» pill (the viewers next to it) sits on the cover
// at the bottom-end corner, opposite the photo; a tap opens the room (the
// live ring's route), your own room on your own profile. D279's big card
// under the cover is gone. The facts come from `PublicProfile.live`
// (v1.70-live, CONVENTIONS §10.5.1).
//
// Checked: ar / en × light / dark at 393 × 852 with insets 59 / 34, 360 ×
// 800 at 1.3 and 2.0 (no overflow, the pill stays small), not live /
// blocked → no pill, a voice room, the tap, reduced motion, the live
// ending (gone on refresh). The clock is fixed (`withClock`), so the screen
// reader's «مباشر منذ» never depends on today.
//
// With D279_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_live_pill.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'profile_cover_d278_test.dart'
    show coverBytes, otherProfile, pumpOther, pumpOwn;

/// The fixed "now" of every test: the live started 1 h 17 min before.
final DateTime d279Now = DateTime.utc(2026, 11, 5, 20, 20);

ProfileLive d279Live({
  LiveRoomMode mode = LiveRoomMode.solo,
  int score = 41900,
  String title = '',
}) => ProfileLive(
  roomId: 'room-0',
  startedAt: d279Now.subtract(const Duration(hours: 1, minutes: 17)),
  title: title,
  mode: mode,
  viewerCount: 93,
  score: score,
);

/// Someone else's profile while live (the card's facts set).
PublicProfile d279Other({required bool ar, ProfileLive? live}) =>
    otherProfile(ar: ar, live: true).copyWith(live: live ?? d279Live());

/// The own profile (`GET /users/{me}`) while live.
PublicProfile d279Own({required bool ar}) => otherProfile(
  ar: ar,
  self: true,
  live: true,
).copyWith(hostAgentCode: null, live: d279Live());

/// Runs [body] with the clock fixed at [d279Now].
Future<void> atNow(Future<void> Function() body) =>
    withClock(Clock.fixed(d279Now), body);

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// The pill on the cover at the reading end, opposite the photo; small
/// (28 dp, a little more with large text). D292: the photo's middle is the
/// picture's bottom edge, so the pill sits on the picture, centred in the
/// photo box's upper half (less 8 dp).
void expectPill(
  WidgetTester tester, {
  required double width,
  required bool ar,
  double maxHeight = ProfileLivePill.height + 0.5,
}) {
  expect(tester.takeException(), isNull);
  final pill = _rect(tester, ProfileLivePill.pillKey);
  final cover = _rect(tester, ProfileCoverHeader.coverAreaKey);
  final avatar = _rect(tester, ProfileHeaderView.avatarKey);
  expect(pill.height, greaterThanOrEqualTo(ProfileLivePill.height - 0.5));
  expect(pill.height, lessThanOrEqualTo(maxHeight));
  expect(pill.width, lessThan(width / 2));
  // On the picture, beside the photo's upper half. D299: at the top of
  // the name block beside the photo, never on the name.
  expect(pill.top, greaterThanOrEqualTo(cover.top));
  expect(pill.bottom, lessThanOrEqualTo(cover.bottom));
  expect(pill.bottom, lessThanOrEqualTo(avatar.center.dy));
  expect(
    pill.bottom,
    lessThanOrEqualTo(_rect(tester, ProfileCoverHeader.nameRowKey).top),
  );
  // The reading end, 16 dp in; the photo at the start (RTL mirrors it).
  if (ar) {
    expect(pill.left, moreOrLessEquals(16, epsilon: 0.5));
    expect(pill.right, lessThan(avatar.left));
  } else {
    expect(pill.right, moreOrLessEquals(width - 16, epsilon: 0.5));
    expect(pill.left, greaterThan(avatar.right));
  }
  final box = tester.widget<Container>(find.byKey(ProfileLivePill.pillKey));
  final gradient =
      (box.decoration! as BoxDecoration).gradient! as LinearGradient;
  expect(gradient.colors, contains(KBrandColors.red400));
  expect(_text(tester, ProfileLivePill.viewersKey), KFormat.compactLatin(93));
}

String _semantics(WidgetTester tester) =>
    tester.getSemantics(find.byType(ProfileLivePill)).label;

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// The profile pages in a router, so the card's tap reaches the room route.
Future<FakeProfileRepository> pumpRouted(
  WidgetTester tester, {
  required PublicProfile profile,
}) async {
  final repo = FakeProfileRepository(profile);
  final router = GoRouter(
    initialLocation: '/u/host0',
    routes: [
      GoRoute(
        path: '/u/:username',
        builder: (_, s) =>
            PublicProfileScreen(username: s.pathParameters['username']!),
      ),
      GoRoute(
        path: '${AppRoutes.home}/room/:roomId',
        builder: (_, s) => Text('room ${s.pathParameters['roomId']}'),
      ),
    ],
  );
  setViewport(tester, GoldenViewport.phone);
  final prefs = await testPrefs();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        profileRepositoryProvider.overrideWithValue(repo),
        profileGridProvider.overrideWith((ref, _) => const FeedItems([])),
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
          brightness: Brightness.light,
          locale: AppLanguage.en.locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
  });

  group('KFormat.hoursMinutes (D279)', () {
    final ar = l10nFor(AppLanguage.ar);
    final en = l10nFor(AppLanguage.en);
    test('hours and minutes; minutes alone under an hour; never negative', () {
      const d = Duration(hours: 1, minutes: 17, seconds: 59);
      expect(KFormat.hoursMinutes(d, ar), '1س 17د');
      expect(KFormat.hoursMinutes(d, en), '1h 17m');
      expect(KFormat.hoursMinutes(const Duration(minutes: 5), ar), '5د');
      expect(KFormat.hoursMinutes(const Duration(hours: 3), en), '3h 0m');
      expect(KFormat.hoursMinutes(const Duration(seconds: 40), en), '0m');
      expect(KFormat.hoursMinutes(const Duration(minutes: -3), en), '0m');
      expect(ar.profileLiveFor('1س 17د'), 'مباشر منذ 1س 17د');
    });
  });

  group("D279b someone else's profile while live", () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      final l10n = l10nFor(language);
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: a small «مباشر» '
            'pill on the cover opposite the photo; no card', (tester) async {
          await atNow(() async {
            await pumpOther(
              tester,
              d279Other(ar: ar),
              language: language,
              brightness: brightness,
            );
            expectPill(tester, width: 393, ar: ar);
            expect(
              find.descendant(
                of: find.byType(ProfileLivePill),
                matching: find.text(l10n.liveBadge),
              ),
              findsOneWidget,
            );
            expect(find.text(l10n.profileLiveNowTitle), findsNothing);
            expect(
              _semantics(tester),
              l10n.profileLiveCardSemantics(
                l10n.profileLiveNowTitle,
                ar ? 'مباشر منذ 1س 17د' : 'Live for 1h 17m',
                '${l10n.liveViewers(93, KFormat.compactLatin(93))} · '
                '${l10n.liveScore(41900, KFormat.compactLatin(41900))}',
              ),
            );
          });
        });
      }
    }

    testWidgets('no score yet: the viewers only', (tester) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: false, live: d279Live(score: 0, title: 'Friday')),
          language: AppLanguage.en,
        );
        expect(_semantics(tester), endsWith('\u206693\u2069 viewers'));
      });
    });

    testWidgets('a voice room: the microphone mark', (tester) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: true, live: d279Live(mode: LiveRoomMode.audio)),
          language: AppLanguage.ar,
        );
        final icon = tester.widget<AppIcon>(
          find
              .descendant(
                of: find.byType(ProfileLivePill),
                matching: find.byType(AppIcon),
              )
              .first,
        );
        expect(icon.asset, AppIcons.mic);
      });
    });

    testWidgets('not live (or only the ring without the facts): no pill', (
      tester,
    ) async {
      await pumpOther(
        tester,
        otherProfile(ar: true, live: true),
        language: AppLanguage.ar,
      );
      expect(find.byType(ProfileLivePill), findsNothing);
      expect(find.byKey(PublicProfileScreen.watchLiveKey), findsOneWidget);
    });

    testWidgets('blocked by me: no pill', (tester) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: true).copyWith(blockedByMe: true),
          language: AppLanguage.ar,
        );
        expect(find.byType(ProfileLivePill), findsNothing);
      });
    });

    for (final scale in [1.3, 2.0]) {
      for (final language in AppLanguage.values) {
        for (final brightness in Brightness.values) {
          testWidgets(
            '360 × 800 at $scale (${language.name} ${brightness.name}): no '
            'overflow; the pill stays small',
            (tester) async {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              await atNow(() async {
                await pumpOther(
                  tester,
                  d279Other(ar: language == AppLanguage.ar),
                  language: language,
                  brightness: brightness,
                  viewport: GoldenViewport.android,
                );
                expectPill(
                  tester,
                  width: 360,
                  ar: language == AppLanguage.ar,
                  maxHeight: 34,
                );
              });
            },
          );
        }
      }
    }

    testWidgets("a tap on the pill opens the room (the live ring's route)", (
      tester,
    ) async {
      await atNow(() async {
        await pumpRouted(tester, profile: d279Other(ar: false));
        await tester.tap(find.byKey(ProfileLivePill.pillKey));
        await tester.pumpAndSettle();
        expect(find.text('room room-0'), findsOneWidget);
      });
    });

    testWidgets('reduced motion: the dot does not pulse', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await atNow(() async {
        await pumpOther(tester, d279Other(ar: false), language: AppLanguage.en);
        expect(find.byType(ProfileLivePill), findsOneWidget);
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
      });
    });

    testWidgets('the live ended: the pill is gone after a refresh', (
      tester,
    ) async {
      await atNow(() async {
        final repo = await pumpRouted(tester, profile: d279Other(ar: false));
        expect(find.byType(ProfileLivePill), findsOneWidget);
        repo.profile = repo.profile.copyWith(live: null, liveRoomId: null);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          1500,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileLivePill), findsNothing);
        expect(find.byKey(PublicProfileScreen.watchLiveKey), findsNothing);
      });
    });
  });

  group('D279b own profile while live', () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      final l10n = l10nFor(language);
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: the same pill '
            '(«أنت في بث الآن» to the screen reader)', (tester) async {
          await atNow(() async {
            await pumpOwn(
              tester,
              language: language,
              brightness: brightness,
              stats: d279Own(ar: ar),
            );
            expectPill(tester, width: 393, ar: ar);
            expect(
              _semantics(tester),
              startsWith(l10n.profileLiveNowSelfTitle),
            );
          });
        });
      }
      testWidgets('360 × 800 at 2.0 (${language.name}): no overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await atNow(() async {
          await pumpOwn(
            tester,
            language: language,
            viewport: GoldenViewport.android,
            stats: d279Own(ar: ar),
          );
          expectPill(tester, width: 360, ar: ar, maxHeight: 34);
        });
      });
    }

    testWidgets('not live: no pill', (tester) async {
      await pumpOwn(tester, language: AppLanguage.en);
      expect(find.byType(ProfileLivePill), findsNothing);
    });
  });

  final captureDir = Platform.environment['D279_CAPTURE_DIR'];
  group('D279 captures', skip: captureDir == null, () {
    Future<void> capture(WidgetTester tester, String name) async {
      await precacheImages(tester);
      await tester.runAsync(() async {
        final element = find.byType(MaterialApp).evaluate().first;
        final image = await captureImage(element);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('${captureDir!}/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      for (final brightness in Brightness.values) {
        final tag = '${language.name}.${brightness.name}';
        testWidgets('other $tag', (tester) async {
          await atNow(() async {
            await pumpOther(
              tester,
              d279Other(ar: ar),
              language: language,
              brightness: brightness,
            );
            await capture(tester, 'other.$tag');
          });
        });
        testWidgets('own $tag', (tester) async {
          await atNow(() async {
            await pumpOwn(
              tester,
              language: language,
              brightness: brightness,
              stats: d279Own(ar: ar),
            );
            await capture(tester, 'own.$tag');
          });
        });
      }
      for (final scale in [1.3, 2.0]) {
        testWidgets('other 360 $scale ${language.name}', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await atNow(() async {
            await pumpOther(
              tester,
              d279Other(ar: ar),
              language: language,
              viewport: GoldenViewport.android,
            );
            await capture(tester, 'other.360x$scale.${language.name}');
          });
        });
      }
    }
  });
}
