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

/// The photo wholly on the picture at the reading start; the name block
/// beside it on the picture (D299b: the medals in it); the @username in the
/// bar (D299d); the numbers and the buttons under the picture.
void expectOnCover(
  WidgetTester tester, {
  required bool ar,
  required double width,
}) {
  expect(tester.takeException(), isNull);
  final area = _r(tester, ProfileCoverHeader.coverAreaKey);
  final bar = tester.getRect(find.byType(AppBar));
  final photo = _r(tester, ProfileHeaderView.avatarKey);
  final slot = KPublicProfile.avatarSlot;
  expect(area.top, 0);
  expect(area.width, width);
  expect(
    area.height,
    greaterThanOrEqualTo(KPublicProfile.coverHeightFor(bar.bottom)),
  );
  // The photo's box (centred in the slot) wholly on the picture, under
  // the bar, in its lower part, at the reading start.
  final box = Rect.fromCenter(
    center: photo.center,
    width: slot.width,
    height: slot.height,
  );
  expect(box.top, greaterThanOrEqualTo(bar.bottom));
  expect(box.bottom, lessThanOrEqualTo(area.bottom));
  expect(photo.center.dy, greaterThan(area.center.dy));
  if (ar) {
    expect(
      box.right,
      moreOrLessEquals(width - KPublicProfile.avatarStart, epsilon: 0.5),
    );
  } else {
    expect(
      box.left,
      moreOrLessEquals(KPublicProfile.avatarStart, epsilon: 0.5),
    );
  }
  // The name block beside it, toward the reading end, on the picture.
  final identity = _r(tester, ProfileCoverHeader.identityKey);
  final name = _r(tester, const Key('profile.displayName'));
  final handle = _r(tester, ProfileCoverHeader.handleKey);
  final medals = find.byKey(ProfileCoverHeader.medalsKey);
  for (final r in [
    identity,
    name,
    if (medals.evaluate().isNotEmpty) tester.getRect(medals),
  ]) {
    expect(r.top, greaterThanOrEqualTo(bar.bottom));
    expect(r.bottom, lessThanOrEqualTo(area.bottom));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(width));
    if (ar) {
      expect(r.right, lessThanOrEqualTo(box.left));
    } else {
      expect(r.left, greaterThanOrEqualTo(box.right));
    }
  }
  // The name at the block's reading start; the medals (when worn) under
  // it.
  if (ar) {
    expect(name.right, moreOrLessEquals(identity.right, epsilon: 0.5));
  } else {
    expect(name.left, moreOrLessEquals(identity.left, epsilon: 0.5));
  }
  final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
  if (medals.evaluate().isNotEmpty) {
    expect(tester.getRect(medals).top, greaterThanOrEqualTo(nameRow.bottom));
  }
  // The bar's buttons never on the photo or the name block.
  for (final button in [
    tester.getRect(find.byType(BackButton)),
    if (find.byKey(PublicProfileScreen.moreKey).evaluate().isNotEmpty)
      _r(tester, PublicProfileScreen.moreKey),
  ]) {
    expect(button.overlaps(box), isFalse);
    expect(button.overlaps(identity), isFalse);
  }
  // D299d: the @username in the bar, on the line of back and ⋯, never
  // under them; once on the page.
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
  // Under the picture: the numbers right away, then the buttons.
  final stats = _r(tester, ProfileScreen.statsKey);
  final actions = _r(tester, ProfileCoverHeader.actionsKey);
  expect(stats.top, greaterThanOrEqualTo(area.bottom));
  expect(stats.top - area.bottom, lessThanOrEqualTo(KSpacing.md + 0.5));
  expect(actions.top, greaterThanOrEqualTo(stats.bottom));
  // The scrim over the picture's bottom, under the name block.
  final scrim = _r(tester, ProfileCoverHeader.coverScrimKey);
  expect(scrim.bottom, area.bottom);
  expect(scrim.top, lessThanOrEqualTo(identity.top));
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
        final area = _r(tester, ProfileCoverHeader.coverAreaKey);
        // 393 × 852 with a 59 dp status bar: exactly the least height.
        expect(area.height, 270);
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
        // The badges under the name line, the medals under them.
        final line = _r(tester, ProfileCoverHeader.nameLineKey);
        final badges = _r(tester, ProfileCoverHeader.badgesKey);
        final medals = _r(tester, ProfileCoverHeader.medalsKey);
        expect(badges.top, greaterThanOrEqualTo(line.bottom));
        expect(medals.top, greaterThanOrEqualTo(badges.bottom));
        expect(medals.top - badges.bottom, lessThanOrEqualTo(KSpacing.xs));
        for (final key in [
          ProfileHeaderView.hostAgentBadgeKey,
          ProfileCoverHeader.levelsKey,
        ]) {
          final r = _r(tester, key);
          expect(r.top, greaterThanOrEqualTo(badges.top), reason: '$key');
          expect(r.bottom, lessThanOrEqualTo(badges.bottom), reason: '$key');
        }
        // The worn medals at the block's reading start, 28 dp, in order.
        final icons = [
          for (final m in _worn.showcase)
            _r(tester, MedalShowcaseRow.medalKey(m.code)),
        ];
        for (final i in icons) {
          expect(i.height, KPublicProfile.medal);
          expect(i.bottom, lessThanOrEqualTo(area.bottom));
        }
        expect(KPublicProfile.medal, inInclusiveRange(28, 30));
        if (ar) {
          expect(icons.first.right, moreOrLessEquals(line.right, epsilon: 1));
          expect(icons[1].right, lessThanOrEqualTo(icons[0].left));
        } else {
          expect(icons.first.left, moreOrLessEquals(line.left, epsilon: 1));
          expect(icons[1].left, greaterThanOrEqualTo(icons[0].right));
        }
        // White over the picture in both themes: the name with a soft
        // shadow (drawn under it).
        final white = KPalette.dark.textPrimary;
        final nameText = tester.widget<Text>(
          find.byKey(const Key('profile.displayName')),
        );
        expect(nameText.style!.color, white);
        expect(nameText.maxLines, 1);
        expect(nameText.overflow, TextOverflow.ellipsis);
        final shade = tester.widget<RichText>(
          find.byKey(ProfileCoverHeader.nameShadeKey),
        );
        expect(shade.text.toPlainText(), nameText.data);
        expect(shade.text.style!.shadows, ProfileCoverBar.coverShadow);
        expect(shade.text.style!.color!.a, 0);
        // Found and read once.
        expect(find.text(nameText.data!), findsOneWidget);
        // D299d: the @username in the bar, centred, white with the bar's
        // shadow over the cover in both themes.
        final handleText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.handleKey),
            matching: find.byType(Text),
          ),
        );
        expect(handleText.data, contains('@host0'));
        expect(handleText.style!.color, white);
        expect(handleText.style!.shadows, ProfileCoverBar.coverShadow);
        expect(
          _r(tester, ProfileCoverHeader.handleKey).center.dx,
          moreOrLessEquals(393 / 2, epsilon: 1),
        );
        expect(find.textContaining('@host0'), findsOneWidget);
        // The scrim: dark at the bottom, clear at its top.
        final scrim = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.coverScrimKey),
            matching: find.byType(DecoratedBox),
          ),
        );
        final gradient =
            (scrim.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.begin, Alignment.bottomCenter);
        expect(gradient.colors.first, KPublicProfile.scrimBottom);
        expect(gradient.colors.last.a, 0);
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
      expect(find.byKey(ProfileCoverHeader.coverButtonKey), findsOneWidget);
      expect(
        _r(tester, ProfileCoverHeader.medalsKey).bottom,
        lessThanOrEqualTo(_r(tester, ProfileCoverHeader.coverAreaKey).bottom),
      );
      await _end(tester);
    });

    testWidgets('no cover: the fallback with the same scrim and layout '
        '(${language.name})', (tester) async {
      await pumpOther(
        tester,
        otherProfile(ar: ar, cover: false),
        language: language,
      );
      expectOnCover(tester, ar: ar, width: 393);
      expect(find.byKey(ProfileCoverHeader.coverKey), findsNothing);
      expect(find.byKey(ProfileCoverHeader.coverFallbackKey), findsOneWidget);
      // No medal worn: no medals row; the name block is just shorter (the
      // picture keeps its least height).
      expect(find.byKey(MedalShowcaseRow.rowKey), findsNothing);
      final area = _r(tester, ProfileCoverHeader.coverAreaKey);
      expect(area.height, 270);
      final stats = _r(tester, ProfileScreen.statsKey);
      expect(stats.top - area.bottom, lessThanOrEqualTo(KSpacing.md + 0.5));
    });

    testWidgets('a staff profile: the team picture on the cover, the staff '
        'ID at the top, the official card under the numbers '
        '(${language.name})', (tester) async {
      await pumpOther(
        tester,
        staffProfile(
          ar: ar,
        ).copyWith(staffId: 'Kabso01', verification: VerificationBadge.staff),
        language: language,
      );
      expectOnCover(tester, ar: ar, width: 393);
      expect(find.byKey(ProfileCoverHeader.staffCoverKey), findsOneWidget);
      final id = tester.widget<Text>(find.byKey(ProfileCoverHeader.staffIdKey));
      // D299e (owner: «كلها لـ @»): «@Kabso01», isolated left to right.
      expect(id.data, ar ? '\u200e@Kabso01\u200e' : '@Kabso01');
      expect(id.textDirection, TextDirection.ltr);
      expect(id.style!.shadows, ProfileCoverBar.coverShadow);
      // The top shade under the bar: deeper for a busy cover (D299e).
      final shade = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.coverTopShadeKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        ((shade.decoration as BoxDecoration).gradient! as LinearGradient)
            .colors
            .first,
        KPublicProfile.topShade,
      );
      expect(id.style!.color, KPalette.dark.textPrimary);
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

    testWidgets('live: «مباشر» on the cover above the name block, never on '
        'it (${language.name})', (tester) async {
      await atNow(() async {
        await pumpOther(tester, d279Other(ar: ar), language: language);
        expectOnCover(tester, ar: ar, width: 393);
        final pill = _r(tester, ProfileLivePill.pillKey);
        final area = _r(tester, ProfileCoverHeader.coverAreaKey);
        final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
        final bar = tester.getRect(find.byType(AppBar));
        expect(pill.top, greaterThanOrEqualTo(bar.bottom));
        expect(pill.bottom, lessThanOrEqualTo(nameRow.top));
        expect(pill.bottom, lessThanOrEqualTo(area.bottom));
        // At the reading end, 16 dp in.
        if (ar) {
          expect(pill.left, moreOrLessEquals(KProfile.inset, epsilon: 0.5));
        } else {
          expect(
            pill.right,
            moreOrLessEquals(393 - KProfile.inset, epsilon: 0.5),
          );
        }
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
      expect(name.height, lessThan(KPublicProfile.nameFont * 1.3 * 2));
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
      // The long @username is cut, clear of back and ⋯.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
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
      expect(find.textContaining('@host0'), findsOneWidget);
    });
  }

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;

    /// tags → bio → links → the bond tiles, each just under the one before.
    void expectOrder(
      WidgetTester tester, {
      required bool bio,
      required bool links,
    }) {
      expect(tester.takeException(), isNull);
      final tags = tester.getRect(find.byKey(ProfileTagChips.wrapKey));
      final bioF = find.byKey(ProfileCoverHeader.bioKey);
      final linksF = find.byKey(ProfileCoverHeader.linksKey);
      expect(bioF, bio ? findsOneWidget : findsNothing);
      expect(linksF, links ? findsOneWidget : findsNothing);
      var above = tags.bottom;
      if (bio) {
        final r = tester.getRect(bioF);
        expect(r.top - above, moreOrLessEquals(KSpacing.md, epsilon: 0.5));
        above = r.bottom;
        // At the reading start.
        if (ar) {
          expect(
            r.right,
            moreOrLessEquals(
              tester.view.physicalSize.width / tester.view.devicePixelRatio -
                  KProfile.inset,
              epsilon: 0.5,
            ),
          );
        } else {
          expect(r.left, moreOrLessEquals(KProfile.inset, epsilon: 0.5));
        }
      }
      if (links) {
        final r = tester.getRect(linksF);
        expect(r.top, greaterThanOrEqualTo(above));
        expect(r.top - above, lessThanOrEqualTo(KSpacing.xs + 0.5));
        above = r.bottom;
      }
      // The bond tiles right after (no empty band).
      final tiles = tester.getRect(find.byType(ProfileInfoBlock));
      expect(tiles.top, greaterThanOrEqualTo(above));
      expect(tiles.top - above, lessThanOrEqualTo(KSpacing.md));
      // The bio is never repeated under the header.
      expect(
        find.descendant(
          of: find.byType(ProfileInfoBlock),
          matching: find.textContaining(ar ? 'موسيقى' : 'Arabic music'),
        ),
        findsNothing,
      );
    }

    testWidgets('D299c the bio under the tags, the link under the bio '
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
      expect(r.left, greaterThanOrEqualTo(KProfile.inset - 0.5));
      expect(r.right, lessThanOrEqualTo(360 - KProfile.inset + 0.5));
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
          '$scale: 16 dp bold (scale capped at 1.15), centred, cut with «…», '
          'clear of back and ⋯ (${language.name})', (tester) async {
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
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(ProfileCoverHeader.handleKey),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isTrue);
        // Centred in the bar (equal margins), clear of the buttons.
        final title = tester.getRect(find.byKey(ProfileCoverBar.titleKey));
        expect(title.center.dx, moreOrLessEquals(width / 2, epsilon: 1));
        final handle = _r(tester, ProfileCoverHeader.handleKey);
        for (final b in [
          tester.getRect(find.byType(BackButton)),
          _r(tester, PublicProfileScreen.moreKey),
        ]) {
          expect(handle.overlaps(b), isFalse);
        }
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
