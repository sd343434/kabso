// D218: the profile header shared by the public profile and (owner:
// «وحدهما») the own profile.
//
// D278 (owner, a reference of another app's profile: «اظهر ملف شخصي بغلاف
// بهذا الحجم ويغطي للاعلى وايقونات دردشة والشات»): the cover is tall (57 %
// of the screen), full-bleed and under the status bar and our top buttons
// («استخدم ازراري»: the same buttons as before, on translucent circles);
// over its lower part, on a soft dark gradient, the photo (frames
// unchanged, D244 / D265), the name with its badges, the @username, the
// level badges, the Following / Followers counts and the action row
// («متابعة» in Kabso red, the chat button, the more button — or «تعديل
// الملف» on the own profile). The rest follows under the cover
// ([ProfileInfoBlock]).

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_live_pill.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/profile_tag_icons.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/staff/presentation/staff_covers.dart';
import 'package:kabso_live/features/staff/presentation/staff_official_bio.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// How the cover's (and the blurred photo's) picture is loaded; tests
/// swap in a [MemoryImage].
@visibleForTesting
ImageProvider Function(String src) profileCoverImageFor = NetworkImage.new;

/// The profile header's geometry.
///
/// D244: the photo and any frame sit in [avatarSlot] (the frames' common
/// box, 1.6 × the photo wide), so a worn frame never covers the name.
///
/// D278: the cover from the very top, full-bleed. D278b (owner: «اجعل
/// الغلاف اقل ارتفاع مثلاً ٤٢٪»): the picture was 42 % of the
/// screen's height (≈ 358 dp on a 393 × 852 phone) and faded into the dark
/// block that carries the name, the numbers, the buttons, the tags and the
/// links. D278c (owner: «نصفه السفلي لا تجعله تدرج لوني بدون لون، اجعله
/// كالخلفية ان كانت دارك سوداء وان كانت لايت بيضاء»): that block is the
/// page's own background (white in light, black in dark) in the theme's
/// colours. D278d (owner: «ما هذا الظلال الابيض على الغلاف ازله واجعل
/// الصورة داخل الغلاف»): no fade — the picture ends with a straight edge,
/// and the photo with its frame sits wholly inside it, near its bottom at
/// the reading start.
///
/// D292 (owner: «اجعل الغلاف أصغر بحيث تكون الصورة الشخصية نصفها داخل
/// الغلاف ونصفها خارج الغلاف»): the cover is shorter — the top bar, then
/// [avatarTopGap], then the top half of the photo's box — and the photo
/// (centred in [avatarSlot]) has its centre ON the picture's bottom edge:
/// half over the picture, half on the page. Still at the reading start.
abstract final class KPublicProfile {
  /// The box every profile photo is drawn in, frame or not: the frames'
  /// common box (`AvatarFrameBox.aroundAvatar`), the real extent of the
  /// largest frame.
  static final AvatarFrameBox avatarSlot = AvatarFrameBox.aroundAvatar(
    KProfile.avatar,
  );

  /// D292: the space between the top bar's bottom and the top of the
  /// photo's box, on the picture.
  static const double avatarTopGap = KSpacing.xl;

  /// At most this many tags (`PublicProfile.tags`, §10.99).
  static const int maxTags = 10;

  /// The numbers row (the person card's, D220).
  static const double statNumber = 16;
  static const double statDivider = 22;

  /// From the screen's reading-start edge to [avatarSlot].
  static const double avatarStart = KSpacing.sm;

  /// D292: the cover picture's height under a top bar ending [barBottom]
  /// from the screen's top: the bar, [avatarTopGap] and half the photo's
  /// box (≈ 213 dp on a 393 × 852 phone with a 59 dp status bar; was 42 %
  /// of the screen, ≈ 358 dp, D278b).
  static double coverHeightFor(double barBottom) =>
      (barBottom + avatarTopGap + avatarSlot.height / 2).roundToDouble();

  static const double buttonHeight = 44;
  static const double nameFont = 20;
  static const double factIcon = 16;

  /// D292: the top bar's buttons (back, ⋯) are plain glyphs at least this
  /// big to tap (no circles any more).
  static const double barButton = KSizes.minTouchTarget;

  /// D292 (owner: «الأيقونة في الملف الشخصي بجانب الاسم صغيرة جداً»; then
  /// «شارات 2 و3 و4 أحجامها مختلفة»): the heights of the square crests in
  /// the name row. At the level pills' 18 (D189: «as tall as the level
  /// badges») a crest read as a speck beside pills whose emblems rise to
  /// ≈ 26. The art differs in how much of its box it fills, so each crest
  /// gets its own height to draw the SAME visible weight — the square root
  /// of the opaque area on screen (alpha > 128, measured on the art files):
  ///
  /// | art                          | box       | opaque | √area / h |
  /// | recharge_badges/tier_1…5     | 192 × 192 | 61–64 %| 0.79      |
  /// | host_agent/badge (wings)     | 240 × 240 | 54 %   | 0.735     |
  /// | recharge_agent/badge         | 240 × 219 | 65 %   | 0.844     |
  ///
  /// (√area / h = √(opaque × width ÷ height); the recharge-agent art is
  /// 1.096 wide.) The daily badge sets the size, [nameBadge] = 26; the
  /// others are 26 × 0.79 ÷ their factor: host agent 27.9 → 28, recharge
  /// agent 24.3 → 24. All three are ≤ the name's line (26–27) + 1, centred
  /// on it.
  static const double nameBadge = 26;

  /// The host-agent crest beside the name (its wings leave 46 % of the box
  /// clear; see [nameBadge]).
  static const double hostAgentNameBadge = 28;

  /// The recharge-agent crest beside the name (its dense ribbon fills
  /// more of the box; see [nameBadge]).
  static const double rechargeAgentNameBadge = 24;

  /// D292 (owner: «الميداليات تكون تحت الاسم»): the worn medals' side in
  /// their own row under the name line (was 26 in the bonds block).
  static const double medal = 34;
}

/// D278: the top bar of the profile pages over the full-bleed cover — our
/// own buttons (back, and the page's actions) with no background while the
/// cover is under them; once the cover has scrolled away, the page-coloured
/// bar of before with the @username. D292 (owner: «الرجوع والثلاث نقاط جنب
/// بعضهم وبدون أيقونة»): back and the page's buttons side by side at the
/// reading start, plain light glyphs over the cover (no circles) with a
/// soft shadow and the top shade; the theme's colours once solid. (The
/// @username in the bar's centre over the cover was tried and withdrawn —
/// owner: «ارجع اليوزر أسفل الاسم».)
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

  /// The cover has scrolled away: the page colour and the title.
  final bool solid;
  final Widget title;
  final List<Widget> actions;

  static const titleKey = Key('profile.bar.title');

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + KMetrics.statusBarGap);

  /// D292 (owner: «بدون أيقونة»): a glyph of the bar as it is — no circle
  /// behind it; over the cover a soft dark shadow keeps it legible (an svg
  /// glyph gets a blurred copy behind it; Material icons take the bar's
  /// icon shadow).
  static Widget glyph({required bool solid, required Widget child}) => solid
      ? child
      : Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: Transform.translate(
                offset: const Offset(0, 1),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x8C000000),
                      BlendMode.srcIn,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
            child,
          ],
        );

  /// The soft shadow of the bar's text and Material icons over the cover.
  static const List<Shadow> coverShadow = [
    Shadow(color: Color(0x8C000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// The width of the grouped buttons at the reading start: back (when the
  /// page was pushed) then the page's actions.
  static double _groupWidth(int count) =>
      KSpacing.xs +
      count * KPublicProfile.barButton +
      (count - 1) * KSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = solid ? p.textPrimary : KPalette.dark.textPrimary;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    // D292 (owner: «الرجوع والثلاث نقاط جنب بعضهم»): back, then the page's
    // buttons, side by side at the reading start; the other side is empty.
    final group = [if (canPop) BackButton(color: fg), ...actions];
    // D292 (owner: «واجعل السهم زر رجوع بشكل أفضل»): the back button draws
    // the app's own back chevron (`AppIcons.back`, the 1.8 stroke the app's
    // other bars use), 24 dp, pointing to the reading start (mirrored in
    // RTL), with the bar's shadow over the cover.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ActionIconTheme(
      data: ActionIconThemeData(
        backButtonIconBuilder: (_) => glyph(
          solid: solid,
          child: Transform.flip(
            flipX: rtl,
            child: AppIcon(AppIcons.back, size: KMetrics.iconMd, color: fg),
          ),
        ),
      ),
      child: IconTheme.merge(
        data: IconThemeData(shadows: solid ? null : coverShadow),
        child: KAppBar(
          backgroundColor: solid ? p.background : Colors.transparent,
          foregroundColor: fg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          // The status bar's icons: light over the cover, the theme's after.
          systemOverlayStyle: !solid || dark
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                ),
          leadingWidth: group.isEmpty ? null : _groupWidth(group.length),
          leading: group.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: KSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: KSpacing.xxs,
                    children: group,
                  ),
                ),
          title: AnimatedOpacity(
            opacity: solid ? 1 : 0,
            duration: KMotion.fast,
            child: KeyedSubtree(key: titleKey, child: title),
          ),
          actions: const [],
        ),
      ),
    );
  }
}

