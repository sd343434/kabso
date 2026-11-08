// D299 (owner, on the profile header: «ضع الصورة الشخصية فوق الغلاف،
// وبجانبها الاسم والشارات، وتحته الميداليات»):
//
// - the photo with its frame wholly ON the picture, under the top bar, at
//   the reading start (right in Arabic, left in English), in the picture's
//   lower part;
// - beside it toward the reading end, on the picture: the name with the
//   verification seal right after it (one line, «…»), the badges (VIP,
//   Kabso Team, the crests, the levels) on at most two lines;
//   D299b (owner: «اجعل اليوزر محل الميداليات التي في الأسفل، والميداليات
//   محل اليوزر»): the worn medals under the badges, on the picture;
// - D299d (owner: «اليوزر اجعله في أعلى الصفحة»): the @username (or the
//   staff ID, or the premium badge) at the top: the bar's title, centred on
//   the line of back and ⋯, white over the cover, the theme's colour once
//   the bar is solid; shown once; cut with «…», never under the buttons;
// - under the picture: the numbers, the buttons, the tags;
// - legibility: a dark scrim at the picture's bottom; the name white with a
//   soft shadow, in light and dark;
// - D299c (owner: «اجعل البايو محل الرابط، والرابط أسفل البايو (البايو
//   فقط سطرين له)»): under the tags the bio (two lines at most, «…»; the
//   profile has no expand), then the links, then the bond tiles;
// - the top bar's back and ⋯ never on the photo or the name; «مباشر» on the
//   picture above the name block, never on it;
// - 360 × 800 at text scale 1.3, a long name and every badge: no overflow.
//
// D316 (owner, after a third-party reference: «التصميم الذي في المنتصف …
// نطبقه 100٪»): every profile but the founder's is centred now — the photo
// with its frame under the bar, the name with the seal and the badges
// centred under it, on the plain page (owner, later: «بدون غلاف» and
// «اليوزر الذي أسفل الاسم أزله لأنه موجود بالأعلى»: no cover, the
// @username only in the bar); under them the worn medals (the art alone)
// (owner 3a, before the bio), the bio (two lines, «…»), the tags, the
// links, the numbers and the buttons. The checks below keep D299's rules
// where they still hold (the seal after the name, the badges on two lines,
// the @username in the bar, the bar's buttons clear of the photo and the
// name, no overflow) and check D316's placement instead of D299's.
//
// With D299_CAPTURE_DIR set, the capture group writes PNGs there (not
// committed).

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_badge_wrap.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_live_pill.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_official_bio.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../staff/staff_d283_test.dart' show staffProfile;
import 'profile_cover_d278_test.dart'
    show coverBytes, otherProfile, pumpOther, pumpOwn;
import 'profile_live_pill_d279_test.dart' show atNow, d279Other;

const _worn = ProfileMedals(
  owned: 5,
  total: 9,
  showcase: [
    ProfileMedal(
      code: 'WEALTH_KINGS',
      name: 'Wealth Kings',
      iconKey: 'medal_wealth_kings',
      level: 3,
      iconAsset: 'medal_wealth_l3',
    ),
    ProfileMedal(
      code: 'LUCKY_MASTER',
      name: 'Lucky Master',
      iconKey: 'medal_lucky_master',
      level: 2,
      iconAsset: 'medal_lucky_l2',
    ),
    ProfileMedal(
      code: 'FIRST_CP',
      name: 'First couple',
      iconKey: 'medal_first_cp',
    ),
  ],
);

/// Someone else's profile: a cover, the seal, VIP, the host-agent crest,
/// the levels and three worn medals.
PublicProfile d299Other({required bool ar, bool self = false}) => otherProfile(
  ar: ar,
  self: self,
).copyWith(verification: VerificationBadge.hostAgent, medals: _worn);

/// The longest @username (CONVENTIONS: 3–30 characters).
const _longest = 'the_very_long_username_nabb_26';

/// A bio longer than two lines.
String longBio({required bool ar}) => ar
    ? 'موسيقى عربية كل مساء من الساعة التاسعة حتى منتصف الليل، طرب أصيل '
          'وأغاني الزمن الجميل، تعالوا شاركونا السهرة واطلبوا أغانيكم '
          'المفضلة في التعليقات، ولا تنسوا المتابعة ليصلكم إشعار البث'
    : 'Arabic music every evening from nine until midnight: classic tarab '
          'and golden-era songs. Join the night, request your favourite '
          'songs in the comments, and follow to be told when we go live';

