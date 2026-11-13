// D218: the profile header shared by the public profile and (owner:
// «وحدهما») the own profile.
//
// D335 (owner, with a third-party reference — the right phone of a Dribbble
// composite, kept out of git (D40) — «أريده مطابق»): EVERY profile (the own
// «أنا» page, visitors, staff and the founder) has the same header — a
// full-bleed cover under the status bar and the top bar (the person's cover
// picture, the founder's video (D307), a staff region cover (D283), else the
// default Kabso cover [ProfileDefaultCover]) with rounded bottom corners;
// the bar's buttons on translucent circles (back with the @username /
// special-ID plate / staff ID beside it at the reading start, ⋯ or the own
// page's buttons at the end); the photo (a Kabso-red gradient ring) at the
// reading start over the cover's bottom edge, with the verification seal on
// its corner (D293; none for others); under it, start-aligned, the name with
// its seal, the levels and badges, the worn medals, the bio, the tags and
// the links; the numbers (Followers | Following | cherries | coins — the
// money ones hidden per D307) with dividers; the buttons («متابعة» in a
// Kabso-red gradient, «مراسلة» with the send icon, or «تعديل الملف», and a
// chevron that opens the family / couple / medals tiles). Supersedes D316's
// centred, cover-less header and D299 / D307's name-on-the-cover layouts.
// Every size is measured on the reference at 1.333 px/dp (M) or estimated
// (E): docs/contracts/CONVENTIONS.md §10.73.7.
//
// D357 (owner, 2026-11-10, the FOUNDER's page only — CONVENTIONS §10.153):
// the same cover (his video), but the photo CENTRED over the cover's edge,
// the name centred under it in Kabso red, his [FounderBadge] (the D293
// seal in Kabso red with a white play triangle) centred under the name in
// place of the blue seal, the bio centred, and only two numbers —
// «المتابعون» and «الاقتراحات والشكاوى» (`PublicProfile.founderFeedbackCount`,
// v1.118-social). Every other profile keeps the D335 layout above.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/presentation/ambassador_badge.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_badge.dart';
import 'package:kabso_live/features/owner_profile/presentation/founder_socials.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_badge_wrap.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_default_cover.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_live_pill.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/profile_tag_icons.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/staff/presentation/staff_covers.dart';
import 'package:kabso_live/features/staff/presentation/staff_official_bio.dart';
import 'package:kabso_live/features/status/status_catalogue.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// How the cover's picture is loaded; tests swap in a [MemoryImage].
@visibleForTesting
ImageProvider Function(String src) profileCoverImageFor = NetworkImage.new;

/// D335: builds the header's button row; [bondsToggle] is the chevron that
/// opens the family / couple / medals tiles (null when there are none to
/// show), placed after the row's last button.
typedef ProfileActionsBuilder = Widget Function(
  BuildContext context,
  Widget? bondsToggle,
);

/// The profile header's geometry.
///
/// D335: measured on the owner's reference at 1.333 px per dp (its phone is
/// 524 px wide for 393 dp): «M» is measured from pixels (± 1 dp), «E» an
/// estimate (type sizes from glyph metrics, radii, translucency).
abstract final class KPublicProfile {
  /// D244: the box every FRAMED profile photo is drawn in (a worn frame, the
  /// live ring, an agent or staff frame): the frames' common box
  /// (`AvatarFrameBox.aroundAvatar`), the real extent of the largest frame.
  static final AvatarFrameBox avatarSlot = AvatarFrameBox.aroundAvatar(
    KProfile.avatar,
  );

  /// D307 follow-up: the top bar turns solid once the list has moved this
  /// far (kept by D335: the bar never lets anything slide under it).
  static const double avatarTopGap = KSpacing.xs;

  /// D335: the cover runs from the screen's top to this far under the top
  /// bar (M: its bottom edge 288 dp from the top, the bar's bottom ≈ 104).
  static const double coverBelowBar = 184;

  /// The cover's height under a top bar ending [barBottom] from the
  /// screen's top (≈ 309 dp on a 393 × 852 phone with a 59 dp status bar).
  static double coverHeightFor(double barBottom) =>
      (barBottom + coverBelowBar).roundToDouble();

  /// D335: the cover's rounded bottom corners (E: the page shows ≈ 16 dp
  /// up the screen's edges).
  static const double coverRadius = 18;

  /// D335: the plain photo (M ≈ 100), its Kabso-red gradient ring (M ≈ 4.5)
  /// and the page-coloured rim around it (M ≈ 3): 114 dp in all (M ≈ 115).
  static const double photo = 100;
  static const double photoRing = 4;
  static const double photoRim = 3;
  static const double avatarOuter = photo + 2 * (photoRing + photoRim);

  /// D335: from the screen's reading-start edge to the ringed photo (M 16.5).
  static const double avatarStart = 16;

  /// D335: the photo's centre this far above the cover's bottom edge (M 38):
  /// two thirds on the cover, [avatarOverhang] on the page.
  static const double avatarLift = 38;
  static const double avatarOverhang = avatarOuter / 2 - avatarLift;

  /// D376 «الحالة»: how high the status bubbles rise over the photo (the
  /// cover above it is their room; owner's pack: radius-relative, 1 = full).
  static const double statusRise = 0.85;

  /// D335 (owner: «الشارة على الصورة = علامة التوثيق»): the verification
  /// seal on the photo's corner (E ≈ 26) with a page-coloured rim (E ≈ 3),
  /// its centre on the ringed photo's edge at 45° toward the bottom end (M).
  static const double avatarBadge = 26;
  static const double avatarBadgeRim = 3;

  /// D335: the top bar's buttons — a 46 dp translucent circle (M 46.5; a
  /// 48 dp target) whose edge is 18 dp from the screen's edge (M 17.6).
  static const double barCircle = 46;
  static const double barTarget = KSizes.minTouchTarget;
  static const double barInset = 17;
  static const Color barCircleFill = Color(0x33FFFFFF);
  static const double barIcon = 22;

  /// The bar's @username (D299f): 16 dp bold, its scale capped at 1.15.
  static const double barTitleFont = 16;
  static const double barTitleMaxScale = 1.15;
  static const double barTitleMinWidth = 140;

  /// D335: the side margin of everything under the cover (M ≈ 20).
  static const double inset = 20;

  /// D335: the photo's bottom → the name line (M ≈ 9) and the name (E ≈ 22,
  /// bold), the seal 6 dp after it (E).
  static const double nameGap = 9;
  static const double nameFont = 22;
  static const double sealGap = 6;

  /// D335: the seal after the name (M ≈ 18 dp of visible rosette).
  static const double nameSeal = 20;

  /// The badges (VIP, Kabso Team, crests, levels) under the name — the
  /// reference's subtitle line (owner 4) — on at most two lines.
  static const int badgeLines = 2;

  /// D292: the heights of the square crests among the badges (the same
  /// visible weight: √opaque area ÷ height measured on each art file).
  static const double nameBadge = 26;
  static const double hostAgentNameBadge = 28;
  static const double rechargeAgentNameBadge = 24;

  /// D335 follow-up (owner, on a staff capture: «اجعل الأيقونة (فريق كابسو)
  /// بجانب الاسم»): a staff account's «فريق كابسو» badge on the name line,
  /// after the seal, as tall as that line (E).
  static const double teamBadgeInline = 26;

  /// D335 (owner 4): the worn medals under the badges, the art alone, 28 dp
  /// in a 44 dp tap row (D316's target), 6 dp apart.
  static const double medal = 28;
  static const double medalTap = 44;

  /// D335: the bio (M ink 13.5 dp, pitch 19.5 dp → E 14 dp × 1.4), two
  /// lines (the founder's four, v1.98-social), 5 dp under the badges.
  static const double bioFont = 14;
  static const double bioHeight = 1.4;
  static const double bioGap = 5;
  static const int bioLines = 2;
  static const int ownerBioLines = 4;

