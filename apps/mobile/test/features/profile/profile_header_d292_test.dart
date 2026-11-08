// D292 (owner, on the profile header: «الأيقونة في الملف الشخصي بجانب الاسم
// صغيرة جداً» / «الميدالية حجمها صغير، بالإضافة أن الميداليات تكون تحت
// الاسم. واليوزر يمكن رفعه في الأعلى بالمنتصف»):
//
// - the square crests in the name row (agent, host-agent, daily recharge)
//   at KPublicProfile.nameBadge, centred on the name's line;
// - the worn medals on their own row right under the name line, larger, in
//   the user's order, opening the medals; none (and no gap) when none are
//   worn; never twice (not in the block under the cover any more);
// - the @username under the name row as before (moved to the bar and back,
//   owner: «ارجع اليوزر أسفل الاسم»), the medals under it;
// - the top bar: back then the page's buttons side by side at the reading
//   start, plain glyphs (no circles).
//
// D299 (owner: «ضع الصورة الشخصية فوق الغلاف، وبجانبها الاسم والشارات»;
// then «اجعل اليوزر محل الميداليات … والميداليات محل اليوزر»): the badges
// on their own line(s) under the name, the crests centred on their line;
// the medals under the badges on the cover; the @username under the cover.
//
// Arabic RTL and English LTR; 360 × 800 at text scale 1.3.

import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_badge_wrap.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/profile_tag_icons.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';
import 'profile_cover_d278_test.dart' show otherProfile, pumpOther, pumpOwn;

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

/// Every badge of the name row: VIP, Kabso Team, recharge agent, host
/// agent, the daily recharge badge and the levels; and three worn medals.
PublicProfile _full({required bool ar, bool self = false}) =>
    otherProfile(ar: ar, self: self).copyWith(
      kabsoTeam: true,
      rechargeAgentCode: 'coin0001',
      rechargeBadge: RechargeBadge(
        tier: 4,
        until: clock.now().toUtc().add(const Duration(hours: 2)),
      ),
      medals: _worn,
    );