/// Every badge, a long name and a long @username.
PublicProfile d299Crowded({required bool ar}) => d299Other(ar: ar).copyWith(
  displayName: ar
      ? 'عبدالرحمن بن سلطان الهاشمي القحطاني'
      : 'Abdulrahman bin Sultan Al-Hashimi Al-Qahtani',
  username: 'a_really_long_username_2026_x',
  kabsoTeam: true,
  rechargeAgentCode: 'coin0001',
  rechargeBadge: RechargeBadge(
    tier: 4,
    until: clock.now().toUtc().add(const Duration(hours: 2)),
  ),
);

Rect _r(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// Disposes the daily badge's timer.
Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// A bright cover (white to a pale yellow), to check the scrim.
late Uint8List _brightCover;

Future<Uint8List> _paintBrightCover() async {
  final recorder = ui.PictureRecorder();
  const size = Size(400, 300);
  ui.Canvas(recorder).drawRect(
    Offset.zero & size,
    ui.Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(400, 300), [
        const Color(0xFFFFFFFF),
        const Color(0xFFFFF4B0),
      ]),
  );
  final image = await recorder.endRecording().toImage(400, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// D316: no cover (owner: «بدون غلاف»); the photo (with its frame)
/// centred under the bar; the name block (the name and its seal, the
/// badges) centred under it, both in the top block; the @username in the
/// bar only (D299d; owner: «اليوزر الذي أسفل الاسم أزله»); the medals, the
/// bio, the numbers and the buttons under the top block. [ar]: the same
/// places in both directions.
void expectOnCover(
  WidgetTester tester, {
  required bool ar,
  required double width,
}) {
  expect(tester.takeException(), isNull);
  final area = _r(tester, ProfileCoverHeader.topBlockKey);
  final bar = tester.getRect(find.byType(AppBar));
  final photo = _r(tester, ProfileHeaderView.avatarKey);
  final slot = KPublicProfile.avatarSlot;
  expect(area.top, 0);
  expect(area.width, width);
  // The photo's box (at most the frames' slot) wholly on the cover, under
  // the bar, centred.
  expect(photo.width, lessThanOrEqualTo(slot.width + 0.5));
  expect(photo.top, greaterThanOrEqualTo(bar.bottom));
  expect(photo.bottom, lessThanOrEqualTo(area.bottom));
  expect(photo.center.dx, moreOrLessEquals(width / 2, epsilon: 0.5));
  // The name block under it, centred, on the cover; the cover ends just
  // under it.
  final identity = _r(tester, ProfileCoverHeader.identityKey);
  // The name with its seal after it: the line is centred.
  final nameLine = _r(tester, ProfileCoverHeader.nameLineKey);
  final handle = _r(tester, ProfileCoverHeader.handleKey);
  for (final r in [identity, nameLine]) {
    expect(r.top, greaterThanOrEqualTo(photo.bottom));
    expect(r.bottom, lessThanOrEqualTo(area.bottom));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(width));
    expect(r.center.dx, moreOrLessEquals(width / 2, epsilon: 1));
  }
  expect(
    area.bottom,
    moreOrLessEquals(
      identity.bottom + KPublicProfile.centredIdentityBottom,
      epsilon: 0.5,
    ),
  );
  for (final key in [
    ProfileCoverHeader.coverAreaKey,
    ProfileCoverHeader.coverKey,
    ProfileCoverHeader.coverFallbackKey,
    ProfileCoverHeader.coverAvatarKey,
    ProfileCoverHeader.staffCoverKey,
    ProfileCoverHeader.coverScrimKey,
    ProfileCoverHeader.coverTopShadeKey,
  ]) {
    expect(find.byKey(key), findsNothing);
  }
  // The bar's buttons never on the photo or the name block.
  for (final button in [
    tester.getRect(find.byType(BackButton)),
    if (find.byKey(PublicProfileScreen.moreKey).evaluate().isNotEmpty)
      _r(tester, PublicProfileScreen.moreKey),
  ]) {
    expect(button.overlaps(photo), isFalse);
    expect(button.overlaps(identity), isFalse);
  }
  // D299d: the @username in the bar, on the line of back, never
  // under them.
  expect(
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byKey(ProfileCoverHeader.handleKey),
    ),
    findsOneWidget,
  );
  final back = tester.getRect(find.byType(BackButton));
  expect(handle.center.dy, moreOrLessEquals(back.center.dy, epsilon: 1));
  for (final button in [
    back,
    if (find.byKey(PublicProfileScreen.moreKey).evaluate().isNotEmpty)
      _r(tester, PublicProfileScreen.moreKey),
  ]) {
    expect(handle.overlaps(button), isFalse);
  }
  expect(handle.left, greaterThanOrEqualTo(0));
  expect(handle.right, lessThanOrEqualTo(width));
  // Under the top block: the medals (when worn), then the numbers, then
  // the buttons, centred.
  final stats = _r(tester, ProfileScreen.statsKey);
  final actions = _r(tester, ProfileCoverHeader.actionsKey);
  final medals = find.byKey(ProfileCoverHeader.medalsKey);
  if (medals.evaluate().isNotEmpty) {
    final m = tester.getRect(medals);
    expect(m.top, greaterThanOrEqualTo(area.bottom));
    expect(stats.top, greaterThanOrEqualTo(m.bottom));
  }
  expect(stats.top, greaterThanOrEqualTo(area.bottom));
  expect(stats.center.dx, moreOrLessEquals(width / 2, epsilon: 1));
  expect(actions.top, greaterThanOrEqualTo(stats.bottom));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    _brightCover = await _paintBrightCover();
  });
  setUp(() {
    profileCoverImageFor = (_) => MemoryImage(coverBytes);
  });
  tearDown(() {
    profileCoverImageFor = NetworkImage.new;
  });

  test('D299: the cover holds the bar, the whole photo box and a margin '
      '(≈ 270 dp under a 125 dp bar; D292: 213 dp)', () {
    expect(
      KPublicProfile.coverHeightFor(125),
      (125 +
              KPublicProfile.avatarTopGap +
              KPublicProfile.avatarSlot.height +
              KPublicProfile.coverBottomGap)
          .roundToDouble(),
    );
    expect(KPublicProfile.coverHeightFor(125), 270);
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    for (final brightness in Brightness.values) {
      testWidgets('${language.name} ${brightness.name}: the photo on the '
          'cover, the name block and the medals beside it, the @username '
          'at the top', (tester) async {
        await pumpOther(
          tester,
          d299Other(ar: ar),
          language: language,
          brightness: brightness,
        );
        expectOnCover(tester, ar: ar, width: 393);
        // The seal right after the name.
        final name = _r(tester, const Key('profile.displayName'));
        final seal = tester.getRect(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.nameLineKey),
            matching: find.byType(ProfileVerificationBadge),
          ),
        );
        if (ar) {
          expect(seal.right, lessThanOrEqualTo(name.left));
          expect(name.left - seal.right, lessThanOrEqualTo(KSpacing.xs + 1));
        } else {
          expect(seal.left, greaterThanOrEqualTo(name.right));
          expect(seal.left - name.right, lessThanOrEqualTo(KSpacing.xs + 1));
        }
        expect(seal.center.dy, moreOrLessEquals(name.center.dy, epsilon: 1));
        // The badges under the name line (and the @username); D316: the
        // medals first under the cover, then the bio (owner: «الميداليات
        // قبل البايو»).
        final line = _r(tester, ProfileCoverHeader.nameLineKey);
        final badges = _r(tester, ProfileCoverHeader.badgesKey);
        final medals = _r(tester, ProfileCoverHeader.medalsKey);
        final bio = _r(tester, ProfileCoverHeader.bioKey);
        expect(badges.top, greaterThanOrEqualTo(line.bottom));
        expect(medals.top, greaterThanOrEqualTo(badges.bottom));
        expect(
          bio.top - medals.bottom,
          moreOrLessEquals(KPublicProfile.centredBioGap, epsilon: 0.5),
        );
        for (final key in [
          ProfileHeaderView.hostAgentBadgeKey,
          ProfileCoverHeader.levelsKey,
        ]) {
          final r = _r(tester, key);
          expect(r.top, greaterThanOrEqualTo(badges.top), reason: '$key');
          expect(r.bottom, lessThanOrEqualTo(badges.bottom), reason: '$key');
        }
        // The worn medals, 32 dp art (no chip), in order.
        final icons = [
          for (final m in _worn.showcase)
            _r(tester, MedalShowcaseRow.medalKey(m.code)),
        ];
        for (final i in icons) {
          expect(i.height, KPublicProfile.centredMedal);
        }
        expect(KPublicProfile.centredMedal, inInclusiveRange(28, 34));
        // In the user's order from the reading start, centred.
        if (ar) {
          expect(icons[1].right, lessThanOrEqualTo(icons[0].left));
        } else {
          expect(icons[1].left, greaterThanOrEqualTo(icons[0].right));
        }
        expect(
          (icons.first.center.dx + icons.last.center.dx) / 2,
          moreOrLessEquals(393 / 2, epsilon: 1),
        );
        // D316: the theme's text colour on the plain page, no shadow.
        final palette = brightness == Brightness.dark
            ? KPalette.dark
            : KPalette.light;
        final nameText = tester.widget<Text>(
          find.byKey(const Key('profile.displayName')),
        );
        expect(nameText.style!.color, palette.textPrimary);
        expect(nameText.maxLines, 1);
        expect(nameText.overflow, TextOverflow.ellipsis);
        expect(find.byKey(ProfileCoverHeader.nameShadeKey), findsNothing);
        // Found and read once.
        expect(find.text(nameText.data!), findsOneWidget);
        // D299d: the @username in the bar; D316: beside back, in the theme's
        // colour, no shadow; not again under the name.
        final handleText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.handleKey),
            matching: find.byType(Text),
          ),
        );
        expect(handleText.data, contains('@host0'));
        expect(handleText.style!.color, palette.textPrimary);
        expect(handleText.style!.shadows, isNull);
        // D316: at the reading start beside back (not centred).
        final handleRect = _r(tester, ProfileCoverHeader.handleKey);
        if (ar) {
          expect(handleRect.center.dx, greaterThan(393 / 2));
        } else {
          expect(handleRect.center.dx, lessThan(393 / 2));
        }
        // The @username once: the bar's title (no line under the name).
        expect(find.textContaining('@host0'), findsOneWidget);
        // The plain page under the header (no cover picture).
        final block = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byKey(ProfileCoverHeader.headerKey),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(block.color, palette.background);
        await _end(tester);
      });
    }

    testWidgets('the own profile: the same layout (${language.name})', (
      tester,
    ) async {
      await pumpOwn(
        tester,
        language: language,
        stats: d299Other(ar: ar, self: true),
      );
      expectOnCover(tester, ar: ar, width: 393);
      // D316: no cover to tap on the page (the cover is set in the edit
      // screen); the medals before the bio.
      expect(find.byKey(ProfileCoverHeader.coverButtonKey), findsNothing);
      expect(
        _r(tester, ProfileCoverHeader.bioKey).top,
        greaterThanOrEqualTo(_r(tester, ProfileCoverHeader.medalsKey).bottom),
      );
      await _end(tester);
    });

    testWidgets('no cover set: the same layout, no fallback either '
        '(${language.name})', (tester) async {
      await pumpOther(
        tester,
        otherProfile(ar: ar, cover: false),
        language: language,
      );
      expectOnCover(tester, ar: ar, width: 393);
      expect(find.byKey(ProfileCoverHeader.coverKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coverFallbackKey), findsNothing);
      // No medal worn: no medals row; the bio, then the numbers.
      expect(find.byKey(MedalShowcaseRow.rowKey), findsNothing);
      final bio = _r(tester, ProfileCoverHeader.bioKey);
      final stats = _r(tester, ProfileScreen.statsKey);
      expect(stats.top, greaterThanOrEqualTo(bio.bottom));
    });

    testWidgets('a staff profile: no region cover (D316), the staff ID at '
        'the top, the official card under the numbers '
        '(${language.name})', (tester) async {
      await pumpOther(
        tester,
        staffProfile(
          ar: ar,
        ).copyWith(staffId: 'Kabso01', verification: VerificationBadge.staff),
        language: language,
      );
      expectOnCover(tester, ar: ar, width: 393);
      // D299h: the staff ID as the gold special-ID pill, «Kabso01».
      final id = tester.widget<KStaffIdText>(
        find.byKey(ProfileCoverHeader.staffIdKey),
      );
      expect(id.staffId, 'Kabso01');
      expect(id.height, KStaffIdText.bar);
      // D316: the staff ID only in the bar (none under the name).
      expect(find.byType(KStaffIdText), findsOneWidget);
      final idRect = _r(tester, ProfileCoverHeader.staffIdKey);
      expect(
        idRect.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
      );
      expect(find.byKey(ProfileCoverHeader.medalsKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.levelsKey), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(StaffOfficialBio.titleKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        _r(tester, StaffOfficialBio.titleKey).top,
        greaterThan(_r(tester, ProfileScreen.statsKey).bottom),
      );
    });

    testWidgets('a premium @username at the top, its badge in the bar '
        '(${language.name})', (tester) async {
      await pumpOther(
        tester,
        d299Other(
          ar: ar,
        ).copyWith(username: 'kingofthenight', premiumTier: PremiumTier.legend),
        language: language,
      );
      expectOnCover(tester, ar: ar, width: 393);
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.byType(KSpecialUsername),
        ),
        findsOneWidget,
      );
    });

    testWidgets('live: «مباشر» on the cover above the name, never on '
        'it (${language.name})', (tester) async {
      await atNow(() async {
        await pumpOther(tester, d279Other(ar: ar), language: language);
        expectOnCover(tester, ar: ar, width: 393);
        final pill = _r(tester, ProfileLivePill.pillKey);
        final area = _r(tester, ProfileCoverHeader.topBlockKey);
        final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
        final bar = tester.getRect(find.byType(AppBar));
        expect(pill.top, greaterThanOrEqualTo(bar.bottom));
        expect(pill.bottom, lessThanOrEqualTo(nameRow.top));
        expect(pill.bottom, lessThanOrEqualTo(area.bottom));
        // D316: centred, under the photo (was at the reading end).
        expect(pill.center.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
        expect(
          pill.top,
          greaterThanOrEqualTo(_r(tester, ProfileHeaderView.avatarKey).bottom),
        );
      });
    });

    testWidgets('a private profile: the same header, the notice under it '
        '(${language.name})', (tester) async {
      await pumpOther(
        tester,
        otherProfile(ar: ar).copyWith(isPrivate: true, isFollowing: false),
        language: language,
      );
      expectOnCover(tester, ar: ar, width: 393);
      await tester.scrollUntilVisible(
        find.byKey(PublicProfileScreen.privateKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(PublicProfileScreen.privateKey), findsOneWidget);
    });

    testWidgets('360 × 800 at text scale 1.3, a long name and every badge: '
        'the name on one line with «…», the badges on at most two lines, '
        'no overflow (${language.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpOther(
        tester,
        d299Crowded(ar: ar),
        language: language,
        viewport: GoldenViewport.android,
      );
      expectOnCover(tester, ar: ar, width: 360);
      final name = _r(tester, const Key('profile.displayName'));
      final line = _r(tester, ProfileCoverHeader.nameLineKey);
      // One line, cut (the line's height is the name's one line).
      expect(name.height, lessThan(KPublicProfile.centredNameFont * 1.3 * 2));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile.displayName')))
            .overflow,
        TextOverflow.ellipsis,
      );
      // The seal stays visible after the cut name.
      final seal = tester.getRect(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.nameLineKey),
          matching: find.byType(ProfileVerificationBadge),
        ),
      );
      expect(seal.left, greaterThanOrEqualTo(line.left));
      expect(seal.right, lessThanOrEqualTo(line.right));
      // Right after the cut name (no gap left by the cut).
      if (ar) {
        expect(name.left - seal.right, lessThanOrEqualTo(KSpacing.xs + 1));
      } else {
        expect(seal.left - name.right, lessThanOrEqualTo(KSpacing.xs + 1));
      }
      // The badges: at most two lines of the tallest badge.
      final wrap = tester.renderObject<RenderProfileBadgeWrap>(
        find.byKey(ProfileCoverHeader.badgesKey),
      );
      final badges = _r(tester, ProfileCoverHeader.badgesKey);
      final shown = <Rect>[];
      var child = wrap.firstChild;
      while (child != null) {
        final data = child.parentData! as ProfileBadgeWrapParentData;
        if (!data.hidden) {
          shown.add(
            MatrixUtils.transformRect(
              child.getTransformTo(null),
              Offset.zero & child.size,
            ),
          );
        }
        child = data.nextSibling;
      }
      expect(shown, isNotEmpty);
      final lines = <int>{for (final r in shown) r.center.dy.round()};
      expect(lines.length, lessThanOrEqualTo(KPublicProfile.badgeLines));
      for (final r in shown) {
        expect(r.left, greaterThanOrEqualTo(badges.left - 0.5));
        expect(r.right, lessThanOrEqualTo(badges.right + 0.5));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(360));
      }
      final handle = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.byType(Text),
        ),
      );
      expect(handle.maxLines, 1);
      expect(handle.overflow, TextOverflow.ellipsis);
      // D316: the long @username beside back, on the screen (cut with «…»
      // when it does not fit), clear of back.
      final h = _r(tester, ProfileCoverHeader.handleKey);
      expect(h.left, greaterThanOrEqualTo(0));
      expect(h.right, lessThanOrEqualTo(360));
      expect(h.overlaps(tester.getRect(find.byType(BackButton))), isFalse);
      await _end(tester);
    });

    testWidgets('the bar turns solid once the cover has scrolled away '
        '(${language.name})', (tester) async {
      await pumpOther(tester, d299Other(ar: ar), language: language);
      AppBar bar() => tester.widget<AppBar>(find.byType(AppBar));
      expect(bar().backgroundColor, Colors.transparent);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(bar().backgroundColor, isNot(Colors.transparent));
      // D299d: the same @username stays the title, in the theme's colour.
      final handle = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.byType(Text),
        ),
      );
      expect(handle.style!.color, KPalette.light.textPrimary);
      expect(handle.style!.shadows, isNull);
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.textContaining('@host0'),
        ),
        findsOneWidget,
      );
    });
  }

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;

    /// D316: the cover → the medals → the bio → the tags → the links → the
    /// numbers, each just under the one before; the bond tiles right after
    /// the header.
    void expectOrder(
      WidgetTester tester, {
      required bool bio,
      required bool links,
    }) {
      expect(tester.takeException(), isNull);
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final area = tester.getRect(find.byKey(ProfileCoverHeader.topBlockKey));
      final tags = tester.getRect(find.byKey(ProfileTagChips.wrapKey));
      final bioF = find.byKey(ProfileCoverHeader.bioKey);
      final linksF = find.byKey(ProfileCoverHeader.linksKey);
      final medalsF = find.byKey(ProfileCoverHeader.medalsKey);
      expect(bioF, bio ? findsOneWidget : findsNothing);
      expect(linksF, links ? findsOneWidget : findsNothing);
      var above = area.bottom;
      if (medalsF.evaluate().isNotEmpty) {
        // The art 10 dp under the name block, in its 44 dp tap target.
        final r = tester.getRect(medalsF);
        expect(
          r.top - above,
          moreOrLessEquals(
            KPublicProfile.centredMedalsGap -
                (KPublicProfile.centredMedalTap - KPublicProfile.centredMedal) /
                    2,
            epsilon: 0.5,
          ),
        );
        above = r.bottom;
      }
      if (bio) {
        final r = tester.getRect(bioF);
        expect(
          r.top - above,
          moreOrLessEquals(KPublicProfile.centredBioGap, epsilon: 0.5),
        );
        above = r.bottom;
        // Centred, within the header's margins.
        expect(r.center.dx, moreOrLessEquals(width / 2, epsilon: 0.5));
        expect(r.left, greaterThanOrEqualTo(KPublicProfile.centredInset - 0.5));
      }
      expect(tags.top - above, moreOrLessEquals(KSpacing.sm, epsilon: 0.5));
      above = tags.bottom;
      if (links) {
        final r = tester.getRect(linksF);
        expect(r.top, greaterThanOrEqualTo(above));
        expect(r.top - above, lessThanOrEqualTo(KSpacing.xs + 0.5));
        above = r.bottom;
      }
      final stats = tester.getRect(find.byKey(ProfileScreen.statsKey));
      expect(
        stats.top - above,
        moreOrLessEquals(KPublicProfile.centredStatsGap, epsilon: 0.5),
      );
      // The bond tiles right after the header (no empty band).
      final header = tester.getRect(find.byKey(ProfileCoverHeader.headerKey));
      final tiles = tester.getRect(find.byType(ProfileInfoBlock));
      expect(tiles.top, greaterThanOrEqualTo(header.bottom));
      expect(tiles.top - header.bottom, lessThanOrEqualTo(KSpacing.md));
      // The bio is never repeated under the header.
      expect(
        find.descendant(
          of: find.byType(ProfileInfoBlock),
          matching: find.textContaining(ar ? 'موسيقى' : 'Arabic music'),
        ),
        findsNothing,
      );
    }

    testWidgets('D316 the medals under the cover, the bio, the tags, then '
        'the link '
        '(${language.name})', (tester) async {
      await pumpOther(tester, d299Other(ar: ar), language: language);
      expect(
        tester.widget<Text>(find.byKey(ProfileCoverHeader.bioKey)).data,
        ar ? 'موسيقى عربية كل مساء' : 'Arabic music every evening',
      );
      expectOrder(tester, bio: true, links: true);
    });

    testWidgets('D299c a long bio: two lines and «…» (${language.name})', (
      tester,
    ) async {
      await pumpOther(
        tester,
        d299Other(ar: ar).copyWith(bio: longBio(ar: ar)),
        language: language,
      );
      final text = tester.widget<Text>(find.byKey(ProfileCoverHeader.bioKey));
      expect(text.maxLines, KPublicProfile.bioLines);
      expect(KPublicProfile.bioLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.bioKey),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      final r = tester.getRect(find.byKey(ProfileCoverHeader.bioKey));
      final line = text.style!.fontSize! * (text.style!.height ?? 1.5);
      expect(r.height, lessThanOrEqualTo(2 * line + 1));
      expectOrder(tester, bio: true, links: true);
    });

    for (final (bio, links) in [(false, true), (true, false), (false, false)]) {
      testWidgets('D299c bio $bio, link $links (${language.name})', (
        tester,
      ) async {
        await pumpOther(
          tester,
          d299Other(ar: ar).copyWith(
            bio: bio ? otherProfile(ar: ar).bio : null,
            links: links ? otherProfile(ar: ar).links : const [],
          ),
          language: language,
        );
        expectOrder(tester, bio: bio, links: links);
      });
    }

    testWidgets('D299c 360 × 800 at 1.3, a long bio: two lines, the link and '
        'the tiles after it (${language.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpOther(
        tester,
        d299Other(ar: ar).copyWith(bio: longBio(ar: ar)),
        language: language,
        viewport: GoldenViewport.android,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final r = tester.getRect(find.byKey(ProfileCoverHeader.bioKey));
      expect(r.left, greaterThanOrEqualTo(KPublicProfile.centredInset - 0.5));
      expect(
        r.right,
        lessThanOrEqualTo(360 - KPublicProfile.centredInset + 0.5),
      );
      expectOrder(tester, bio: true, links: true);
    });
  }

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    for (final (viewport, scale) in [
      (GoldenViewport.phone, 1.0),
      (GoldenViewport.phone, 2.0),
      (GoldenViewport.android, 1.3),
    ]) {
      final width = viewport.logicalSize.width;
      testWidgets('D299f the 30-character @username at ${width.round()} × '
          '$scale: 16 dp bold (scale capped at 1.15), beside back (D316), '
          'on one line («…» when it does not fit), clear of back '
          '(${language.name})', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpOther(
          tester,
          d299Other(ar: ar).copyWith(username: _longest),
          language: language,
          viewport: viewport,
        );
        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.handleKey),
            matching: find.byType(Text),
          ),
        );
        expect(text.style!.fontSize, KPublicProfile.barTitleFont);
        expect(text.style!.fontWeight, FontWeight.w700);
        expect(
          text.textScaler!.scale(10),
          moreOrLessEquals(
            10 * math.min(scale, KPublicProfile.barTitleMaxScale),
          ),
        );
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
        // Isolated left to right: «@» first, the cut at the end.
        expect(text.textDirection, TextDirection.ltr);
        // D316 (owner: «اليوزر بجانب السهم»): at the reading start right
        // beside back, inside the screen; no ⋯ in the bar.
        final handle = _r(tester, ProfileCoverHeader.handleKey);
        final back = tester.getRect(find.byType(BackButton));
        expect(handle.overlaps(back), isFalse);
        if (ar) {
          expect(handle.right, lessThanOrEqualTo(back.left + 0.5));
          expect(back.left - handle.right, lessThan(16));
        } else {
          expect(handle.left, greaterThanOrEqualTo(back.right - 0.5));
          expect(handle.left - back.right, lessThan(16));
        }
        expect(handle.left, greaterThanOrEqualTo(0));
        expect(handle.right, lessThanOrEqualTo(width));
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byKey(PublicProfileScreen.moreKey),
          ),
          findsNothing,
        );
        expect(handle.height, lessThan(KPublicProfile.barTitleFont * 2));
        await _end(tester);
      });
    }
  }

  testWidgets('the badge wrap: a badge past the second line is not shown, '
      'hit or read', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: 100,
            child: ProfileBadgeWrap(
              key: Key('wrap'),
              maxLines: 2,
              spacing: 8,
              runSpacing: 4,
              children: [
                SizedBox(key: Key('a'), width: 60, height: 20),
                SizedBox(key: Key('b'), width: 60, height: 30),
                SizedBox(key: Key('c'), width: 30, height: 20),
                SizedBox(key: Key('d'), width: 60, height: 20),
              ],
            ),
          ),
        ),
      ),
    );
    final wrap = tester.renderObject<RenderProfileBadgeWrap>(
      find.byKey(const Key('wrap')),
    );
    // a | b c | (d hidden)
    expect(wrap.hiddenCount, 1);
    expect(wrap.size.height, 20 + 4 + 30);
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    final c = tester.getRect(find.byKey(const Key('c')));
    // RTL: from the right; the runs centred on their line.
    expect(a.right, wrap.localToGlobal(Offset(wrap.size.width, 0)).dx);
    expect(b.right, a.right);
    expect(c.right, b.left - 8);
    expect(c.center.dy, b.center.dy);
    expect(b.top, a.bottom + 4);
  });

  for (final dir in TextDirection.values) {
    testWidgets('D316 the centred badge wrap: each line centred in the box '
        '(${dir.name})', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: dir,
          child: const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: Center(
                child: ProfileBadgeWrap(
                  key: Key('wrap'),
                  maxLines: 2,
                  spacing: 8,
                  runSpacing: 4,
                  centre: true,
                  children: [
                    SizedBox(key: Key('a'), width: 60, height: 20),
                    SizedBox(key: Key('b'), width: 50, height: 20),
                    SizedBox(key: Key('c'), width: 30, height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byKey(const Key('wrap')));
      final a = tester.getRect(find.byKey(const Key('a')));
      final b = tester.getRect(find.byKey(const Key('b')));
      final c = tester.getRect(find.byKey(const Key('c')));
      // a | b c — the box as wide as the widest line (b c: 88).
      expect(box.width, 88);
      expect(a.center.dx, moreOrLessEquals(box.center.dx, epsilon: 0.01));
      final line = b.expandToInclude(c);
      expect(line.center.dx, moreOrLessEquals(box.center.dx, epsilon: 0.01));
      // The reading order kept within the line.
      if (dir == TextDirection.rtl) {
        expect(c.right, b.left - 8);
      } else {
        expect(c.left, b.right + 8);
      }
    });
  }

  final captureDir = Platform.environment['D299_CAPTURE_DIR'];
  group('D299 captures', skip: captureDir == null, () {
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

    for (final brightness in Brightness.values) {
      testWidgets('other ar ${brightness.name}', (tester) async {
        await pumpOther(
          tester,
          d299Other(ar: true),
          language: AppLanguage.ar,
          brightness: brightness,
        );
        await capture(tester, 'other.ar.${brightness.name}');
      });
    }
    testWidgets('other ar light no medals', (tester) async {
      await pumpOther(tester, otherProfile(ar: true), language: AppLanguage.ar);
      await capture(tester, 'other.ar.light.nomedals');
    });
    testWidgets('other ar light long bio', (tester) async {
      await pumpOther(
        tester,
        d299Other(ar: true).copyWith(bio: longBio(ar: true)),
        language: AppLanguage.ar,
      );
      await capture(tester, 'other.ar.light.longbio');
    });
    testWidgets('other ar light long username', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpOther(
        tester,
        d299Other(ar: true).copyWith(username: _longest),
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      await capture(tester, 'other.ar.light.longusername.360x1.3');
    });
    testWidgets('other ar light 30-character username 393', (tester) async {
      await pumpOther(
        tester,
        d299Other(ar: true).copyWith(username: _longest),
        language: AppLanguage.ar,
      );
      await capture(tester, 'other.ar.light.longusername.393');
    });
    testWidgets('other en light', (tester) async {
      await pumpOther(tester, d299Other(ar: false), language: AppLanguage.en);
      await capture(tester, 'other.en.light');
    });
    testWidgets('own ar', (tester) async {
      await pumpOwn(
        tester,
        language: AppLanguage.ar,
        stats: d299Other(ar: true, self: true),
      );
      await capture(tester, 'own.ar.light');
    });
    testWidgets('staff ar', (tester) async {
      await pumpOther(
        tester,
        staffProfile(
          ar: true,
        ).copyWith(staffId: 'Kabso01', verification: VerificationBadge.staff),
        language: AppLanguage.ar,
      );
      await capture(tester, 'staff.ar.light');
    });
    testWidgets('360 1.3 ar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpOther(
        tester,
        d299Crowded(ar: true),
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      await capture(tester, 'other.360x1.3.ar');
      await _end(tester);
    });
    for (final brightness in Brightness.values) {
      testWidgets('bright cover ar ${brightness.name}', (tester) async {
        profileCoverImageFor = (_) => MemoryImage(_brightCover);
        await pumpOther(
          tester,
          d299Other(ar: true),
          language: AppLanguage.ar,
          brightness: brightness,
        );
        await capture(tester, 'bright.ar.${brightness.name}');
      });
    }
    testWidgets('no cover live ar', (tester) async {
      await atNow(() async {
        await pumpOther(
          tester,
          d279Other(ar: true).copyWith(coverUrl: null),
          language: AppLanguage.ar,
        );
        await capture(tester, 'nocover.live.ar.light');
      });
    });
  });
}
