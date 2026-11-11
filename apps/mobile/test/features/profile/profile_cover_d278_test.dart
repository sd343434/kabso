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
// D278b (owner, comparing with the reference: «صورة شخصية نريد رفعها
// للاعلى قليلاً، الاسم يظهر بجانبه الليفيلات، باسفله اليوزر، بالاسفل
// المتابعون والمتابعهم والكرز المستلم والكوينز المرسل، ثم منشنات … لغاية ١٠
// بسطرين فقط، والاسفل روابط … واجعل الغلاف اقل ارتفاع مثلاً ٤٢٪»): the
// picture is 42 % of the screen and fades into a dark block; the photo
// rises into the picture; the name, the VIP badge and the level badges on
// one line; the @username; the four numbers; the buttons; the tags (two
// lines at most, «+n»); the links.
//
// D278c (owner: «نصفه السفلي لا تجعله تدرج لوني بدون لون، اجعله كالخلفية
// ان كانت دارك سوداء وان كانت لايت بيضاء»): that block is the page colour
// in the theme's colours; the picture ends with a short fade.
//
// D299 (owner: «ضع الصورة الشخصية فوق الغلاف، وبجانبها الاسم والشارات،
// وتحته الميداليات»; then the @username and the medals swapped, and the bio
// above the links): the photo wholly on the picture, the name, the badges
// and the medals beside it; under it the @username, the numbers, the
// buttons, the tags, the bio and the links.
//
// D335 (owner, «أريده مطابق»): the cover is back for every profile (the
// default Kabso cover when none), the photo at the reading start over its
// bottom edge, the name block start-aligned under it, the ⋯ in the bar; the
// checks below follow (D316's centred, cover-less header is superseded).
//
// With D278_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_default_cover.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/levels/levels_api_fixtures.dart';
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
  cherriesReceived: 1250000,
  coinsSent: 86400,
  tags: sampleTags(ar: ar),
  tagIcons: sampleTagIcons,
  links: const [
    ProfileLink(
      id: 'l1',
      url: 'https://www.instagram.com/nabb',
      platform: ProfileLinkPlatform.instagram,
    ),
  ],
);

/// D292: the icon each sample tag's owner chose (one `default`).
const List<String> sampleTagIcons = [
  'crown',
  'flag:SA',
  'fire',
  'trophy',
  'mic',
  'gamepad',
  'default',
  'music',
  'moon',
  'book',
];

/// Ten tags: more than one line on a phone, so the «+n» chip shows.
List<String> sampleTags({required bool ar}) => ar
    ? [
        'صانع محتوى',
        'السعودية',
        'البقاء للأقوى',
        'Top 10',
        'مطرب',
        'ألعاب',
        'جيش النمر',
        'موسيقى',
        'سهرات',
        'شعر',
      ]
    : [
        'Content creator',
        'Saudi Arabia',
        'Survival of the fittest',
        'Top 10',
        'Singer',
        'Gamer',
        'Tiger army',
        'Music',
        'Late nights',
        'Poetry',
      ];

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
  tags: sampleTags(ar: ar).take(4).toList(),
  tagIcons: sampleTagIcons.take(4).toList(),
);