  /// At most this many tags (`PublicProfile.tags`, §10.99).
  static const int maxTags = 10;

  /// D335: the numbers (M cap height 20 dp → E 26 dp bold, a little under
  /// the reference's so four fit a phone), their labels (M ink 15.8 → E
  /// 15 dp), a column (M ≈ 163 dp when two) and the line between two (M 41
  /// dp tall).
  static const double statsGap = 22.5;
  static const double statNumber = 26;
  static const double statLabel = 15;

  /// D335 (owner 4): with the money numbers there are four columns — the
  /// numbers smaller and the labels on up to two lines.
  static const double statNumberDense = 21;
  static const double statLabelDense = 13;
  static const double statColumn = 163;
  static const double statDivider = 41;

  /// D335: the pill buttons (M 41 dp tall, 12 dp apart; M 18.5 dp under
  /// the labels' ink).
  static const double actionsGap = 18.5;
  static const double buttonHeight = 41;
  static const double buttonGap = 12;

  /// D335 (owner 4): the family / couple / medals tiles under the buttons,
  /// opened by the chevron (animated; not remembered).
  static const double bondsGap = KSpacing.md;

  /// D335: under the buttons (or the open tiles), before the tabs.
  static const double bottomGap = 8;
  static const Duration bondsMotion = Duration(milliseconds: 240);

  /// D335 (owner 3): the Kabso-red gradient of «متابعة», the photo's ring
  /// and the selected tab's line (the reference's pink → orange replaced).
  static const List<Color> gradient = [
    KBrandColors.red500,
    KBrandColors.red400,
  ];

  /// D299e: the shade under the bar (black 50 % at the top, clear at 40 %
  /// of the cover) so the white @username reads over a bright cover.
  static const double topShadeShare = 0.4;
  static const Color topShade = Color(0x80000000);

  static const double factIcon = 16;

  /// D357 (founder page only): the name under the centred photo (E 24 dp,
  /// bold, Kabso red), the bio 10 dp under it, centred.
  static const double founderNameFont = 24;
  static const double founderBioGap = 10;

  /// D357: the social row 12 dp under the bio.
  static const double founderSocialGap = KSpacing.md;

  /// D357 (owner: «بجانب اسم المؤسس ازل الشارة»): his red seal at the
  /// bottom centre of the photo — 0.28 of the photo's diameter (the owner's
  /// 0.26–0.30), never under 20 lp — on a [founderSealRing] ring, its
  /// centre [founderSealRise] of the badge above the photo's bottom rim, so
  /// it overlaps the rim and hangs [founderSealOverhang] below it.
  static const double founderSealShare = 0.28;
  static const double founderSealMin = 20;
  static const double founderSealRing = 2.5;
  static const double founderSealRise = 0.15;

  /// The seal (ring excluded) on a photo [diameter] across.
  static double founderSealFor(double diameter) =>
      math.max(founderSealMin, (diameter * founderSealShare).roundToDouble());

  /// The badge (ring included) on a photo [diameter] across.
  static double founderSealOuterFor(double diameter) =>
      founderSealFor(diameter) + 2 * founderSealRing;

  /// How far the badge hangs below the photo's bottom rim.
  static double founderSealOverhang(double diameter) =>
      founderSealOuterFor(diameter) * (0.5 - founderSealRise);
}

/// D335: the top bar of the profile pages over the full-bleed cover — back
/// (when the page was pushed) on a translucent circle with the @username
/// ([ProfileCoverHandle]) beside it at the reading start, and the page's
/// buttons (⋯, or the own page's drafts and settings) on circles at the
/// end. Clear over the cover; once the list has moved (D307), the page
/// colour, the theme's glyphs on the chip colour.
///
/// Used as the Scaffold's app bar with `extendBodyBehindAppBar`; the
/// scroll view starts with [ProfileCoverBarSpace] so that pinned headers
/// stop under the bar.
class ProfileCoverBar extends StatelessWidget implements PreferredSizeWidget {
  const new({
    required this.solid,
    required this.title,
    required this.actions,
    super.key,
  });

  /// The list has moved: the page colour.
  final bool solid;
  final Widget title;

  /// The buttons at the end, each drawn on a circle ([circle]).
  final List<Widget> actions;

  static const titleKey = Key('profile.bar.title');

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + KMetrics.statusBarGap);

  /// D335: a bar button's translucent circle (46 dp) in its 48 dp target;
  /// once solid, the chip colour.
  static Widget circle({
    required BuildContext context,
    required bool solid,
    required Widget child,
  }) => SizedBox.square(
    dimension: KPublicProfile.barTarget,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: KPublicProfile.barCircle,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: solid
                  ? ProfileCoverHeader.chipColor(context)
                  : KPublicProfile.barCircleFill,
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    ),
  );

  /// The soft shadow of the bar's text over the cover.
  static const List<Shadow> coverShadow = [
    Shadow(color: Color(0x8C000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = solid ? p.textPrimary : KPalette.dark.textPrimary;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The edge of the 48 dp target: the circle's edge [barInset] + 1 in.
    const edge = KPublicProfile.barInset - 1;
    return ActionIconTheme(
      data: ActionIconThemeData(
        // D292: the app's own back chevron, pointing to the reading start.
        backButtonIconBuilder: (_) => Transform.flip(
          flipX: rtl,
          child: AppIcon(
            AppIcons.back,
            size: KPublicProfile.barIcon,
            color: fg,
          ),
        ),
      ),
      child: KAppBar(
        backgroundColor: solid ? p.background : Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        // The status bar's icons: light over the cover, the theme's after.
        systemOverlayStyle: !solid || dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        leadingWidth: canPop ? edge + KPublicProfile.barTarget : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsetsDirectional.only(start: edge),
                child: Center(
                  child: circle(
                    context: context,
                    solid: solid,
                    child: BackButton(color: fg),
                  ),
                ),
              )
            : null,
        // D299d / D316: the @username (special-ID plate, staff ID) right
        // beside back, at the reading start.
        title: KeyedSubtree(key: titleKey, child: title),
        titleSpacing: canPop ? KSpacing.xs : KPublicProfile.inset,
        actions: [
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: KSpacing.xxs),
            Center(
              child: circle(context: context, solid: solid, child: action),
            ),
          ],
          if (actions.isNotEmpty) const SizedBox(width: edge),
        ],
      ),
    );
  }
}

/// D299d: the @username at the top of the profile pages — the
/// [ProfileCoverBar]'s title, beside back (D316 / D335). Over the cover
/// white with the bar's soft shadow; once the bar is solid, the theme's
/// text colour. A premium username wears its special-ID badge (D146, shrunk
/// to fit); a staff account shows its official staff ID (D283c / D299h). A
/// long one is cut with «…» (or shrinks), never under the buttons.
class ProfileCoverHandle extends StatelessWidget {
  const new({
    required this.solid,
    required this.username,
    super.key,
    this.tier,
    this.staffId,
    this.textKey,
  });

  final bool solid;
  final String username;
  final PremiumTier? tier;
  final String? staffId;

  /// The key of the plain @username (or the premium badge).
  final Key? textKey;

  /// The premium badge's height in the bar.
  static const double badgeHeight = 24;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    // D299f: 16 dp bold, the text scale capped at 1.15.
    final style = context.textStyles.title.copyWith(
      fontSize: KPublicProfile.barTitleFont,
      fontWeight: FontWeight.w700,
      color: solid ? p.textPrimary : KPalette.dark.textPrimary,
      shadows: solid ? null : ProfileCoverBar.coverShadow,
    );
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KPublicProfile.barTitleMaxScale);
    return KeyedSubtree(
      key: ProfileCoverHeader.handleKey,
      child: switch (tier) {
        // D299h: the official staff ID as the gold special-ID pill.
        _ when staffId != null => KStaffIdText(
          staffId!,
          key: ProfileCoverHeader.staffIdKey,
          height: KStaffIdText.bar,
          semanticHint: l10n.profileStaffIdHint,
          // D299l: the tier's full motion in the profile bar.
          effects: KSpecialIdEffects.full,
        ),
        final tier? => Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: KSpecialUsername(
              key: textKey,
              username: username,
              tier: tier,
              height: badgeHeight,
              effects: KSpecialIdEffects.full,
            ),
          ),
        ),
        null => Text(
          l10n.profileUsername(username),
          key: textKey,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: scaler,
          style: style,
        ),
      },
    );
  }
}

