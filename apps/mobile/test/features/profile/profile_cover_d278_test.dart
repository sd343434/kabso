// D278 (owner, a reference of another app's profile: «اظهر ملف شخصي بغلاف
// بهذا الحجم ويغطي للاعلى وايقونات دردشة والشات»; then «استخدم ازراري»):
// the cover is ≈ 57 % of the screen, full-bleed from the very top (under
// the status bar and our own top buttons, which sit on translucent circles
// with no bar background); over its lower part on a dark gradient: the
// photo (frames unchanged), the name with its badges, the @username, the
// level badges, the Following / Followers counts and the action row —
// «متابعة» in Kabso red, the chat button (the conversation) and the more
// button; on the own profile «تعديل الملف». The rest follows under it.
//
// Checked: someone else's profile with a cover and without, the own
// profile, ar / en, light / dark, 393 × 852 with insets 59 / 34, 360 × 800
// at 1.3 and 2.0; the bar turns solid (the @username) once the cover has
// scrolled away and the tabs pin under it.
//
// With D278_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final Uint8List coverBytes = File('test/fixtures/profile/cover_sample.jpg')
    .readAsBytesSync();

const coverUrl = 'https://cdn.k.test/covers/host0.jpg';

/// Someone else's profile: with a cover, not live, a VIP badge after the
/// name.
PublicProfile otherProfile({
  required bool ar,
  bool cover = true,
  bool live = false,
  bool self = false,
}) => apiProfile(ar: ar, isSelf: self).copyWith(
  displayName: ar ? 'نبّ' : 'Nabb',
  coverUrl: cover ? coverUrl : null,
  liveRoomId: live ? 'room-0' : null,
  vip: const UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D),
  followerCount: 47200,
  followingCount: 1782,
  hostAgentCode: 'H-1001',
);

User me({required bool ar, bool cover = true}) => User(
  id: 'user-0',
  email: 'me@example.invalid',
  emailVerified: true,
  username: 'host0',
  displayName: ar ? 'نبّ' : 'Nabb',
  locale: ar ? 'ar' : 'en',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
  bio: ar ? 'موسيقى عربية كل مساء' : 'Arabic music every evening',
  coverUrl: cover ? coverUrl : null,
);

final List<Override> _common = [
  secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  profileGridProvider.overrideWith(
    (ref, _) =>
        FeedItems([for (var i = 0; i < 30; i++) const ProfileGridItem()]),
  ),
];

/// Opens [screen] over a first page, so the back button shows.
class _Pushed extends StatefulWidget {
  const new(this.screen);

  final Widget screen;

  @override
  State<_Pushed> createState() => _PushedState();
}

class _PushedState extends State<_Pushed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => widget.screen,
          transitionDuration: Duration.zero,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