final List<Override> _common = [
  secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
  // D278b: the level badges beside the name.
  profileLevelsProvider.overrideWith(
    (ref, _) async => [
      PublicLevel(
        category: LevelCategory.attractiveness,
        name: 'Charm',
        level: LevelBrief.fromJson(levelBriefJson(37)),
      ),
      PublicLevel(
        category: LevelCategory.support,
        name: 'Support',
        level: LevelBrief.fromJson(levelBriefJson(12)),
      ),
    ],
  ),
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
  PublicProfile? stats,
  // D367: another signed-in person (a staff account) instead of [me].
  User? user,
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
      meProvider.overrideWith((ref) => user ?? me(ar: ar, cover: cover)),
      profileStatsProvider.overrideWith(
        (ref, username) =>
            stats ??
            otherProfile(ar: ar, self: true).copyWith(hostAgentCode: null),
      ),
      ..._common,
    ],
  );
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// D335 (was D316: no cover, centred): the cover from the top, full width
/// (the person's picture, else the default Kabso cover); the photo at the
/// reading start over its bottom edge; the name block, the numbers and the
/// buttons start-aligned under it; nothing outside the screen.
void expectCover(
  WidgetTester tester, {
  required Size screen,
  required bool own,
}) {
  expect(tester.takeException(), isNull);
  final rtl =
      Directionality.of(
        tester.element(find.byKey(ProfileCoverHeader.headerKey)),
      ) ==
      TextDirection.rtl;
  final header = _rect(tester, ProfileCoverHeader.headerKey);
  expect(header.top, 0);
  expect(header.left, 0);
  expect(header.width, screen.width);
  final area = _rect(tester, ProfileCoverHeader.coverAreaKey);
  final bar = tester.getRect(find.byType(AppBar));
  expect(area.top, 0);
  expect(area.width, screen.width);
  expect(area.height, KPublicProfile.coverHeightFor(bar.bottom));
  expect(find.byKey(ProfileCoverHeader.coverFallbackKey), findsOneWidget);
  final photo = _rect(tester, ProfileHeaderView.avatarKey);
  // The photo under the bar, its centre above the cover's edge, at the
  // reading start.
  expect(photo.top, greaterThanOrEqualTo(bar.bottom));
  expect(
    photo.center.dy,
    moreOrLessEquals(area.bottom - KPublicProfile.avatarLift, epsilon: 0.5),
  );
  expect(
    rtl ? screen.width - photo.center.dx : photo.center.dx,
    moreOrLessEquals(
      KPublicProfile.avatarStart + KPublicProfile.avatarOuter / 2,
      epsilon: 0.5,
    ),
  );
  final name = _rect(tester, const Key('profile.displayName'));
  final nameRow = _rect(tester, ProfileCoverHeader.nameRowKey);
  final handle = _rect(tester, ProfileCoverHeader.handleKey);
  final stats = _rect(tester, ProfileScreen.statsKey);
  final actions = _rect(tester, ProfileCoverHeader.actionsKey);
  expect(name.overlaps(photo), isFalse);
  expect(name.top, greaterThan(photo.bottom));
  expect(nameRow.top, greaterThanOrEqualTo(photo.bottom));
  expect(
    rtl ? screen.width - nameRow.right : nameRow.left,
    moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5),
  );
  // D299d: the @username at the top, in the bar; the numbers under the
  // name block, centred.
  expect(handle.bottom, lessThanOrEqualTo(bar.bottom));
  expect(handle.left, greaterThanOrEqualTo(0));
  expect(handle.right, lessThanOrEqualTo(screen.width));
  expect(stats.top, greaterThanOrEqualTo(nameRow.bottom));
  expect(stats.center.dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
  expect(actions.top, greaterThanOrEqualTo(stats.bottom));
  for (final r in [name, nameRow, stats, actions]) {
    expect(r.bottom, lessThanOrEqualTo(header.bottom));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(screen.width));
  }
  final buttons = own
      ? [ProfileScreen.editButtonKey]
      : [PublicProfileScreen.followKey, PublicProfileScreen.messageKey];
  for (final key in [...buttons, ProfileCoverHeader.bondsToggleKey]) {
    final r = _rect(tester, key);
    expect(r.top, greaterThanOrEqualTo(actions.top - 0.5));
    expect(r.bottom, lessThanOrEqualTo(actions.bottom + 0.5));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(screen.width));
  }
  // The tags: one line (D292; was two); D316 / D335: under the bio, above
  // the numbers.
  final tags = find.byKey(ProfileTagChips.wrapKey);
  if (tags.evaluate().isNotEmpty) {
    final t = tester.getRect(tags);
    expect(t.top, greaterThanOrEqualTo(nameRow.bottom));
    expect(t.bottom, lessThanOrEqualTo(stats.top));
    final chips = find.descendant(
      of: tags,
      matching: find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is BoxDecoration,
      ),
    );
    final tops = {
      for (final e in chips.evaluate())
        tester.getRect(find.byWidget(e.widget)).top.round(),
    };
    expect(tops.length, lessThanOrEqualTo(ProfileTagChips.maxLines));
  }
  // What follows starts under the header.
  // (With very large text the header can fill the screen: the rest is
  // not built yet.)
  final under = find.byType(ProfileInfoBlock);
  if (under.evaluate().isNotEmpty) {
    expect(tester.getRect(under).top, greaterThanOrEqualTo(header.bottom));
  }
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
  });

  test('D335: the cover runs 184 dp under the bar (309 dp under a 125 dp '
      'bar; D299: 270; D292: 213; D278b: 42 % of the screen, 358 dp)', () {
    expect(KPublicProfile.coverHeightFor(125), 125 + 184);
    expect(KPublicProfile.coverHeightFor(125), 309);
  });

  group("D278 someone else's profile", () {
    for (final language in AppLanguage.values) {
      final ar = language == AppLanguage.ar;
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: the cover '
            '(D335); the photo at the start and the name under it; the '
            'counts and Follow / Message / chevron pills; our top buttons on '
            'circles with ⋯ in the bar', (tester) async {
          await pumpOther(
            tester,
            otherProfile(ar: ar),
            language: language,
            brightness: brightness,
          );
          expectCover(tester, screen: const Size(393, 852), own: false);
          expect(find.byKey(ProfileCoverHeader.coverKey), findsOneWidget);
          // The bar: no background, back with the @username right beside it
          // (D316) and (D335, owner 4) the ⋯ at the end, on circles.
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          expect(bar.backgroundColor, Colors.transparent);
          expect(find.byType(BackButton), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byKey(PublicProfileScreen.moreKey),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(ProfileCoverHeader.actionsKey),
              matching: find.byKey(PublicProfileScreen.moreKey),
            ),
            findsNothing,
          );
          // D299d (owner: «اليوزر اجعله في أعلى الصفحة»): the @username is
          // the bar's title over the cover too (no fade).
          expect(
            find.descendant(
              of: find.byKey(ProfileCoverBar.titleKey),
              matching: find.byKey(ProfileCoverHeader.handleKey),
            ),
            findsOneWidget,
          );
          final back = tester.getRect(find.byType(BackButton));
          final title = _rect(tester, ProfileCoverHeader.handleKey);
          if (ar) {
            // Back at the right edge (its circle 18 dp in, D335), the
            // @username just left of it.
            expect(back.right, greaterThanOrEqualTo(393 - 16));
            expect(title.right, lessThanOrEqualTo(back.left + 0.5));
            expect(back.left - title.right, lessThan(16));
          } else {
            expect(back.left, lessThanOrEqualTo(16));
            expect(title.left, greaterThanOrEqualTo(back.right - 0.5));
            expect(title.left - back.right, lessThan(16));
          }
          expect(back.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
          // D335: back and ⋯ on translucent circles over the cover.
          final circles = find.descendant(
            of: find.byType(AppBar),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is ShapeDecoration &&
                  (w.decoration as ShapeDecoration).shape is CircleBorder &&
                  (w.decoration as ShapeDecoration).color ==
                      KPublicProfile.barCircleFill,
            ),
          );
          expect(circles, findsNWidgets(2));
          for (final e in circles.evaluate()) {
            expect(
              tester.getSize(find.byWidget(e.widget)).width,
              KPublicProfile.barCircle,
            );
          }
          expect((back.center.dy - title.center.dy).abs(), lessThan(2));
          // The bar's back button sits under the status bar (59).
          expect(back.top, greaterThanOrEqualTo(59));
          // D335 (owner 3): «متابعة» a pill on the Kabso-red gradient (no
          // shadow), «مراسلة» a narrower pill in the chip colour with the
          // send icon, then the round chevron.
          final follow = tester.widget<FilledButton>(
            find.byKey(PublicProfileScreen.followKey),
          );
          expect(follow.style!.shape!.resolve({}), isA<StadiumBorder>());
          expect(follow.style!.elevation!.resolve({}), 0);
          final fill = tester.widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.byKey(PublicProfileScreen.followKey),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(
            ((fill.decoration as ShapeDecoration).gradient! as LinearGradient)
                .colors,
            KPublicProfile.gradient,
          );
          final f = _rect(tester, PublicProfileScreen.followKey);
          final m = _rect(tester, PublicProfileScreen.messageKey);
          final d = _rect(tester, ProfileCoverHeader.bondsToggleKey);
          expect(f.height, moreOrLessEquals(KPublicProfile.buttonHeight));
          expect(f.width, greaterThan(m.width));
          expect(d.width, moreOrLessEquals(d.height));
          expect(d.height, moreOrLessEquals(KPublicProfile.buttonHeight));
          // Reading order: Follow, chat, chevron (RTL mirrors it).
          if (ar) {
            expect(f.left, greaterThan(m.right));
            expect(m.left, greaterThan(d.right));
          } else {
            expect(f.right, lessThan(m.left));
            expect(m.right, lessThan(d.left));
          }
          // D268: the VIP badge first; D278b: the level badges after it.
          // D335: on the badges' line right under the name (the @username
          // is the bar's title only), at the reading start.
          final name = _rect(tester, const Key('profile.displayName'));
          final badge = tester.getRect(find.byType(VipNameBadge));
          final levels = _rect(tester, ProfileInfoBlock.levelsKey);
          expect(badge.top, greaterThanOrEqualTo(name.bottom));
          expect(find.textContaining('@host0'), findsOneWidget);
          if (ar) {
            expect(levels.right, lessThanOrEqualTo(badge.left));
          } else {
            expect(levels.left, greaterThanOrEqualTo(badge.right));
          }
          final badges = _rect(tester, ProfileCoverHeader.badgesKey);
          final line = [
            for (final e
                in find
                    .descendant(
                      of: find.byKey(ProfileCoverHeader.badgesKey),
                      matching: find.byType(VipNameBadge),
                    )
                    .evaluate())
              tester.getRect(find.byWidget(e.widget)),
          ];
          expect(line, isNotEmpty);
          expect(
            ar ? 393 - badge.right : badge.left,
            moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5),
          );
          expect(
            ar ? 393 - badges.right : badges.left,
            moreOrLessEquals(KPublicProfile.inset, epsilon: 0.5),
          );
          expect(
            levels.center.dy,
            moreOrLessEquals(badge.center.dy, epsilon: 6),
          );
          // D278c: the block under the picture is the page itself (white
          // in light, black in dark), in the theme's colours.
          final palette = brightness == Brightness.dark
              ? KPalette.dark
              : KPalette.light;
          final block = tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byKey(ProfileCoverHeader.headerKey),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
          expect(block.color, palette.background);
          final handleText = tester.widget<Text>(
            find.descendant(
              of: find.byKey(ProfileCoverHeader.handleKey),
              matching: find.byType(Text),
            ),
          );
          // D299d / D335: over the cover the @username is white with the
          // bar's soft shadow.
          expect(handleText.style?.color, KPalette.dark.textPrimary);
          expect(handleText.style?.shadows, ProfileCoverBar.coverShadow);
          final chip = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byKey(ProfileTagChips.chipKey(0)),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          // D292 (owner: «بإطار مفرّغ»): a hollow pill — no fill, a thin
          // Kabso-red outline (the text a deeper red, D279b).
          final dark = brightness == Brightness.dark;
          final shape = chip.decoration as ShapeDecoration;
          expect(shape.color, isNull);
          expect(
            (shape.shape as StadiumBorder).side.color,
            // D292: white (the theme's text colour) in dark, red in light.
            dark
                ? KPalette.dark.textPrimary.withValues(alpha: 0.85)
                : KBrandColors.red500.withValues(alpha: 0.6),
          );
          final chipBox = _rect(tester, ProfileTagChips.chipKey(0));
          expect(chipBox.height, inInclusiveRange(22, 27));
          final message = tester.widget<OutlinedButton>(
            find.byKey(PublicProfileScreen.messageKey),
          );
          expect(
            message.style!.foregroundColor!.resolve({}),
            palette.textPrimary,
          );
          // D278b: the four numbers, the person card's (short Latin).
          for (final key in [
            ProfileHeaderView.followersKey,
            ProfileHeaderView.followingKey,
            ProfileCoverHeader.cherriesKey,
            ProfileCoverHeader.coinsKey,
          ]) {
            expect(find.byKey(key), findsOneWidget);
          }
          for (final n in ['47.2K', '1.7K', '86.4K']) {
            expect(find.textContaining(n), findsOneWidget, reason: n);
          }
          // The tags as chips, on one line (checked above).
          expect(find.byKey(ProfileTagChips.chipKey(0)), findsOneWidget);
          // The link after the tags, before the numbers (D316).
          final links = _rect(tester, ProfileCoverHeader.linksKey);
          expect(
            links.top,
            greaterThanOrEqualTo(
              tester.getRect(find.byKey(ProfileTagChips.wrapKey)).bottom,
            ),
          );
          expect(
            links.bottom,
            lessThanOrEqualTo(_rect(tester, ProfileScreen.statsKey).top),
          );
        });
      }
    }

    testWidgets('D335 (owner 1): without a cover — the default Kabso cover '
        '(no blurred photo)', (tester) async {
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
      expect(find.byType(ProfileDefaultCover), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.coverAreaKey),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
    });

    // D282: a staff account's profile wears the Kabso Team badge in the
    // name row, the name in the phone's language.
    for (final language in AppLanguage.values) {
      testWidgets('a staff account wears the Kabso Team badge '
          '(${language.name})', (tester) async {
        final ar = language == AppLanguage.ar;
        await pumpOther(
          tester,
          otherProfile(ar: ar).copyWith(kabsoTeam: true),
          language: language,
        );
        final badge = find.descendant(
          of: find.byKey(ProfileCoverHeader.nameRowKey),
          matching: find.byKey(KabsoTeamBadge.badgeKey),
        );
        expect(badge, findsOneWidget);
        // D292: large enough for its name to read.
        expect(tester.getSize(badge).height, KabsoTeamBadge.profileHeight);
        expect(
          find.descendant(
            of: badge,
            matching: find.text(ar ? 'فريق كابسو' : 'Kabso Team'),
          ),
          findsOneWidget,
        );
        await precacheImages(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/profile_staff_d282.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    }

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
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverBar.titleKey),
          matching: find.text('@host0'),
        ),
        findsOneWidget,
      );
      // D299d: the same title, now in the theme's colour; once.
      expect(
        tester.widget<Text>(find.text('@host0')).style!.color,
        KPalette.light.textPrimary,
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
              expectCover(tester, screen: const Size(360, 800), own: false);
            },
          );
        }
      }
    }
  });

  group('D278 own profile', () {
    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        testWidgets('${language.name} ${brightness.name}: the same layout '
            '(the cover); «تعديل الملف» instead of follow and chat; our '
            'buttons (back, drafts, settings)', (tester) async {
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
          // D335: the cover is back, and a button on the own page (D218).
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
        expectCover(tester, screen: const Size(360, 800), own: true);
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

  group('D278b tags', () {
    Future<void> pumpTags(
      WidgetTester tester,
      List<String> tags, {
      double width = 361,
      double scale = 1,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpGolden(
        tester,
        Center(
          child: SizedBox(
            width: width,
            child: ProfileTagChips(tags: tags),
          ),
        ),
        language: AppLanguage.en,
      );
    }

    List<double> lines(WidgetTester tester) => {
      for (final e
          in find
              .descendant(
                of: find.byKey(ProfileTagChips.wrapKey),
                matching: find.byType(Text),
              )
              .evaluate())
        tester.getRect(find.byWidget(e.widget)).top.roundToDouble(),
    }.toList();

    testWidgets('a few short tags: all shown, one line, no «+n»', (
      tester,
    ) async {
      await pumpTags(tester, ['A', 'B', 'C']);
      expect(find.byKey(ProfileTagChips.chipKey(2)), findsOneWidget);
      expect(find.byKey(ProfileTagChips.moreKey), findsNothing);
      expect(lines(tester), hasLength(1));
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('ten long tags at $scale: one line (D292), the rest as '
          '«+n» (shown + hidden = 10)', (tester) async {
        await pumpTags(tester, sampleTags(ar: false), width: 328, scale: scale);
        expect(tester.takeException(), isNull);
        expect(lines(tester), hasLength(1));
        var shown = 0;
        while (find
            .byKey(ProfileTagChips.chipKey(shown))
            .evaluate()
            .isNotEmpty) {
          shown++;
        }
        final more = tester.widget<Text>(
          find.descendant(
            of: find.byKey(ProfileTagChips.moreKey),
            matching: find.byType(Text),
          ),
        );
        expect(shown + int.parse(more.data!.substring(1)), 10);
      });
    }

    testWidgets('one tag wider than the line is cut with an ellipsis', (
      tester,
    ) async {
      await pumpTags(tester, ['W' * 24], width: 120);
      expect(tester.takeException(), isNull);
      final chip = tester.getRect(find.byKey(ProfileTagChips.chipKey(0)));
      expect(chip.width, lessThanOrEqualTo(120));
    });
  });
}