/// D278 / D307 follow-up: whether the list has moved — the bar then turns
/// solid (before anything can pass under it).
bool profileCoverScrolledAway(BuildContext context, ScrollMetrics metrics) =>
    metrics.axis == Axis.vertical &&
    metrics.pixels > KPublicProfile.avatarTopGap;

/// D278: the space of the top bar over the scroll view — it takes no room
/// (the cover runs under the bar) but pinned headers (the tabs) stop under
/// it. Put it first in the scroll view; its height is the body's top
/// padding (the bar and the status bar, `extendBodyBehindAppBar`).
class ProfileCoverBarSpace extends LeafRenderObjectWidget {
  const new({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderProfileCoverBarSpace(MediaQuery.paddingOf(context).top);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProfileCoverBarSpace renderObject,
  ) {
    renderObject.extent = MediaQuery.paddingOf(context).top;
  }
}

/// The render object of [ProfileCoverBarSpace].
class RenderProfileCoverBarSpace extends RenderSliver {
  new(this._extent);

  double _extent;
  double get extent => _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final paint = math.min(_extent, constraints.remainingPaintExtent);
    // No scroll extent, no layout extent: what follows starts at the top
    // (under the bar); the paint extent is the overlap the pinned headers
    // after it stop under.
    geometry = SliverGeometry(
      paintExtent: paint,
      layoutExtent: 0,
      maxPaintExtent: paint,
      hasVisualOverflow: true,
    );
  }
}

/// D335: the profile header of every profile — the cover, the ringed photo
/// over its bottom edge at the reading start, then the name block, the
/// medals, the bio, the tags, the links, the numbers, the buttons
/// ([actions]) and the family / couple / medals tiles behind the chevron.
/// The own profile passes [onCoverTap] (change the cover).
class ProfileCoverHeader extends ConsumerStatefulWidget {
  const new({
    required this.profile,
    required this.actions,
    super.key,
    this.onCoverTap,
    this.cpFrame,
    this.onOpenFollowers,
    this.onOpenFollowing,
    this.countsKnown = true,
    this.countsFailed = false,
    this.coverVideo,
  });

  final PublicProfile profile;

  /// v1.95-social (D301, §10.112.1): the app owner's cover video layer
  /// (with its own shade and controls), over the cover picture.
  final Widget? coverVideo;

  /// The button row: «متابعة» / «مراسلة», or «تعديل الملف» — with the
  /// bonds chevron the header hands it.
  final ProfileActionsBuilder actions;

  /// The own profile: a tap on the cover opens «صورة الغلاف» (choose, take,
  /// remove).
  final VoidCallback? onCoverTap;

  /// Whether the photo wears the CP heart frame; default: the couple's
  /// privilege (others see it). D168: the own page shows the plain photo.
  final bool? cpFrame;

  final VoidCallback? onOpenFollowers;
  final VoidCallback? onOpenFollowing;

  /// The own profile while `GET /users/{me}` loads: the counts show a
  /// skeleton, never a made-up 0.
  final bool countsKnown;

  /// The counts could not be read: a dash, never a made-up number (pull to
  /// refresh retries).
  final bool countsFailed;

  static const headerKey = Key('profile.cover.header');
  static const coverAreaKey = Key('profile.cover.area');
  static const coverKey = Key('profile.public.cover');

  /// D335: the default Kabso cover ([ProfileDefaultCover]) of a profile
  /// without a cover of its own.
  static const coverFallbackKey = Key('profile.public.cover.gradient');
  static const coverButtonKey = Key('profile.cover.tap');
  static const watchLiveKey = Key('profile.public.watchLive');
  static const handleKey = Key('profile.cover.handle');

  /// D299e: the shade at the cover's top, under the bar.
  static const coverTopShadeKey = Key('profile.cover.topShade');

  /// D335: the ringed photo (or the frame's box) over the cover's edge.
  static const photoKey = Key('profile.cover.photo');

  /// D335: the verification seal on the photo's corner.
  static const avatarBadgeKey = Key('profile.cover.avatarBadge');

  /// The name block under the photo — «مباشر», the name and its seal, the
  /// badges.
  static const identityKey = Key('profile.cover.identity');

  /// The name and the verification seal after it, on one line.
  static const nameLineKey = Key('profile.cover.nameLine');

  /// The badges under the name (at most two lines).
  static const badgesKey = Key('profile.cover.badges');

  /// D283c: the staff ID in the bar.
  static const staffIdKey = Key('profile.cover.staffId');
  static const levelsKey = Key('profile.public.levels');

  /// D283: a staff profile's team cover.
  static const staffCoverKey = Key('profile.cover.staff');
  static const nameRowKey = Key('profile.cover.nameRow');

  /// The worn medals' row under the badges.
  static const medalsKey = Key('profile.cover.medals');
  static const actionsKey = Key('profile.cover.actions');
  static const linksKey = Key('profile.cover.links');
  static const bioKey = Key('profile.cover.bio');

  /// D335: everything under the cover, start-aligned.
  static const infoKey = Key('profile.cover.info');

  /// D335 (owner 4): the chevron beside «مراسلة» and the section it opens.
  static const bondsToggleKey = Key('profile.cover.bondsToggle');
  static const bondsKey = Key('profile.cover.bonds');

  static const cherriesKey = Key('profile.stat.cherries');
  static const coinsKey = Key('profile.stat.coins');

  /// D357: the founder page's second number, «الاقتراحات والشكاوى».
  static const founderFeedbackKey = Key('profile.stat.founderFeedback');

  /// D357: the founder's centred identity block (photo-centred layout).
  static const founderIdentityKey = Key('profile.cover.founderIdentity');

  /// D357: the founder's name colour — Kabso red (the brand token; the
  /// lighter red400 on dark for contrast: ≥ 4.5 : 1 on both pages).
  static Color founderNameColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? KBrandColors.red400
      : KBrandColors.red500;

  /// D316 / D335: the fill of the pill buttons, the chevron and (once the
  /// bar is solid) the bar's circles — the reference's ≈ #EEF2F5 on white
  /// is the light overlay grey; on dark, the surface.
  static Color chipColor(BuildContext context) {
    final p = context.palette;
    return Theme.of(context).brightness == Brightness.dark
        ? p.surface
        : p.surfaceOverlay;
  }

  /// D335 (owner 4): whether the chevron has anything to open — a staff
  /// account shows no family, couple or medals (D283); the founder's page
  /// only what he holds (D301 §10.112.6).
  static bool hasBonds(PublicProfile profile) =>
      profile.staff == null &&
      (!profile.kabsoOwner ||
          profile.family != null ||
          profile.cp != null ||
          profile.medals.owned > 0);

  @override
  ConsumerState<ProfileCoverHeader> createState() => _ProfileCoverHeaderState();
}

class _ProfileCoverHeaderState extends ConsumerState<ProfileCoverHeader> {
  /// D335: the bonds section is open (this visit only; never stored).
  bool _bondsOpen = false;

  PublicProfile get profile => widget.profile;