/// D278: whether the cover has scrolled out from under the top bar — the
/// bar then turns solid.
bool profileCoverScrolledAway(BuildContext context, ScrollMetrics metrics) {
  final media = MediaQuery.of(context);
  final bar = media.padding.top + kToolbarHeight + KMetrics.statusBarGap;
  final cover = KPublicProfile.coverHeightFor(bar);
  return metrics.axis == Axis.vertical &&
      metrics.pixels > cover - bar - KSpacing.xl;
}

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

/// D278 / D278b: the full-bleed cover and, over its lower part and the dark
/// block it fades into, the photo, the name with its badges and level
/// badges, the @username, the worn medals (D292), the four numbers,
/// [actions], the tags and the links. The own profile passes [onCoverTap]
/// (change the cover).
class ProfileCoverHeader extends StatelessWidget {
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
  });

  final PublicProfile profile;

  /// The action row: «متابعة», chat and more; or «تعديل الملف».
  final Widget actions;

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
  static const coverFallbackKey = Key('profile.public.cover.gradient');
  static const coverAvatarKey = Key('profile.public.cover.avatar');
  static const coverButtonKey = Key('profile.cover.tap');
  static const watchLiveKey = Key('profile.public.watchLive');
  static const handleKey = Key('profile.cover.handle');

  /// D283c: the «ID: Kabso01» line of a staff account.
  static const staffIdKey = Key('profile.cover.staffId');
  static const levelsKey = Key('profile.public.levels');

  /// D283: a staff profile's team cover (D283d: its region line is only in
  /// the official bio card).
  static const staffCoverKey = Key('profile.cover.staff');
  static const nameRowKey = Key('profile.cover.nameRow');

  /// D292: the worn medals' row under the name line.
  static const medalsKey = Key('profile.cover.medals');
  static const actionsKey = Key('profile.cover.actions');
  static const linksKey = Key('profile.cover.links');
  static const cherriesKey = Key('profile.stat.cherries');
  static const coinsKey = Key('profile.stat.coins');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final slot = KPublicProfile.avatarSlot;
    final avatarUrl = profile.avatarUrl;
    final page = context.palette.background;
    // D292: the photo's centre on the picture's bottom edge, under the top
    // bar. The page runs under the bar (`extendBodyBehindAppBar`), so its
    // top padding is the status bar and the bar.
    final coverHeight = KPublicProfile.coverHeightFor(media.padding.top);
    // v1.72-live (D283, §10.96.10): a Kabso Team account's cover is its
    // region's team cover, locked (no cover of its own, never changed here).
    final staff = profile.staff;
    final onCoverTap = staff == null ? this.onCoverTap : null;
    final cover = Stack(
      key: coverAreaKey,
      fit: StackFit.expand,
      children: [
        // The fallback: the Kabso gradient, with the photo blurred over it
        // when there is one (owner, D278: never an empty cover).
        const DecoratedBox(
          key: ProfileCoverHeader.coverFallbackKey,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                KBrandColors.red400,
                KBrandColors.red600,
                KBrandColors.red700,
              ],
            ),
          ),
        ),
        if (staff != null)
          Image(
            key: ProfileCoverHeader.staffCoverKey,
            image: AssetImage(StaffCovers.assetFor(staff.primaryRegion)),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        if (staff == null && profile.coverUrl == null && avatarUrl != null)
          ImageFiltered(
            key: ProfileCoverHeader.coverAvatarKey,
            imageFilter: ImageFilter.blur(
              sigmaX: 24,
              sigmaY: 24,
              tileMode: TileMode.decal,
            ),
            child: Image(
              image: profileCoverImageFor(avatarUrl),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              color: KLiveColors.glass,
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        if (profile.coverUrl case final url? when staff == null)
          Image(
            key: ProfileCoverHeader.coverKey,
            image: profileCoverImageFor(url),
            fit: BoxFit.cover,
            semanticLabel: l10n.profileCoverOf(profile.displayName),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        // Under the status bar and the buttons: a light shade.
        const Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            heightFactor: 0.3,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59000000), Color(0x00000000)],
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
                child: InkWell(key: coverButtonKey, onTap: tap),
              ),
            ),
          ),
      ],
    );
    final contentTop = coverHeight - slot.height / 2;
    return Stack(
      key: headerKey,
      children: [
        Positioned.fill(child: ColoredBox(color: page)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: coverHeight,
          child: cover,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: coverHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: contentTop),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: KPublicProfile.avatarStart,
                ),
                child: SizedBox(
                  width: slot.width,
                  height: slot.height,
                  child: Center(child: _avatar(context)),
                ),
              ),
              // The picture ended at the photo's middle (D292); the name
              // row follows the photo's box.
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KProfile.inset,
                  KSpacing.sm,
                  KProfile.inset,
                  KSpacing.lg,
                ),
                child: _details(context),
              ),
            ],
          ),
        ),
        // D279b: «مباشر» on the picture, at the bottom-end corner opposite
        // the photo (the server sends no `live` across a block either way).
        // D292: the photo's middle is the picture's edge now, so the pill
        // stays on the picture in the photo's upper half.
        if (profile.live case final live? when !profile.blockedByMe)
          PositionedDirectional(
            top: contentTop,
            height: slot.height / 2 - KSpacing.sm,
            end: KProfile.inset,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              widthFactor: 1,
              child: ProfileLivePill(live: live, self: profile.isSelf),
            ),
          ),
      ],
    );
  }

  /// The name with its badges and the level badges on one line (they
  /// wrap), the @username, the worn medals (D292), the numbers, the
  /// buttons, the tags, the links.
  Widget _details(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final agentCode = profile.rechargeAgentCode;
    final hostCode = profile.hostAgentCode;
    final tier = profile.premiumTier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // D278b (owner: «الاسم يظهر بجانبه الليفيلات»): the name, the VIP
        // badge right after it (D268), our badges, then the level badges.
        Wrap(
          key: nameRowKey,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KSpacing.sm,
          runSpacing: KSpacing.xs,
          children: [
            // D258: the VIP name's gold (CHAT_NAME_COLOR).
            VipNameShimmer(
              vip: profile.vip,
              child: Text(
                profile.displayName,
                key: const Key('profile.displayName'),
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontSize: KPublicProfile.nameFont,
                  // D258: the special colour at semi-bold (owner).
                  fontWeight: (profile.vip?.member ?? false)
                      ? FontWeight.w600
                      : FontWeight.w700,
                ),
              ),
            ),
            if (profile.vip?.member ?? false)
              VipNameBadge(vip: profile.vip, height: 20),
            // D282: a staff account wears the Kabso Team badge.
            // D292 (owner: «شارة فريق كابسو صغيرة وغير واضحة»).
            if (profile.kabsoTeam)
              const KabsoTeamBadge(height: KabsoTeamBadge.profileHeight),
            // D292: the crests at one visible size
            // ([KPublicProfile.nameBadge]).
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
            // D283: a Kabso Team account shows no levels.
            if (profile.staff == null)
              ProfileLevels(
                key: levelsKey,
                username: profile.isSelf ? null : profile.username,
                onOpen: profile.isSelf
                    ? () => context.push(AppRoutes.levels)
                    : null,
                padding: EdgeInsetsDirectional.zero,
              ),
          ],
        ),
        const SizedBox(height: KSpacing.xxs),
        // The @username (a premium one with its badge, D146) under it.
        // D283c: a staff account shows its official staff ID «ID: Kabso01»
        // instead (the username stays for login and links).
        KeyedSubtree(
          key: handleKey,
          child: switch (tier) {
            _ when profile.staffId != null => Semantics(
              hint: l10n.profileStaffIdHint,
              child: Text(
                l10n.profileStaffId(profile.staffId!),
                key: staffIdKey,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            final tier? => KSpecialUsername(
              username: profile.username,
              tier: tier,
            ),
            null => Text(
              l10n.profileUsername(profile.username),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: p.textSecondary),
            ),
          },
        ),
        // D292 (owner: «الميداليات تكون تحت الاسم»): the medals the person
        // chose to show, in their order, on their own row under the name
        // line and the @username (owner, after: «ارجع اليوزر أسفل الاسم»)
        // — larger than the old bonds-block row; nothing (no gap) when none
        // are worn. D283: a Kabso Team account shows none.
        if (profile.staff == null && profile.medals.showcase.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: MedalShowcaseRow(
              key: medalsKey,
              medals: profile.medals.showcase,
              size: KPublicProfile.medal,
              alignment: MainAxisAlignment.start,
              onTap: () => context.push(
                profile.isSelf
                    ? AppRoutes.medals
                    : AppRoutes.userMedals(profile.username),
              ),
            ),
          ),
        const SizedBox(height: KSpacing.md),
        _stats(context),
        const SizedBox(height: KSpacing.md),
        SizedBox(
          key: actionsKey,
          height: KPublicProfile.buttonHeight,
          child: actions,
        ),
        // D278b: «منشنات» (up to 10, two lines at most), then the links.
        if (profile.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.md),
            child: ProfileTagChips(
              tags: profile.tags,
              icons: ProfileTagIcon.listFor(profile.tags, profile.tagIcons),
            ),
          ),
        if (profile.links.isNotEmpty)
          KeyedSubtree(
            key: linksKey,
            child: ProfileLinksRow(
              links: profile.links,
              reportable: !profile.isSelf,
            ),
          ),
      ],
    );
  }

  Widget _avatar(BuildContext context) {
    final l10n = context.l10n;
    final room = profile.liveRoomId;
    final live = room != null;
    return Semantics(
      key: ProfileHeaderView.avatarKey,
      button: live,
      label: live ? l10n.profileWatchLive : null,
      // While live the photo is the way into the room (one label).
      excludeSemantics: live,
      child: GestureDetector(
        key: live ? ProfileCoverHeader.watchLiveKey : null,
        onTap: live ? () => context.push(AppRoutes.liveRoom(room)) : null,
        // D258: the VIP's animated frame, unless an agent or bag frame is
        // worn (those keep their own art). D265 (owner): the picture fills
        // the frame's whole opening.
        child: profile.staff != null || isTeamAvatarUrl(profile.avatarUrl)
            // D283: the team picture in the locked team frame, filling the
            // photo's slot (no VIP, bag or store frame ever).
            ? KabsoTeamAvatar.boxed(
                box: math.min(
                  KPublicProfile.avatarSlot.width,
                  KPublicProfile.avatarSlot.height,
                ),
              )
            : Consumer(
                builder: (context, ref, _) {
                  // While live the live ring and its badge win over every frame
                  // (ProfileAvatar): the VIP frame too.
                  final vip =
                      !live &&
                          profile.rechargeAgentCode == null &&
                          profile.hostAgentCode == null &&
                          profile.avatarFrame == null
                      ? profile.vip
                      : null;
                  final framed = VipAvatarFrame.shows(ref, vip);
                  return VipAvatarFrame(
                    vip: vip,
                    size: KProfile.avatar,
                    child: ProfileAvatar(
                      displayName: profile.displayName,
                      avatarUrl: profile.avatarUrl,
                      live: live,
                      cpFrame: cpFrame ?? cpWearsSpecialFrame(profile.cp),
                      agentCode: profile.rechargeAgentCode,
                      hostAgentCode: profile.hostAgentCode,
                      avatarFrame: profile.avatarFrame,
                      // A thin light ring sets the plain photo off the picture.
                      outline: framed ? null : KPalette.dark.textPrimary,
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// D278b: Followers, Following, «الكرز المستلم» and «الكوينز المرسلة» —
  /// the person card's numbers and format (D220: short Latin numbers, equal
  /// columns, a thin line between two; a number the person hides is left
  /// out by the server and the others share the row).
  Widget _stats(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final stats = <(Key, int, String, VoidCallback?)>[
      (
        ProfileHeaderView.followersKey,
        profile.followerCount,
        l10n.liveCardFollowers,
        onOpenFollowers,
      ),
      (
        ProfileHeaderView.followingKey,
        profile.followingCount,
        l10n.liveCardFollowing,
        onOpenFollowing,
      ),
      if (profile.cherriesReceived case final n?)
        (cherriesKey, n, l10n.liveCardCherries, null),
      if (profile.coinsSent case final n?)
        (coinsKey, n, l10n.liveCardCoinsSent, null),
    ];
    final pending = !countsKnown && !countsFailed;
    String number(int v) => countsFailed ? '\u2013' : KFormat.compactLatin(v);
    return IntrinsicHeight(
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
                  color: p.textPrimary.withValues(alpha: 0.18),
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
                      vertical: KSpacing.xxs,
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
                                fontSize: KPublicProfile.statNumber,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ),
                        const SizedBox(height: 1),
                        // A long label shrinks a little to stay whole.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: t.caption.copyWith(
                              color: p.textSecondary,
                              fontSize: 12,
                              height: 1.2,
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
  const new({required this.tags, super.key, this.icons = const []});

  final List<String> tags;

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

/// D278: the buttons of the action row over the cover. [primary] is the
/// Kabso red fill («متابعة»); otherwise a translucent fill with a light
/// outline.
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

  /// A square icon button of the row (chat, more).
  static Widget square({
    required BuildContext context,
    required Key key,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
  }) => SizedBox.square(
    dimension: KPublicProfile.buttonHeight,
    child: Tooltip(
      message: tooltip,
      child: OutlinedButton(
        key: key,
        style: quiet(context)
            .copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
        onPressed: onPressed,
        child: Semantics(label: tooltip, child: icon),
      ),
    ),
  );

  /// The label of a row button: one line, shrunk rather than cut.
  static Widget label(String text) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
}

/// D218 / D278: under the cover — the account category, the bio, the
/// country and the month joined, the links, then our features (the family,
/// relationship and medals tiles; D292: the medals shown are under the name
/// in [ProfileCoverHeader]).
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
    final bio = profile.bio;
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KProfile.inset,
        KSpacing.sm,
        KProfile.inset,
        KSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileFieldsLine(category: profile.category, gender: profile.gender),
          // D283b: a Kabso Team account shows the company's official bio
          // card, never its typed bio.
          if (profile.staff case final staff?) ...[
            const SizedBox(height: KSpacing.sm),
            StaffOfficialBio(staff: staff),
          ] else if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: KSpacing.xs),
            Text(bio, style: t.body.copyWith(color: p.textPrimary)),
          ],
          if (country != null || joined != null) ...[
            const SizedBox(height: KSpacing.sm),
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
          // Our features (D218): the family, relationship and medals tiles
          // (no PK record pill; D292: the medals shown are under the name).
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: ProfileBondsBlock(
              levels: const SizedBox.shrink(),
              profile: profile,
              // The own bag and premium tiles stay in the Me hub (D163).
              ownTiles: false,
              // D292: the worn medals are under the name in the header.
              showMedals: false,
            ),
          ),
        ],
      ),
    );
  }
}