void insets(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> pumpOther(
  WidgetTester tester,
  PublicProfile profile, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  GoldenViewport viewport = GoldenViewport.phone,
  bool pushed = true,
}) async {
  setViewport(tester, viewport);
  insets(tester);
  const screen = PublicProfileScreen(username: 'host0');
  await pumpScreen(
    tester,
    pushed ? const _Pushed(screen) : screen,
    language: language,
    brightness: brightness,
    disableAnimations: true,
    overrides: [
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile),
      ),
      ..._common,
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> pumpOwn(
  WidgetTester tester, {
  required AppLanguage language,
  Brightness brightness = Brightness.light,
  GoldenViewport viewport = GoldenViewport.phone,
  bool cover = true,
}) async {
  setViewport(tester, viewport);
  insets(tester);
  final ar = language == AppLanguage.ar;
  await pumpScreen(
    tester,
    const _Pushed(ProfileScreen()),
    language: language,
    brightness: brightness,
    disableAnimations: true,
    overrides: [
      meProvider.overrideWith((ref) => me(ar: ar, cover: cover)),
      profileStatsProvider.overrideWith(
        (ref, username) =>
            otherProfile(ar: ar, self: true).copyWith(hostAgentCode: null),
      ),
      ..._common,
    ],
  );
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// The cover from the very top, full width, ≈ 57 % of the screen (or
/// taller with large text); the name, the handle, the counts and the
/// buttons over its lower part.
void expectCover(
  WidgetTester tester, {
  required Size screen,
  required bool own,
  bool exact = true,
}) {
  expect(tester.takeException(), isNull);
  final header = _rect(tester, ProfileCoverHeader.headerKey);
  expect(header.top, 0);
  expect(header.left, 0);
  expect(header.width, screen.width);
  if (exact) {
    expect(header.height, moreOrLessEquals(screen.height * 0.57, epsilon: 1));
  } else {
    expect(header.height, greaterThanOrEqualTo(screen.height * 0.57 - 1));
  }
  final fallback = _rect(tester, ProfileCoverHeader.coverFallbackKey);
  expect(fallback, header);
  final bar = tester.getRect(find.byType(AppBar));
  final name = _rect(tester, const Key('profile.displayName'));
  final handle = _rect(tester, ProfileCoverHeader.handleKey);
  final stats = _rect(tester, ProfileScreen.statsKey);
  // Over the cover, under the bar, in the lower part.
  for (final r in [name, handle, stats]) {
    expect(r.top, greaterThan(bar.bottom));
    expect(r.bottom, lessThanOrEqualTo(header.bottom));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(screen.width));
  }
  if (exact) expect(name.top, greaterThan(header.top + header.height * 0.4));
  expect(handle.top, greaterThanOrEqualTo(name.bottom - 1));
  final photo = _rect(tester, ProfileHeaderView.avatarKey);
  expect(photo.top, greaterThan(bar.bottom));
  expect(photo.bottom, lessThanOrEqualTo(header.bottom));
  final buttons = own
      ? [ProfileScreen.editButtonKey]
      : [
          PublicProfileScreen.followKey,
          PublicProfileScreen.messageKey,
          PublicProfileScreen.dropdownKey,
        ];
  for (final key in buttons) {
    final r = _rect(tester, key);
    expect(r.top, greaterThanOrEqualTo(stats.top - 1));
    expect(r.bottom, lessThanOrEqualTo(header.bottom));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(screen.width));
  }
  // What follows starts under the cover.
  final under = find.byType(ProfileInfoBlock);
  expect(tester.getRect(under).top, header.bottom);
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
  });

  test('the cover is 57 % of the screen (≈ 486 dp on 393 × 852)', () {
    expect(KPublicProfile.coverHeightFor(852), 486);
  });

  group("D278 someone else's profile", () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: the tall cover '
            'from the top, the name, handle, counts and Follow / chat / '
            'more over it; our top buttons on circles', (tester) async {
          await pumpOther(
            tester,
            otherProfile(ar: ar),
            language: language,
            brightness: brightness,
          );
          expectCover(tester, screen: const Size(393, 852), own: false);
          expect(find.byKey(ProfileCoverHeader.coverKey), findsOneWidget);
          // The bar: no background, our buttons (back, the dots), no title.
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          expect(bar.backgroundColor, Colors.transparent);
          expect(find.byType(BackButton), findsOneWidget);
          expect(find.byKey(PublicProfileScreen.moreKey), findsOneWidget);
          final title = tester.widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byKey(ProfileCoverBar.titleKey),
              matching: find.byType(AnimatedOpacity),
            ),
          );
          expect(title.opacity, 0);
          // The bar's buttons sit under the status bar (59).
          expect(
            _rect(tester, PublicProfileScreen.moreKey).top,
            greaterThanOrEqualTo(59),
          );
          // «متابعة» in Kabso red, the widest of the row.
          final follow = tester.widget<FilledButton>(
            find.byKey(PublicProfileScreen.followKey),
          );
          expect(
            follow.style!.backgroundColor!.resolve({}),
            KBrandColors.red500,
          );
          final f = _rect(tester, PublicProfileScreen.followKey);
          final m = _rect(tester, PublicProfileScreen.messageKey);
          final d = _rect(tester, PublicProfileScreen.dropdownKey);
          expect(m.width, moreOrLessEquals(m.height));
          expect(d.width, moreOrLessEquals(d.height));
          expect(f.width, greaterThan(m.width * 2));
          // Reading order: Follow, chat, more (RTL mirrors it).
          if (ar) {
            expect(f.left, greaterThan(m.right));
            expect(m.left, greaterThan(d.right));
          } else {
            expect(f.right, lessThan(m.left));
            expect(m.right, lessThan(d.left));
          }
          // D268: the VIP badge right after the name.
          final name = _rect(tester, const Key('profile.displayName'));
          final badge = tester.getRect(find.byType(VipNameBadge));
          if (ar) {
            expect(badge.right, lessThanOrEqualTo(name.left));
          } else {
            expect(badge.left, greaterThanOrEqualTo(name.right));
          }
        });
      }
    }

    testWidgets('no cover: the Kabso gradient (the photo blurred over it '
        'when there is one)', (tester) async {
      await pumpOther(
        tester,
        otherProfile(
          ar: true,
          cover: false,
        ).copyWith(avatarUrl: 'https://cdn.k.test/a.jpg'),
        language: AppLanguage.ar,
      );
      expectCover(tester, screen: const Size(393, 852), own: false);
      expect(find.byKey(ProfileCoverHeader.coverKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coverAvatarKey), findsOneWidget);
    });

    testWidgets('the more button opens the sheet (copy username, mute, '
        'block, report)', (tester) async {
      await pumpOther(
        tester,
        otherProfile(ar: false),
        language: AppLanguage.en,
      );
      await tester.tap(find.byKey(PublicProfileScreen.dropdownKey));
      await tester.pumpAndSettle();
      expect(find.byKey(PublicProfileScreen.copyUsernameKey), findsOneWidget);
      expect(find.byKey(PublicProfileScreen.blockKey), findsOneWidget);
      expect(find.byKey(PublicProfileScreen.reportKey), findsOneWidget);
    });

    testWidgets('scrolled past the cover: the solid bar with the @username; '
        'the tabs pin under it', (tester) async {
      await pumpOther(
        tester,
        otherProfile(ar: false),
        language: AppLanguage.en,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, KPalette.light.background);
      final title = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(ProfileCoverBar.titleKey),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(title.opacity, 1);
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverBar.titleKey),
          matching: find.text('@host0'),
        ),
        findsOneWidget,
      );
      final barRect = tester.getRect(find.byType(AppBar));
      final tabs = tester.getRect(
        find.byKey(ProfileScreen.tabKey(ProfileTab.posts)),
      );
      expect(tabs.top, greaterThanOrEqualTo(barRect.bottom - 0.5));
      expect(tabs.top, lessThan(barRect.bottom + 60));
      // Back up: transparent again.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        Colors.transparent,
      );
    });

    for (final language in AppLanguage.values) {
      for (final scale in [1.3, 2.0]) {
        for (final live in [false, true]) {
          testWidgets(
            '360 × 800 at $scale (${language.name}, dark, live: $live): '
            'no overflow, the cover grows with its contents',
            (tester) async {
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              await pumpOther(
                tester,
                otherProfile(
                  ar: language == AppLanguage.ar,
                  live: live,
                ).copyWith(displayName: 'Nabulsi Abdulrahman Al-Khatib'),
                language: language,
                brightness: Brightness.dark,
                viewport: GoldenViewport.android,
              );
              expectCover(
                tester,
                screen: const Size(360, 800),
                own: false,
                exact: false,
              );
            },
          );
        }
      }
    }
  });

  group('D278 own profile', () {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: the same cover; '
            '«تعديل الملف» instead of follow and chat; our buttons '
            '(back, drafts, settings)', (tester) async {
          await pumpOwn(tester, language: language, brightness: brightness);
          expectCover(tester, screen: const Size(393, 852), own: true);
          expect(find.byKey(PublicProfileScreen.followKey), findsNothing);
          expect(find.byKey(PublicProfileScreen.messageKey), findsNothing);
          expect(find.byKey(ProfileScreen.draftsButtonKey), findsOneWidget);
          expect(find.byKey(ProfileScreen.settingsButtonKey), findsOneWidget);
          expect(find.byType(BackButton), findsOneWidget);
          final l10n = l10nFor(language);
          expect(
            find.descendant(
              of: find.byKey(ProfileScreen.editButtonKey),
              matching: find.text(l10n.profileEditShort),
            ),
            findsOneWidget,
          );
          // The cover is still the button that changes it.
          expect(find.byKey(ProfileCoverHeader.coverButtonKey), findsOneWidget);
        });
      }
      testWidgets('360 × 800 at 2.0 (${language.name}): no overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOwn(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          cover: false,
        );
        expectCover(
          tester,
          screen: const Size(360, 800),
          own: true,
          exact: false,
        );
      });
    }
  });

  final captureDir = Platform.environment['D278_CAPTURE_DIR'];
  group('D278 captures', skip: captureDir == null, () {
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
          await pumpOther(
            tester,
            otherProfile(ar: ar),
            language: language,
            brightness: brightness,
          );
          await capture(tester, 'other.$tag');
        });
        testWidgets('own $tag', (tester) async {
          await pumpOwn(tester, language: language, brightness: brightness);
          await capture(tester, 'own.$tag');
        });
      }
      testWidgets('other no cover ${language.name}', (tester) async {
        await pumpOther(
          tester,
          otherProfile(ar: ar, cover: false, live: true),
          language: language,
        );
        await capture(tester, 'other.nocover.${language.name}');
      });
      testWidgets('other 360 2.0 ${language.name}', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOther(
          tester,
          otherProfile(ar: ar),
          language: language,
          viewport: GoldenViewport.android,
        );
        await capture(tester, 'other.360x2.${language.name}');
      });
      testWidgets('other scrolled ${language.name}', (tester) async {
        await pumpOther(tester, otherProfile(ar: ar), language: language);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pumpAndSettle();
        await capture(tester, 'other.scrolled.${language.name}');
      });
    }
  });
}