  /// The bio shown in the header (none for a Kabso Team account, D283b).
  /// v1.98-social (D307, §10.112.11): on the app owner's page, his bio in
  /// the app's language, else the app's default founder text in that
  /// language (never the other language's, never the one-language bio).
  String? _bioOf(BuildContext context) {
    if (profile.kabsoOwner) {
      final lang = Localizations.localeOf(context).languageCode;
      return profile.ownerBio?.pick(lang) ?? context.l10n.ownerBioDefault;
    }
    return switch (profile.bio) {
      final bio? when profile.staff == null && bio.trim().isNotEmpty => bio,
      _ => null,
    };
  }

  /// D335 follow-up (owner: «مشرف كابسو: اجعل الأيقونة (فريق كابسو) بجانب
  /// الاسم، وضع أسفلهم بعد ذلك صندوق البايو»): a staff account (D283) shows
  /// the team badge on the name line and its official bio card right under
  /// the name block, before the numbers.
  bool get _teamInline =>
      profile.staff != null && profile.kabsoTeam && !profile.kabsoOwner;

  /// D307 follow-up: the app owner or a Kabso Team account (a watch role,
  /// or a limited staff account) — no money numbers on the profile.
  bool get _teamOrFounder =>
      profile.kabsoOwner || profile.kabsoTeam || profile.staff != null;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final page = context.palette.background;
    // The page runs under the bar (`extendBodyBehindAppBar`), so its top
    // padding is the status bar and the bar.
    final coverHeight = KPublicProfile.coverHeightFor(media.padding.top);
    final photoCentre = coverHeight - KPublicProfile.avatarLift;
    final framed = _framed(context);
    final box = framed
        ? Size(
            KPublicProfile.avatarSlot.width,
            KPublicProfile.avatarSlot.height,
          )
        : const Size.square(KPublicProfile.avatarOuter);
    const centreX = KPublicProfile.avatarStart + KPublicProfile.avatarOuter / 2;
    final founder = profile.kabsoOwner;
    final photo = KeyedSubtree(
      key: ProfileCoverHeader.photoKey,
      child: _photo(context, framed: framed),
    );
    return Stack(
      key: ProfileCoverHeader.headerKey,
      children: [
        Positioned.fill(child: ColoredBox(color: page)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: coverHeight, child: _cover(context)),
            Padding(
              key: ProfileCoverHeader.infoKey,
              // D244: the name starts under the photo's box — a frame's
              // taller box pushes it down (never under the frame).
              padding: EdgeInsetsDirectional.fromSTEB(
                KPublicProfile.inset,
                box.height / 2 -
                    KPublicProfile.avatarLift +
                    KPublicProfile.nameGap +
                    (founder ? _founderSealClearance(framed: framed) : 0),
                KPublicProfile.inset,
                KPublicProfile.bottomGap,
              ),
              child: founder ? _founderInfo(context) : _info(context),
            ),
          ],
        ),
        // D357: the founder's photo centred over the cover's bottom edge.
        if (founder)
          Positioned(
            left: 0,
            right: 0,
            top: photoCentre - box.height / 2,
            height: box.height,
            child: Center(
              child: SizedBox.fromSize(size: box, child: photo),
            ),
          )
        else
          // The photo over the cover's bottom edge, at the reading start (a
          // frame's larger box keeps the same centre).
          PositionedDirectional(
            start: centreX - box.width / 2,
            top: photoCentre - box.height / 2,
            width: box.width,
            height: box.height,
            child: photo,
          ),
      ],
    );
  }

  /// D357: the room the founder's photo seal needs under the photo's box
  /// (a frame's taller box may already hold it).
  double _founderSealClearance({required bool framed}) {
    final diameter = framed ? KProfile.avatar : KPublicProfile.avatarOuter;
    final boxHalf = framed
        ? KPublicProfile.avatarSlot.height / 2
        : KPublicProfile.avatarOuter / 2;
    final below =
        diameter / 2 + KPublicProfile.founderSealOverhang(diameter) - boxHalf;
    return math.max(0, below);
  }

  /// The cover: the person's picture, a staff region's team cover (D283),
  /// else the default Kabso cover; the founder's video over it (D301); the
  /// shade under the bar; rounded bottom corners. The own page's cover is a
  /// button (change it).
  Widget _cover(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final staff = profile.staff;
    final onCoverTap = staff == null ? widget.onCoverTap : null;
    return ClipRRect(
      key: ProfileCoverHeader.coverAreaKey,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(KPublicProfile.coverRadius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // D335 (owner 1): never an empty cover — the default Kabso one.
          const ProfileDefaultCover(key: ProfileCoverHeader.coverFallbackKey),
          if (staff != null)
            Image(
              key: ProfileCoverHeader.staffCoverKey,
              image: AssetImage(StaffCovers.assetFor(staff.primaryRegion)),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          if (profile.coverUrl case final url? when staff == null)
            Image(
              key: ProfileCoverHeader.coverKey,
              image: profileCoverImageFor(url),
              fit: BoxFit.cover,
              semanticLabel: l10n.profileCoverOf(profile.displayName),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          // D378 (ANIMATED_COVER): the tier's cover art plays over the own
          // cover while the member holds the perk (the own cover is kept).
          if (staff == null && (profile.vip?.member ?? false))
            VipAnimatedCover(vip: profile.vip),
          // D299e: a shade under the status bar and the bar, so the white
          // @username reads over a bright cover.
          const Align(
            key: ProfileCoverHeader.coverTopShadeKey,
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: KPublicProfile.topShadeShare,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KPublicProfile.topShade, Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          // The own profile: the cover is a button (change it) — under the
          // status bar and the top buttons, never in them.
          if (onCoverTap case final tap?)
            Padding(
              padding: EdgeInsets.only(top: media.padding.top),
              child: Semantics(
                button: true,
                label: l10n.profileEditCover,
                excludeSemantics: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ProfileCoverHeader.coverButtonKey,
                    onTap: tap,
                  ),
                ),
              ),
            ),
          ?widget.coverVideo,
        ],
      ),
    );
  }

  /// The VIP frame shows only when no agent or bag frame is worn and the
  /// person is not live.
  UserVip? get _vip =>
      profile.liveRoomId == null &&
          profile.rechargeAgentCode == null &&
          profile.hostAgentCode == null &&
          profile.avatarFrame == null
      ? profile.vip
      : null;

  /// Whether the photo is drawn with a frame (D244 box) rather than the
  /// D335 gradient ring.
  bool _framed(BuildContext context) =>
      profile.liveRoomId != null ||
      profile.staff != null ||
      isTeamAvatarUrl(profile.avatarUrl) ||
      profile.rechargeAgentCode != null ||
      profile.hostAgentCode != null ||
      AvatarFrameArt.of(profile.avatarFrame) != null ||
      (widget.cpFrame ?? cpWearsSpecialFrame(profile.cp)) ||
      VipAvatarFrame.shows(ref, _vip);

  /// The photo: the plain photo in its Kabso-red gradient ring and page rim
  /// (D335), or a frame / the live ring / a staff frame in the frames' box
  /// (D244). While live, a tap opens the room. The verification seal on its
  /// corner (owner 2; read once, with the name).
  Widget _photo(BuildContext context, {required bool framed}) {
    final l10n = context.l10n;
    final room = profile.liveRoomId;
    final live = room != null;
    final page = context.palette.background;
    final Widget picture;
    if (profile.staff != null || isTeamAvatarUrl(profile.avatarUrl)) {
      // D283: the team picture in the locked team frame.
      picture = Center(
        child: KabsoTeamAvatar.boxed(
          box: math.min(
            KPublicProfile.avatarSlot.width,
            KPublicProfile.avatarSlot.height,
          ),
        ),
      );
    } else if (framed) {
      picture = Center(
        child: VipAvatarFrame(
          vip: _vip,
          size: KProfile.avatar,
          child: ProfileAvatar(
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            live: live,
            cpFrame: widget.cpFrame ?? cpWearsSpecialFrame(profile.cp),
            agentCode: profile.rechargeAgentCode,
            hostAgentCode: profile.hostAgentCode,
            avatarFrame: profile.avatarFrame,
          ),
        ),
      );
    } else {
      picture = DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: page),
        child: Padding(
          padding: const EdgeInsets.all(KPublicProfile.photoRim),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: KPublicProfile.gradient,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KPublicProfile.photoRing),
              child: KAvatar(
                name: profile.displayName,
                imageUrl: profile.avatarUrl,
                size: KPublicProfile.photo,
              ),
            ),
          ),
        ),
      );
    }
    // The seal's centre on the photo's edge at 45° toward the bottom end.
    final radius = framed
        ? KProfile.avatar / 2
        : KPublicProfile.avatarOuter / 2;
    const seal = KPublicProfile.avatarBadge + 2 * KPublicProfile.avatarBadgeRim;
    return Semantics(
      key: ProfileHeaderView.avatarKey,
      button: live,
      label: live ? l10n.profileWatchLive : null,
      // While live the photo is the way into the room (one label).
      excludeSemantics: live,
      child: GestureDetector(
        key: live ? ProfileCoverHeader.watchLiveKey : null,
        onTap: live ? () => context.push(AppRoutes.liveRoom(room)) : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final c = constraints.biggest.center(Offset.zero);
            final d = radius * math.sqrt1_2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: picture),
                // D376 «الحالة»: the status rising over the photo (never on
                // a Kabso Team account's fixed look).
                if (StatusCatalogue.byId(profile.statusEmojiId)
                    case final emoji?
                    when profile.staff == null &&
                        !isTeamAvatarUrl(profile.avatarUrl))
                  Positioned.fill(
                    child: StatusEmojiLayer(
                      emoji,
                      radius: radius,
                      riseFactor: KPublicProfile.statusRise,
                    ),
                  ),
                // D357: the founder's red seal at the photo's bottom centre,
                // over its rim (never beside his name), on a white / surface
                // ring that parts it from the photo and any frame.
                if (profile.kabsoOwner) _founderSeal(context, c, radius),
                // D357: the founder never wears the D293 seal.
                if (shownVerification(profile.verification) case final badge?
                    when !profile.kabsoOwner)
                  PositionedDirectional(
                    start: c.dx + d - seal / 2,
                    top: c.dy + d - seal / 2,
                    width: seal,
                    height: seal,
                    // The name's seal is the one read aloud.
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        key: ProfileCoverHeader.avatarBadgeKey,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: page,
                        ),
                        // D293's seal art (the same painter and check),
                        // drawn without the name seal's tooltip and label.
                        child: Center(
                          child: SizedBox.square(
                            dimension: KPublicProfile.avatarBadge,
                            child: CustomPaint(
                              painter: VerificationSealPainter(
                                fill: VerificationBadgeColors.sealOf(badge),
                                rim: VerificationBadgeColors.rimOf(badge),
                              ),
                              child: Center(
                                child: Icon(
                                  verificationBadgeIcon(badge),
                                  size:
                                      KPublicProfile.avatarBadge *
                                      verificationIconScale,
                                  color: VerificationBadgeColors.inkOf(badge),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// D357: the founder's photo seal, centred on the photo of [radius]
  /// around [c], its centre a little above the bottom rim.
  Widget _founderSeal(BuildContext context, Offset c, double radius) {
    final diameter = 2 * radius;
    final size = KPublicProfile.founderSealFor(diameter);
    final outer = KPublicProfile.founderSealOuterFor(diameter);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final centreY = c.dy + radius - outer * KPublicProfile.founderSealRise;
    return Positioned(
      left: c.dx - outer / 2,
      top: centreY - outer / 2,
      width: outer,
      height: outer,
      child: FounderBadge(
        size: size,
        ring: dark ? context.palette.surface : const Color(0xFFFFFFFF),
        ringWidth: KPublicProfile.founderSealRing,
      ),
    );
  }

  /// Under the cover, start-aligned: the name block, the medals, the bio,
  /// the tags, the links, the numbers, the buttons and the bonds section.
  Widget _info(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final medals = profile.staff == null
        ? profile.medals.showcase
        : const <ProfileMedal>[];
    final bonds = ProfileCoverHeader.hasBonds(profile);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bondsSection = _bondsOpen
        ? Padding(
            key: ProfileCoverHeader.bondsKey,
            padding: const EdgeInsets.only(top: KPublicProfile.bondsGap),
            child: ProfileBondsBlock(
              levels: const SizedBox.shrink(),
              profile: profile,
              // The own bag and premium tiles stay in the Me hub.
              ownTiles: false,
              // The worn medals are under the levels.
              showMedals: false,
            ),
          )
        : const SizedBox(width: double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(context),
        // D335 follow-up: a staff account's official bio card under the
        // name block (it was under the header, D283b).
        if (profile.staff case final staff?)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.md),
            child: StaffOfficialBio(staff: staff),
          ),
        // Owner 4: the worn medals under the levels (the art alone, D316),
        // nothing when none are worn. D283: a Kabso Team account shows none.
        if (medals.isNotEmpty)
          SizedBox(
            height: KPublicProfile.medalTap,
            child: MedalShowcaseRow(
              key: ProfileCoverHeader.medalsKey,
              medals: medals,
              size: KPublicProfile.medal,
              alignment: MainAxisAlignment.start,
              onTap: () => context.push(
                profile.isSelf
                    ? AppRoutes.medals
                    : AppRoutes.userMedals(profile.username),
              ),
            ),
          ),
        // D283b: a Kabso Team account shows the official bio card under
        // the header instead, never its typed bio.
        if (_bioOf(context) case final bio?)
          Padding(
            padding: EdgeInsets.only(
              top: medals.isEmpty ? KPublicProfile.bioGap : KSpacing.xxs,
            ),
            child: Text(
              bio,
              key: ProfileCoverHeader.bioKey,
              maxLines: profile.kabsoOwner
                  ? KPublicProfile.ownerBioLines
                  : KPublicProfile.bioLines,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(
                color: p.textSecondary,
                fontSize: KPublicProfile.bioFont,
                height: KPublicProfile.bioHeight,
              ),
            ),
          ),
        if (profile.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.sm),
            child: ProfileTagChips(
              tags: profile.tags,
              icons: ProfileTagIcon.listFor(profile.tags, profile.tagIcons),
            ),
          ),
        if (profile.links.isNotEmpty)
          KeyedSubtree(
            key: ProfileCoverHeader.linksKey,
            child: ProfileLinksRow(
              links: profile.links,
              reportable: !profile.isSelf,
            ),
          ),
        const SizedBox(height: KPublicProfile.statsGap),
        _stats(context),
        const SizedBox(height: KPublicProfile.actionsGap),
        SizedBox(
          key: ProfileCoverHeader.actionsKey,
          height: KPublicProfile.buttonHeight,
          child: widget.actions(context, bonds ? _bondsToggle(context) : null),
        ),
        // Owner 4: the family / couple / medals tiles, opened and closed by
        // the chevron (animated; reduce motion: at once).
        if (bonds)
          if (reduceMotion)
            bondsSection
          else
            AnimatedSize(
              duration: KPublicProfile.bondsMotion,
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.topStart,
              child: bondsSection,
            ),
      ],
    );
  }

  /// D357: the founder's centred block under the centred photo — the name
  /// in Kabso red (no seal beside or under it: his seal is on the photo),
  /// the other badges, the worn medals, the bio, the tags and links (all
  /// centred), the two numbers, the buttons and the bonds section (as
  /// [_info]).
  Widget _founderInfo(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final medals = profile.medals.showcase;
    final bonds = ProfileCoverHeader.hasBonds(profile);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final badges = _badges(context);
    final socials = FounderSocialRow.shown(profile.links);
    final otherLinks = [
      for (final l in profile.links)
        if (!socials.contains(l)) l,
    ];
    final bondsSection = _bondsOpen
        ? Padding(
            key: ProfileCoverHeader.bondsKey,
            padding: const EdgeInsets.only(top: KPublicProfile.bondsGap),
            child: ProfileBondsBlock(
              levels: const SizedBox.shrink(),
              profile: profile,
              ownTiles: false,
              showMedals: false,
            ),
          )
        : const SizedBox(width: double.infinity);
    final name = Text(
      profile.displayName,
      key: const Key('profile.displayName'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: t.title.copyWith(
        color: ProfileCoverHeader.founderNameColor(context),
        fontSize: KPublicProfile.founderNameFont,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          key: ProfileCoverHeader.founderIdentityKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              key: ProfileCoverHeader.nameLineKey,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: name),
                if (profile.live case final live? when !profile.blockedByMe)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: KSpacing.sm,
                    ),
                    child: ProfileLivePill(live: live, self: profile.isSelf),
                  ),
              ],
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: KSpacing.xs),
              ProfileBadgeWrap(
                key: ProfileCoverHeader.badgesKey,
                spacing: KSpacing.sm,
                runSpacing: KSpacing.xs,
                maxLines: KPublicProfile.badgeLines,
                centre: true,
                children: badges,
              ),
            ],
          ],
        ),
        if (medals.isNotEmpty)
          SizedBox(
            height: KPublicProfile.medalTap,
            child: MedalShowcaseRow(
              key: ProfileCoverHeader.medalsKey,
              medals: medals,
              size: KPublicProfile.medal,
              onTap: () => context.push(
                profile.isSelf
                    ? AppRoutes.medals
                    : AppRoutes.userMedals(profile.username),
              ),
            ),
          ),
        // v1.98-social: his bilingual bio (four lines), centred.
        if (_bioOf(context) case final bio?)
          Padding(
            padding: EdgeInsets.only(
              top: medals.isEmpty ? KPublicProfile.founderBioGap : KSpacing.xxs,
            ),
            child: Text(
              bio,
              key: ProfileCoverHeader.bioKey,
              maxLines: KPublicProfile.ownerBioLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.body.copyWith(
                color: p.textSecondary,
                fontSize: KPublicProfile.bioFont,
                height: KPublicProfile.bioHeight,
              ),
            ),
          ),
        // D357: his social row right under the bio (his Instagram,
        // Facebook, WhatsApp and Snapchat links; none → no row).
        if (socials.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: KPublicProfile.founderSocialGap,
            ),
            child: FounderSocialRow(
              links: profile.links,
              reportable: !profile.isSelf,
            ),
          ),
        if (profile.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.sm),
            child: ProfileTagChips(
              tags: profile.tags,
              icons: ProfileTagIcon.listFor(profile.tags, profile.tagIcons),
              alignment: WrapAlignment.center,
            ),
          ),
        // His other links as chips (the row's links are not repeated).
        if (otherLinks.isNotEmpty)
          KeyedSubtree(
            key: ProfileCoverHeader.linksKey,
            child: ProfileLinksRow(
              links: otherLinks,
              reportable: !profile.isSelf,
              alignment: WrapAlignment.center,
            ),
          ),
        const SizedBox(height: KPublicProfile.statsGap),
        _stats(context),
        const SizedBox(height: KPublicProfile.actionsGap),
        SizedBox(
          key: ProfileCoverHeader.actionsKey,
          height: KPublicProfile.buttonHeight,
          child: widget.actions(context, bonds ? _bondsToggle(context) : null),
        ),
        if (bonds)
          if (reduceMotion)
            bondsSection
          else
            AnimatedSize(
              duration: KPublicProfile.bondsMotion,
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.topStart,
              child: bondsSection,
            ),
      ],
    );
  }

  void _toggleBonds() => setState(() => _bondsOpen = !_bondsOpen);

  /// D335 (owner 4): the round chevron after the row's last button — opens
  /// and closes the bonds section; it turns as it does.
  Widget _bondsToggle(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final label = _bondsOpen ? l10n.profileBondsHide : l10n.profileBondsShow;
    return SizedBox.square(
      dimension: KPublicProfile.buttonHeight,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          expanded: _bondsOpen,
          label: label,
          onTap: _toggleBonds,
          excludeSemantics: true,
          child: OutlinedButton(
            key: ProfileCoverHeader.bondsToggleKey,
            style: ProfileCoverButtons.pill(context).copyWith(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              shape: const WidgetStatePropertyAll(CircleBorder()),
              minimumSize: const WidgetStatePropertyAll(Size.zero),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: _toggleBonds,
            child: AnimatedRotation(
              turns: _bondsOpen ? 0.5 : 0,
              duration: reduceMotion
                  ? Duration.zero
                  : KPublicProfile.bondsMotion,
              child: AppIcon(
                AppIcons.chevronDown,
                size: KMetrics.iconMd - 2,
                color: p.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The name block: the name (bold) and its seal, «مباشر» at the line's
  /// end (D279b; never across a block), then the badges (owner 4: the
  /// reference's subtitle line is our levels row).
  Widget _identity(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final nameStyle = t.title.copyWith(
      color: p.textPrimary,
      fontSize: KPublicProfile.nameFont,
      // D258: the special colour at semi-bold (owner).
      fontWeight: (profile.vip?.member ?? false)
          ? FontWeight.w600
          : FontWeight.w700,
    );
    final badges = _badges(context);
    return Column(
      key: ProfileCoverHeader.identityKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          key: ProfileCoverHeader.nameRowKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Row(
                    key: ProfileCoverHeader.nameLineKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: VipNameShimmer(
                          vip: profile.vip,
                          child: Text(
                            profile.displayName,
                            key: const Key('profile.displayName'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textWidthBasis: TextWidthBasis.longestLine,
                            style: nameStyle,
                          ),
                        ),
                      ),
                      // D293: the verification seal right after the name.
                      if (shownVerification(profile.verification)
                          case final badge?) ...[
                        const SizedBox(width: KPublicProfile.sealGap),
                        ProfileVerificationBadge(
                          badge: badge,
                          size: KPublicProfile.nameSeal,
                        ),
                      ],
                      // D335 follow-up: a staff account's team badge on the
                      // name line (the name is cut first on a narrow line).
                      if (_teamInline) ...[
                        const SizedBox(width: KPublicProfile.sealGap),
                        const KabsoTeamBadge(
                          height: KPublicProfile.teamBadgeInline,
                        ),
                      ],
                    ],
                  ),
                ),
                if (profile.live case final live? when !profile.blockedByMe)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: KSpacing.sm,
                    ),
                    child: ProfileLivePill(live: live, self: profile.isSelf),
                  ),
              ],
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: KSpacing.xs),
              ProfileBadgeWrap(
                key: ProfileCoverHeader.badgesKey,
                spacing: KSpacing.sm,
                runSpacing: KSpacing.xs,
                maxLines: KPublicProfile.badgeLines,
                children: badges,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The badges under the name: VIP, Kabso Team, the crests, the levels.
  List<Widget> _badges(BuildContext context) {
    final agentCode = profile.rechargeAgentCode;
    final hostCode = profile.hostAgentCode;
    return [
      if (profile.vip?.member ?? false)
        VipNameBadge(vip: profile.vip, height: 20),
      // D378 (GOLDEN_ID): the golden ID as the gold special-ID pill.
      if (profile.goldenId case final golden?)
        VipGoldenIdChip(
          goldenId: golden,
          height: 20,
          effects: KSpecialIdEffects.full,
        ),
      // D282 / D299i: a Kabso Team account wears the team badge (D307:
      // never on the founder's page); D335 follow-up: a staff account's is
      // on the name line instead.
      if (profile.kabsoTeam && !profile.kabsoOwner && !_teamInline)
        const KabsoTeamBadge(height: KabsoTeamBadge.profileHeight),
      // D292: the crests at one visible size ([KPublicProfile.nameBadge]).
      if (agentCode case final code?)
        RechargeAgentBadge(
          key: ProfileHeaderView.agentBadgeKey,
          code: code,
          height: KPublicProfile.rechargeAgentNameBadge,
        ),
      if (hostCode case final code?)
        HostAgentBadge(
          key: ProfileHeaderView.hostAgentBadgeKey,
          code: code,
          height: KPublicProfile.hostAgentNameBadge,
        ),
      if (rechargeBadgeShows(profile.rechargeBadge))
        RechargeTierBadge(
          key: ProfileHeaderView.rechargeBadgeKey,
          badge: profile.rechargeBadge,
          height: KPublicProfile.nameBadge,
        ),
      // D390 (owner 2026-11-13): the exclusive ambassador badge, for
      // everyone, while the membership is ACTIVE (the server's rule).
      if (profile.ambassadorLevel case final level?)
        AmbassadorBadge(
          key: ProfileHeaderView.ambassadorBadgeKey,
          level: level,
          height: KPublicProfile.nameBadge - 4,
        ),
      // D283: a Kabso Team account shows no levels.
      // D361 (§10.156; owner: «المؤسس ليس له ليفيل»): nor does the founder.
      if (profile.staff == null && !profile.kabsoOwner)
        ProfileLevels(
          key: ProfileCoverHeader.levelsKey,
          username: profile.isSelf ? null : profile.username,
          onOpen: profile.isSelf ? () => context.push(AppRoutes.levels) : null,
          padding: EdgeInsetsDirectional.zero,
        ),
    ];
  }

  /// D278b / D335: Followers, Following, «الكرز المستلم» and «الكوينز
  /// المرسلة» (owner 4: the four kept; never the money ones on the founder's
  /// or a Kabso Team page, D307) — short Latin numbers (D220) in equal
  /// columns with a thin line between two; a number the person hides is
  /// left out by the server and the others share the row. Two columns are
  /// the reference's ≈ 163 dp each, centred.
  Widget _stats(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final stats = <(Key, int?, String, VoidCallback?)>[
      // D357 (owner: «اظهر فقط عدد متابعين المؤسس وبجانبها عدد الاقتراحات
      // والشكاوى»): the founder's page shows these two only.
      if (profile.kabsoOwner) ...[
        (
          ProfileHeaderView.followersKey,
          profile.followerCount,
          l10n.liveCardFollowers,
          widget.onOpenFollowers,
        ),
        (
          ProfileCoverHeader.founderFeedbackKey,
          profile.founderFeedbackCount,
          l10n.founderFeedbackStat,
          null,
        ),
      ] else ...[
        (
          ProfileHeaderView.followersKey,
          profile.followerCount,
          l10n.liveCardFollowers,
          widget.onOpenFollowers,
        ),
        (
          ProfileHeaderView.followingKey,
          profile.followingCount,
          l10n.liveCardFollowing,
          widget.onOpenFollowing,
        ),
        if (profile.cherriesReceived case final n? when !_teamOrFounder)
          (ProfileCoverHeader.cherriesKey, n, l10n.liveCardCherries, null),
        if (profile.coinsSent case final n? when !_teamOrFounder)
          (ProfileCoverHeader.coinsKey, n, l10n.liveCardCoinsSent, null),
      ],
    ];
    final pending = !widget.countsKnown && !widget.countsFailed;
    final dense = stats.length > 2;
    // A number the server did not send (an older server's founder count) is
    // a dash, never a made-up 0.
    String number(int? v) =>
        widget.countsFailed || v == null ? '–' : KFormat.compactLatin(v);
    final row = IntrinsicHeight(
      child: Row(
        key: ProfileScreen.statsKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (key, value, label, onTap)) in stats.indexed) ...[
            if (i > 0)
              Center(
                child: Container(
                  width: 1,
                  height: KPublicProfile.statDivider,
                  color: p.border,
                ),
              ),
            Expanded(
              child: Semantics(
                key: key,
                button: onTap != null,
                label: pending ? label : '$label ${number(value)}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.xxs,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (pending)
                          const KSkeleton(width: KSpacing.xl)
                        else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              number(value),
                              maxLines: 1,
                              style: t.title.copyWith(
                                color: p.textPrimary,
                                fontSize: dense
                                    ? KPublicProfile.statNumberDense
                                    : KPublicProfile.statNumber,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        // A long label: two lines in a four-column row,
                        // else it shrinks a little to stay whole.
                        if (dense)
                          Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: t.caption.copyWith(
                              color: p.textSecondary,
                              fontSize: KPublicProfile.statLabelDense,
                              height: 1.2,
                            ),
                          )
                        else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: t.caption.copyWith(
                                color: p.textSecondary,
                                fontSize: KPublicProfile.statLabel,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: stats.length * KPublicProfile.statColumn,
        ),
        child: row,
      ),
    );
  }
}

/// D278b (owner: «منشنات يضعها الشخص معاه لغاية ١٠ بسطرين فقط»): the
/// person's tags as chips, at most two lines; what does not fit shows as a
/// «+n» chip at the end of the second line.
///
/// D292 (owner, after his mock; §10.106): rounded pills with the icon the
/// person chose for the tag before its text (none for `default`). Then
/// (owner: «اجعلها أصغر وبصف واحد، والأيقونة فقط بإطار مفرّغ»): small
/// (≈ 24 dp), on ONE line — what does not fit shows as «+n» — and hollow:
/// no fill, a thin Kabso-red outline, the text red as D279b.
class ProfileTagChips extends StatelessWidget {
  const new({
    required this.tags,
    super.key,
    this.icons = const [],
    this.alignment = WrapAlignment.start,
  });

  final List<String> tags;

  /// D316: centred under the centred header's bio.
  final WrapAlignment alignment;

  /// The icon of each tag (missing entries draw none).
  final List<ProfileTagIcon> icons;

  static const wrapKey = Key('profile.tags');
  static const moreKey = Key('profile.tags.more');
  static Key chipKey(int i) => Key('profile.tags.$i');

  /// D292: one line (was two, D278b).
  static const int maxLines = 1;
  static const double spacing = KSpacing.xs + 2;

  /// D292: the pill's padding, its icon, the gap after it and the label's
  /// size (≈ 24 dp tall at text scale 1).
  static const double padH = KSpacing.sm + 2;
  static const double padV = KSpacing.xs;
  static const double iconSize = 14;
  static const double iconGap = KSpacing.xs;

  /// The type scale's caption size (was 12.5).
  static const double fontSize = 12;

  /// The outline's width (BorderSide's default).
  static const double outline = 1;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    // D279b (owner: «اجعل المستطيل بلون فاتح ليكون اجمل»): the text a
    // deeper Kabso red (a light pink on dark). D292: hollow — no fill, a
    // thin red outline.
    // Dark (owner: «اجعل إطار الأيقونات … في الدارك مود بلون الأبيض»): the
    // outline and the text are the theme's text colour (white).
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = context.palette;
    final edge = dark
        ? p.textPrimary.withValues(alpha: 0.85)
        : KBrandColors.red500.withValues(alpha: 0.6);
    final ink = dark ? p.textPrimary : KBrandColors.red600;
    final style = t.caption.copyWith(
      color: ink,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured as the chips' Text lays out (the inherited style merged).
    final measured = DefaultTextStyle.of(context).style.merge(style);
    final locale = Localizations.maybeLocaleOf(context);
    final l10n = context.l10n;
    final arabic = locale?.languageCode == 'ar';
    final shown = tags.take(KPublicProfile.maxTags).toList();
    ProfileTagIcon iconOf(int i) =>
        i < icons.length ? icons[i] : ProfileTagIcon.none;
    // The icon keeps its size with large text (as the text's line).
    final iconSide = scaler.scale(iconSize);
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        double widthOf(String text, {bool icon = false}) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: measured),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: 1,
          )..layout();
          // Rounded up (and a hair more) so a measured line never wraps.
          final w =
              painter.width.ceilToDouble() +
              1 +
              2 * padH +
              2 * outline +
              (icon ? iconSide + iconGap : 0);
          painter.dispose();
          return math.min(w, max);
        }

        final widths = [
          for (final (i, tag) in shown.indexed)
            widthOf(tag, icon: !iconOf(i).isNone),
        ];
        // Greedy lines; when the tags overflow two lines, the last line
        // keeps room for «+n».
        var line = 1;
        var x = 0.0;
        var count = 0;
        final lineOf = <int>[];
        for (final w in widths) {
          final next = x == 0 ? w : x + spacing + w;
          if (next <= max) {
            x = next;
          } else {
            line++;
            if (line > maxLines) break;
            x = w;
          }
          lineOf.add(line);
          count++;
        }
        var hidden = shown.length - count;
        if (hidden > 0) {
          // Make room for «+n» on the last line.
          double lastLineWidth() {
            var w = 0.0;
            for (var i = 0; i < count; i++) {
              if (lineOf[i] != maxLines) continue;
              w = w == 0 ? widths[i] : w + spacing + widths[i];
            }
            return w;
          }

          while (count > 0) {
            final more = widthOf('+$hidden');
            final last = lastLineWidth();
            if ((last == 0 ? more : last + spacing + more) <= max) break;
            count--;
            lineOf.removeLast();
            hidden++;
          }
        }
        Widget chip(
          Key key,
          String text, {
          String? label,
          TextDirection? dir,
          ProfileTagIcon icon = ProfileTagIcon.none,
        }) => Semantics(
          key: key,
          label: label,
          excludeSemantics: label != null,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: edge)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!icon.isNone) ...[
                    ProfileTagIconView(icon: icon, size: iconSide),
                    const SizedBox(width: iconGap),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      textDirection: dir,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        return Wrap(
          key: wrapKey,
          alignment: alignment,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < count; i++)
              chip(
                chipKey(i),
                shown[i],
                icon: iconOf(i),
                // D292: the icon's name read with the tag.
                label: iconOf(i).isNone
                    ? null
                    : '${shown[i]}, ${iconOf(i).label(l10n, arabic: arabic)}',
              ),
            if (hidden > 0)
              chip(
                moreKey,
                '+$hidden',
                label: context.l10n.profileTagsMore(hidden),
                // «+3», never «3+» in Arabic.
                dir: TextDirection.ltr,
              ),
          ],
        );
      },
    );
  }
}