Rect _r(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

/// D299: the rects of the badges shown under the name.
List<Rect> _badgeRects(WidgetTester tester) {
  final wrap = tester.renderObject<RenderProfileBadgeWrap>(
    find.byKey(ProfileCoverHeader.badgesKey),
  );
  final out = <Rect>[];
  var child = wrap.firstChild;
  while (child != null) {
    final data = child.parentData! as ProfileBadgeWrapParentData;
    if (!data.hidden) {
      out.add(
        MatrixUtils.transformRect(
          child.getTransformTo(null),
          Offset.zero & child.size,
        ),
      );
    }
    child = data.nextSibling;
  }
  return out;
}

/// Disposes the daily badge's timer.
Future<void> _end(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  setUpAll(loadAppFonts);

  test('D292 tag icons: the wire keys parse to their kinds; a flag keeps its '
      'country; anything unknown is none', () {
    for (final kind in ProfileTagIconKind.values) {
      if (kind == ProfileTagIconKind.flag) continue;
      expect(ProfileTagIcon.parse(kind.wire).kind, kind);
      expect(ProfileTagIcon.parse(kind.wire).wire, kind.wire);
    }
    final flag = ProfileTagIcon.parse('flag:sa');
    expect(flag.kind, ProfileTagIconKind.flag);
    expect(flag.country, 'SA');
    expect(flag.wire, 'flag:SA');
    for (final bad in [null, 'flag', 'flag:ZZ', 'rocket', 'Crown']) {
      expect(ProfileTagIcon.parse(bad), ProfileTagIcon.none, reason: bad);
    }
    // One per tag; an older server's missing icons are none.
    expect(ProfileTagIcon.listFor(['a', 'b'], ['star']), [
      const ProfileTagIcon(ProfileTagIconKind.star),
      ProfileTagIcon.none,
    ]);
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;

    testWidgets('the name row: the crests at one visible size, centred on '
        'their line under the name (${language.name})', (tester) async {
      await pumpOther(tester, _full(ar: ar), language: language);
      final name = _r(tester, const Key('profile.displayName'));
      final line = _r(tester, ProfileCoverHeader.nameLineKey);
      final badges = _badgeRects(tester);
      for (final (key, height) in [
        (
          ProfileHeaderView.agentBadgeKey,
          KPublicProfile.rechargeAgentNameBadge,
        ),
        (
          ProfileHeaderView.hostAgentBadgeKey,
          KPublicProfile.hostAgentNameBadge,
        ),
        (ProfileHeaderView.rechargeBadgeKey, KPublicProfile.nameBadge),
      ]) {
        final r = _r(tester, key);
        expect(r.height, height, reason: '$key');
        // D299: under the name line, centred on the badges' line it is on.
        expect(r.top, greaterThanOrEqualTo(line.bottom), reason: '$key');
        final run = badges.where((b) => b.top < r.bottom && b.bottom > r.top);
        final top = run.map((b) => b.top).reduce(math.min);
        final bottom = run.map((b) => b.bottom).reduce(math.max);
        expect(
          r.center.dy,
          moreOrLessEquals((top + bottom) / 2, epsilon: 1),
          reason: '$key',
        );
      }
      // The host-agent and daily badges are square.
      for (final key in [
        ProfileHeaderView.hostAgentBadgeKey,
        ProfileHeaderView.rechargeBadgeKey,
      ]) {
        final r = _r(tester, key);
        expect(r.width, moreOrLessEquals(r.height));
      }
      // Larger than before (18); at most a hair taller than the name's
      // line, so the row does not grow by more than that.
      for (final h in [
        KPublicProfile.nameBadge,
        KPublicProfile.hostAgentNameBadge,
        KPublicProfile.rechargeAgentNameBadge,
      ]) {
        expect(h, greaterThan(18));
        expect(h, lessThanOrEqualTo(name.height + 2));
      }
      // D292b: the same visible weight — √(opaque share × width ÷ height)
      // × height within 3 % of the daily badge's (factors measured on the
      // art, see KPublicProfile.nameBadge).
      const daily = 0.79 * KPublicProfile.nameBadge;
      expect(
        0.735 * KPublicProfile.hostAgentNameBadge / daily,
        moreOrLessEquals(1, epsilon: 0.03),
      );
      expect(
        0.844 * KPublicProfile.rechargeAgentNameBadge / daily,
        moreOrLessEquals(1, epsilon: 0.03),
      );
      await _end(tester);
    });

    testWidgets('the worn medals: their own row under the name row, '
        'larger, in order, a button; once (${language.name})', (tester) async {
      await pumpOther(tester, _full(ar: ar), language: language);
      final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
      final row = _r(tester, ProfileCoverHeader.medalsKey);
      final stats = _r(tester, ProfileScreen.statsKey);
      final handle = _r(tester, ProfileCoverHeader.handleKey);
      // D299b: the medals right under the name row (on the cover); D299d:
      // the @username at the top (in the bar); the numbers under the cover.
      expect(row.top, greaterThanOrEqualTo(nameRow.bottom));
      expect(row.top - nameRow.bottom, lessThanOrEqualTo(8));
      expect(handle.bottom, lessThanOrEqualTo(nameRow.top));
      expect(stats.top, greaterThanOrEqualTo(row.bottom));
      // Exactly one showcase on the page (none in the block under the
      // cover).
      expect(find.byKey(MedalShowcaseRow.rowKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.medalsKey),
          matching: find.byKey(MedalShowcaseRow.rowKey),
        ),
        findsOneWidget,
      );
      final icons = [
        for (final m in _worn.showcase)
          _r(tester, MedalShowcaseRow.medalKey(m.code)),
      ];
      for (final i in icons) {
        expect(i.height, KPublicProfile.medal);
      }
      expect(KPublicProfile.medal, greaterThan(26));
      // The user's order, from the reading start.
      for (var i = 1; i < icons.length; i++) {
        if (ar) {
          expect(icons[i].right, lessThanOrEqualTo(icons[i - 1].left));
        } else {
          expect(icons[i].left, greaterThanOrEqualTo(icons[i - 1].right));
        }
      }
      // At the reading start, like the name.
      final name = _r(tester, const Key('profile.displayName'));
      if (ar) {
        expect(icons.first.right, moreOrLessEquals(name.right, epsilon: 1));
      } else {
        expect(icons.first.left, moreOrLessEquals(name.left, epsilon: 1));
      }
      // The current-level art, no number on it (D291).
      final icon = tester.widget<MedalIcon>(
        find.byKey(MedalShowcaseRow.medalKey('WEALTH_KINGS')),
      );
      expect(icon.iconAsset, 'medal_wealth_l3');
      // A button that opens the person's medals (as before, D291).
      final semantics = tester.widget<Semantics>(
        find.byKey(MedalShowcaseRow.rowKey),
      );
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.onTap, isNotNull);
      await _end(tester);
    });

    testWidgets('no medal worn: no medals row and no gap '
        '(${language.name})', (tester) async {
      await pumpOther(tester, otherProfile(ar: ar), language: language);
      expect(find.byKey(ProfileCoverHeader.medalsKey), findsNothing);
      expect(find.byKey(MedalShowcaseRow.rowKey), findsNothing);
      final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
      final stats = _r(tester, ProfileScreen.statsKey);
      // The name row, then the numbers (D299d: the @username at the top).
      final handle = _r(tester, ProfileCoverHeader.handleKey);
      expect(handle.bottom, lessThanOrEqualTo(nameRow.top));
      expect(stats.top, greaterThanOrEqualTo(nameRow.bottom));
    });

    testWidgets('the own profile: the medals under the name, the @username '
        'at the top (${language.name})', (tester) async {
      await pumpOwn(
        tester,
        language: language,
        stats: _full(ar: ar, self: true),
      );
      final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
      final row = _r(tester, ProfileCoverHeader.medalsKey);
      expect(row.top, greaterThanOrEqualTo(nameRow.bottom));
      expect(find.byKey(MedalShowcaseRow.rowKey), findsOneWidget);
      final handle = _r(tester, ProfileCoverHeader.handleKey);
      expect(handle.bottom, lessThanOrEqualTo(nameRow.top));
      await _end(tester);
    });

    testWidgets('360 × 800 at text scale 1.3, every badge: the name row '
        'wraps cleanly, a long @username on one line; back and the dots side '
        'by side at the reading start '
        '(${language.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpOther(
        tester,
        _full(ar: ar).copyWith(username: 'a_really_long_username_2026_x'),
        language: language,
        viewport: GoldenViewport.android,
      );
      expect(tester.takeException(), isNull);
      final nameRow = _r(tester, ProfileCoverHeader.nameRowKey);
      expect(nameRow.left, greaterThanOrEqualTo(0));
      expect(nameRow.right, lessThanOrEqualTo(360));
      for (final key in [
        ProfileHeaderView.agentBadgeKey,
        ProfileHeaderView.hostAgentBadgeKey,
        ProfileHeaderView.rechargeBadgeKey,
        ProfileCoverHeader.levelsKey,
      ]) {
        final r = _r(tester, key);
        expect(r.left, greaterThanOrEqualTo(0), reason: '$key');
        expect(r.right, lessThanOrEqualTo(360), reason: '$key');
        expect(r.top, greaterThanOrEqualTo(nameRow.top), reason: '$key');
        expect(r.bottom, lessThanOrEqualTo(nameRow.bottom), reason: '$key');
      }
      final handle = _r(tester, ProfileCoverHeader.handleKey);
      final medals = _r(tester, ProfileCoverHeader.medalsKey);
      expect(medals.top, greaterThanOrEqualTo(nameRow.bottom));
      expect(medals.left, greaterThanOrEqualTo(0));
      expect(medals.right, lessThanOrEqualTo(360));
      // D299d: the @username at the top, clear of back and the dots.
      expect(handle.bottom, lessThanOrEqualTo(nameRow.top));
      expect(handle.left, greaterThanOrEqualTo(0));
      expect(handle.right, lessThanOrEqualTo(360));
      final back = tester.getRect(find.byType(BackButton));
      final more = _r(tester, PublicProfileScreen.moreKey);
      if (ar) {
        expect(back.right, greaterThan(360 - 16));
        expect(more.right, lessThanOrEqualTo(back.left + 4));
      } else {
        expect(back.left, lessThan(16));
        expect(more.left, greaterThanOrEqualTo(back.right - 4));
      }
      expect(handle.overlaps(back), isFalse);
      expect(handle.overlaps(more), isFalse);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ProfileCoverHeader.handleKey),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      await _end(tester);
    });
  }

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets('D292 tag chips: small hollow pills on one line, the chosen '
        'icon first, none for default, the icon named for screen readers '
        '(${language.name})', (tester) async {
      await pumpOther(tester, otherProfile(ar: ar), language: language);
      final l10n = l10nFor(language);
      Finder iconIn(int i) => find.descendant(
        of: find.byKey(ProfileTagChips.chipKey(i)),
        matching: find.byType(ProfileTagIconView),
      );
      // The sample: crown, flag:SA, fire, trophy, mic, gamepad, default…
      expect(
        tester.widget<ProfileTagIconView>(iconIn(0)).icon.kind,
        ProfileTagIconKind.crown,
      );
      expect(tester.widget<ProfileTagIconView>(iconIn(1)).icon.country, 'SA');
      final chip = tester.getRect(find.byKey(ProfileTagChips.chipKey(0)));
      // Small: about 24 dp tall; the icon 14 dp.
      expect(chip.height, inInclusiveRange(22, 27));
      final icon = tester.getRect(iconIn(0));
      expect(icon.height, ProfileTagChips.iconSize);
      // At the reading start of the pill.
      if (ar) {
        expect(icon.right, greaterThan(chip.center.dx));
      } else {
        expect(icon.left, lessThan(chip.center.dx));
      }
      final shownChips = find.descendant(
        of: find.byKey(ProfileTagChips.wrapKey),
        matching: find.byType(ProfileTagIconView),
      );
      expect(shownChips, findsWidgets);
      if (find.byKey(ProfileTagChips.chipKey(6)).evaluate().isNotEmpty) {
        expect(iconIn(6), findsNothing);
      }
      expect(
        tester.getSemantics(find.byKey(ProfileTagChips.chipKey(0))).label,
        contains(l10n.profileTagIconCrown),
      );
      // One line (owner: «بصف واحد»), the rest as «+n».
      final tops = {
        for (var i = 0; i < 10; i++)
          if (find.byKey(ProfileTagChips.chipKey(i)).evaluate().isNotEmpty)
            tester.getRect(find.byKey(ProfileTagChips.chipKey(i))).top.round(),
      };
      expect(tops.length, lessThanOrEqualTo(ProfileTagChips.maxLines));
      expect(find.byKey(ProfileTagChips.moreKey), findsOneWidget);
    });
  }
}
