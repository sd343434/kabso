// D279 (owner): a «في بث الآن» card under the profile's tall cover (D278)
// while the profile's owner is live — «مباشر منذ 1س 17د», the viewers, the
// score and «انضم» in Kabso red; a tap on the card or the button opens the
// room (the live ring's route). The own profile: «أنت في بث الآن» (opens
// your room). The facts come from `PublicProfile.live` (v1.70-live,
// CONVENTIONS §10.5.1).
//
// Checked: ar / en × light / dark at 393 × 852 with insets 59 / 34, 360 ×
// 800 at 1.3 and 2.0 (no overflow), not live / blocked → no card, a voice
// room, the taps, the live ending (gone on refresh). The clock is fixed
// (`withClock`), so «مباشر منذ» never depends on today.
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
import 'package:kabso_live/features/profile/profile_live_card.dart';
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

/// The card directly under the cover, inside the screen, before the info
/// block; «انضم» in Kabso red at the reading end.
void expectCard(
  WidgetTester tester, {
  required double width,
  required bool ar,
  bool exact = true,
}) {
  expect(tester.takeException(), isNull);
  final title = _rect(tester, ProfileLiveCard.titleKey);
  final card = _rect(tester, ProfileLiveCard.cardKey);
  final join = _rect(tester, ProfileLiveCard.joinKey);
  // Directly under the cover (large text scrolls the cover away first).
  if (exact) {
    final header = _rect(tester, ProfileCoverHeader.headerKey);
    expect(title.top, greaterThanOrEqualTo(header.bottom));
    expect(title.top - header.bottom, lessThanOrEqualTo(KSpacing.md));
  }
  expect(card.top, greaterThan(title.bottom));
  for (final r in [title, card, join]) {
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(width));
  }
  // The page's 16 dp margins (the card's 1 dp border inside them).
  expect(card.left, moreOrLessEquals(16, epsilon: 1));
  expect(card.right, moreOrLessEquals(width - 16, epsilon: 1));
  expect(join.top, greaterThanOrEqualTo(card.top));
  expect(join.bottom, lessThanOrEqualTo(card.bottom));
  // «انضم» at the reading end (RTL mirrors it).
  if (ar) {
    expect(join.left - card.left, lessThan(card.right - join.right));
  } else {
    expect(card.right - join.right, lessThan(join.left - card.left));
  }
  final button = tester.widget<FilledButton>(
    find.byKey(ProfileLiveCard.joinKey),
  );
  expect(button.style!.backgroundColor!.resolve({}), KBrandColors.red500);
  // What followed the cover now follows the card.
  expect(
    tester.getRect(find.byType(ProfileInfoBlock)).top,
    greaterThanOrEqualTo(card.bottom),
  );
}

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

  group("D279 someone else's profile while live", () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      final l10n = l10nFor(language);
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: «في بث الآن» under '
            'the cover — live for 1h 17m, 93 viewers, 41.9K points, Join '
            'in red', (tester) async {
          await atNow(() async {
            await pumpOther(
              tester,
              d279Other(ar: ar),
              language: language,
              brightness: brightness,
            );
            expectCard(tester, width: 393, ar: ar);
            expect(
              _text(tester, ProfileLiveCard.titleKey),
              l10n.profileLiveNowTitle,
            );
            expect(
              _text(tester, ProfileLiveCard.durationKey),
              ar ? 'مباشر منذ 1س 17د' : 'Live for 1h 17m',
            );
            expect(
              _text(tester, ProfileLiveCard.detailsKey),
              '${l10n.liveViewers(93, KFormat.compactLatin(93))} · '
              '${l10n.liveScore(41900, KFormat.compactLatin(41900))}',
            );
            expect(
              _text(tester, ProfileLiveCard.detailsKey),
              contains('41.9K'),
            );
            expect(find.text(l10n.profileLiveJoin), findsOneWidget);
          });
        });
      }
    }

    testWidgets('no score yet: the viewers only; a title shows under them', (
      tester,
    ) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: false, live: d279Live(score: 0, title: 'Friday night')),
          language: AppLanguage.en,
        );
        expect(
          _text(tester, ProfileLiveCard.detailsKey),
          '\u206693\u2069 viewers',
        );
        expect(find.textContaining('Friday night'), findsOneWidget);
      });
    });

    testWidgets('a voice room says so', (tester) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: true, live: d279Live(mode: LiveRoomMode.audio)),
          language: AppLanguage.ar,
        );
        expect(find.text('غرفة صوتية'), findsOneWidget);
      });
    });

    testWidgets('not live (or only the ring without the facts): no card', (
      tester,
    ) async {
      await pumpOther(
        tester,
        otherProfile(ar: true, live: true),
        language: AppLanguage.ar,
      );
      expect(find.byType(ProfileLiveCard), findsNothing);
      expect(find.byKey(PublicProfileScreen.watchLiveKey), findsOneWidget);
    });

    testWidgets('blocked by me: no card', (tester) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: true).copyWith(blockedByMe: true),
          language: AppLanguage.ar,
        );
        expect(find.byType(ProfileLiveCard), findsNothing);
      });
    });

    for (final scale in [1.3, 2.0]) {
      for (final language in AppLanguage.values) {
        for (final brightness in Brightness.values) {
          testWidgets(
            '360 × 800 at $scale (${language.name} ${brightness.name}): no '
            'overflow',
            (tester) async {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              await atNow(() async {
                await pumpOther(
                  tester,
                  d279Other(
                    ar: language == AppLanguage.ar,
                    live: d279Live(title: 'سهرة الجمعة مع الأصدقاء'),
                  ),
                  language: language,
                  brightness: brightness,
                  viewport: GoldenViewport.android,
                );
                await tester.ensureVisible(find.byKey(ProfileLiveCard.joinKey));
                await tester.pumpAndSettle();
                expectCard(
                  tester,
                  width: 360,
                  ar: language == AppLanguage.ar,
                  exact: false,
                );
              });
            },
          );
        }
      }
    }

    testWidgets('a tap on the card or on Join opens the room (the live '
        "ring's route)", (tester) async {
      await atNow(() async {
        await pumpRouted(tester, profile: d279Other(ar: false));
        await tester.tap(find.byKey(ProfileLiveCard.joinKey));
        await tester.pumpAndSettle();
        expect(find.text('room room-0'), findsOneWidget);
      });
    });

    testWidgets('a tap on the card body opens the room too', (tester) async {
      await atNow(() async {
        await pumpRouted(tester, profile: d279Other(ar: false));
        await tester.tap(find.byKey(ProfileLiveCard.durationKey));
        await tester.pumpAndSettle();
        expect(find.text('room room-0'), findsOneWidget);
      });
    });

    testWidgets('the live ended: the card is gone after a refresh', (
      tester,
    ) async {
      await atNow(() async {
        final repo = await pumpRouted(tester, profile: d279Other(ar: false));
        expect(find.byType(ProfileLiveCard), findsOneWidget);
        repo.profile = repo.profile.copyWith(live: null, liveRoomId: null);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 500),
          1500,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileLiveCard), findsNothing);
        expect(find.byKey(PublicProfileScreen.watchLiveKey), findsNothing);
      });
    });
  });

  group('D279 own profile while live', () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      final l10n = l10nFor(language);
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: «أنت في بث الآن» '
            'with «عودة للبث»', (tester) async {
          await atNow(() async {
            await pumpOwn(
              tester,
              language: language,
              brightness: brightness,
              stats: d279Own(ar: ar),
            );
            expectCard(tester, width: 393, ar: ar);
            expect(
              _text(tester, ProfileLiveCard.titleKey),
              l10n.profileLiveNowSelfTitle,
            );
            expect(find.text(l10n.profileLiveReturn), findsOneWidget);
            expect(
              _text(tester, ProfileLiveCard.durationKey),
              l10n.profileLiveFor(ar ? '1س 17د' : '1h 17m'),
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
          await tester.ensureVisible(find.byKey(ProfileLiveCard.joinKey));
          await tester.pumpAndSettle();
          expectCard(tester, width: 360, ar: ar, exact: false);
        });
      });
    }

    testWidgets('not live: no card', (tester) async {
      await pumpOwn(tester, language: AppLanguage.en);
      expect(find.byType(ProfileLiveCard), findsNothing);
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
              d279Other(
                ar: ar,
                live: d279Live(title: 'سهرة الجمعة مع الأصدقاء'),
              ),
              language: language,
              viewport: GoldenViewport.android,
            );
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -300),
            );
            await tester.pumpAndSettle();
            await capture(tester, 'other.360x$scale.${language.name}');
          });
        });
      }
    }
  });
}