/// The profile pages' buttons. D335 (owner 3): stadium pills (M 41 dp tall)
/// — «متابعة» (and «إلغاء الحظر») on the Kabso-red gradient
/// ([gradientPill]); the others («مراسلة» with the send icon, «تتابعه», «تم
/// الطلب», «تعديل الملف») filled with the chip colour ([pill]).
abstract final class ProfileCoverButtons {
  static ButtonStyle primary(BuildContext context) {
    final p = context.palette;
    return FilledButton.styleFrom(
      backgroundColor: KBrandColors.red500,
      foregroundColor: p.onPrimary,
      disabledBackgroundColor: KBrandColors.red500.withValues(alpha: 0.4),
      disabledForegroundColor: p.onPrimary.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.sm),
      ),
      textStyle: context.textStyles.bodyStrong,
    );
  }

  static ButtonStyle quiet(BuildContext context) {
    // D278c: on the page colour, the theme's outlined button.
    final p = context.palette;
    return OutlinedButton.styleFrom(
      foregroundColor: p.textPrimary,
      backgroundColor: p.background,
      side: BorderSide(color: p.borderStrong),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.sm),
      ),
      textStyle: context.textStyles.bodyStrong,
    );
  }

  /// D335: the chip-coloured pill («مراسلة», «تتابعه», «تم الطلب», «تعديل
  /// الملف»).
  static ButtonStyle pill(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.styleFrom(
      foregroundColor: p.textPrimary,
      backgroundColor: ProfileCoverHeader.chipColor(context),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      shape: const StadiumBorder(),
      textStyle: pillText(context),
    );
  }

  /// The pills' label: 15 dp bold (E: the reference's ≈ 14–15 dp).
  static TextStyle pillText(BuildContext context) =>
      context.textStyles.bodyStrong.copyWith(fontSize: 15);

  /// D335 (owner 3): a pill on the Kabso-red gradient
  /// ([KPublicProfile.gradient], start → end), no shadow; dimmed while
  /// [onPressed] is null.
  static Widget gradientPill({
    required BuildContext context,
    required Key key,
    required VoidCallback? onPressed,
    required Widget child,
    Widget? icon,
  }) {
    final p = context.palette;
    final style = FilledButton.styleFrom(
      backgroundColor: const Color(0x00000000),
      disabledBackgroundColor: const Color(0x00000000),
      shadowColor: const Color(0x00000000),
      foregroundColor: p.onPrimary,
      disabledForegroundColor: p.onPrimary.withValues(alpha: 0.7),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      shape: const StadiumBorder(),
      textStyle: pillText(context),
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          shape: StadiumBorder(),
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: KPublicProfile.gradient,
          ),
        ),
        child: icon == null
            ? FilledButton(
                key: key,
                style: style,
                onPressed: onPressed,
                child: child,
              )
            : FilledButton.icon(
                key: key,
                style: style,
                onPressed: onPressed,
                icon: icon,
                label: child,
              ),
      ),
    );
  }

  /// D335: the send icon of «مراسلة» (pointing to the reading end).
  static Widget sendIcon(BuildContext context) => Transform.flip(
    flipX: Directionality.of(context) == TextDirection.rtl,
    child: AppIcon(AppIcons.send, size: 18, color: context.palette.textPrimary),
  );

  /// The label of a row button: one line, shrunk rather than cut.
  static Widget label(String text) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
}

/// D218 / D278: under the header — the account category, a staff
/// account's official bio card (D283b), the country and the month joined.
/// D335: start-aligned with the header; the family / couple / medals tiles
/// moved behind the header's chevron (owner 4).
class ProfileInfoBlock extends StatelessWidget {
  const new({required this.profile, super.key});

  final PublicProfile profile;

  static const factsKey = Key('profile.public.facts');
  static const Key levelsKey = ProfileCoverHeader.levelsKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    final arabic = locale.languageCode == 'ar';
    final country = KCountries.byCode(profile.country);
    final joined = switch (profile.joinedMonth?.split('-')) {
      [final y, final m]
          when int.tryParse(y) != null && int.tryParse(m) != null =>
        DateTime(int.parse(y), int.parse(m)),
      _ => null,
    };
    final muted = t.caption.copyWith(color: p.textSecondary, fontSize: 13);
    Widget fact(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: KPublicProfile.factIcon, color: p.textSecondary),
        const SizedBox(width: KSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ],
    );
    final category = ProfileFieldsLine(
      // D367: never on a Kabso Team profile (the founder too).
      category:
          profileHidesCategory(
            kabsoTeam: profile.kabsoTeam,
            hasStaffIdentity: profile.staff != null,
            hasStaffId: profile.staffId != null,
            kabsoOwner: profile.kabsoOwner,
          )
          ? null
          : profile.category,
      gender: profile.gender,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KPublicProfile.inset,
        0,
        KPublicProfile.inset,
        KSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          category,
          // D283b: a staff account's official bio card is in the header,
          // under the name (D335 follow-up).
          if (country != null || joined != null) ...[
            const SizedBox(height: KSpacing.xs),
            Wrap(
              key: ProfileInfoBlock.factsKey,
              spacing: KSpacing.lg,
              runSpacing: KSpacing.xs,
              children: [
                if (country != null)
                  fact(
                    Icons.place_outlined,
                    '${KCountries.flag(country.code)} '
                    '${KCountries.name(country, arabic: arabic)}',
                  ),
                if (joined != null)
                  fact(
                    Icons.calendar_month_outlined,
                    l10n.profileJoined(
                      '${DateFormat.MMMM(tag).format(joined)} ${joined.year}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
