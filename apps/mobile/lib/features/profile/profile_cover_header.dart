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
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
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
/// الغلاف اقل ارتفاع مثلاً ٤٢٪»): the picture is [coverShare] of the
/// screen's height (≈ 358 dp on a 393 × 852 phone) and fades into the dark
/// [base] block that carries the name, the numbers, the buttons, the tags
/// and the links.
abstract final class KPublicProfile {
  /// The box every profile photo is drawn in, frame or not: the frames'
  /// common box (`AvatarFrameBox.aroundAvatar`), the real extent of the
  /// largest frame.
  static final AvatarFrameBox avatarSlot = AvatarFrameBox.aroundAvatar(
    KProfile.avatar,
  );

  /// The cover picture's share of the screen's height (D278b: 0.42; was
  /// 0.57).
  static const double coverShare = 0.42;

  /// The dark block under the picture (the picture fades into it).
  static const Color base = Color(0xFF16161A);

  /// How much of [avatarSlot]'s height rises into the picture (D278b:
  /// «رفعها للاعلى قليلاً»).
  static const double avatarRise = 0.8;

  /// At most this many tags (`PublicProfile.tags`, §10.99).
  static const int maxTags = 10;

  /// The numbers row (the person card's, D220).
  static const double statNumber = 16;
  static const double statDivider = 22;

  /// From the screen's reading-start edge to [avatarSlot].
  static const double avatarStart = KSpacing.sm;

  /// The share of the picture (from its bottom) that fades into [base].
  static const double gradientShare = 0.55;

  /// The cover picture's height on a screen of [screenHeight].
  static double coverHeightFor(double screenHeight) =>
      (screenHeight * coverShare).roundToDouble();

  static const double buttonHeight = 44;
  static const double nameFont = 20;
  static const double factIcon = 16;

  /// The top buttons' translucent circle over the cover.
  static const double barButton = 40;
}

/// D278: the top bar of the profile pages over the full-bleed cover — our
/// own buttons (back, and the page's actions) on translucent circles with
/// no background while the cover is under them; once the cover has
/// scrolled away, the page-coloured bar of before with the @username.
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

  /// Wraps an icon button of the bar: a translucent circle over the cover.
  static Widget button({required bool solid, required Widget child}) =>
      solid ? child : _CoverCircle(child: child);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = solid ? p.textPrimary : KPalette.dark.textPrimary;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return KAppBar(
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
      leading: canPop
          ? Center(
              child: button(
                solid: solid,
                child: BackButton(color: fg),
              ),
            )
          : null,
      title: AnimatedOpacity(
        opacity: solid ? 1 : 0,
        duration: KMotion.fast,
        child: KeyedSubtree(key: titleKey, child: title),
      ),
      actions: [
        for (final action in actions) button(solid: solid, child: action),
        const SizedBox(width: KSpacing.xs),
      ],
    );
  }
}

class _CoverCircle extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.xxs),
    child: SizedBox.square(
      dimension: KPublicProfile.barButton,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: KLiveColors.glass,
          shape: CircleBorder(),
        ),
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(KPublicProfile.barButton),
              fixedSize: const Size.square(KPublicProfile.barButton),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

/// D278: whether the cover has scrolled out from under the top bar — the
/// bar then turns solid.
bool profileCoverScrolledAway(BuildContext context, ScrollMetrics metrics) {
  final media = MediaQuery.of(context);
  final cover = KPublicProfile.coverHeightFor(media.size.height);
  final bar = media.padding.top + kToolbarHeight + KMetrics.statusBarGap;
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
/// badges, the @username, the four numbers, [actions], the tags and the
/// links. The own profile passes [onCoverTap] (change the cover).
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
  static const levelsKey = Key('profile.public.levels');
  static const nameRowKey = Key('profile.cover.nameRow');
  static const actionsKey = Key('profile.cover.actions');
  static const linksKey = Key('profile.cover.links');
  static const cherriesKey = Key('profile.stat.cherries');
  static const coinsKey = Key('profile.stat.coins');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final coverHeight = KPublicProfile.coverHeightFor(media.size.height);
    final slot = KPublicProfile.avatarSlot;
    final avatarUrl = profile.avatarUrl;
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
        if (profile.coverUrl == null && avatarUrl != null)
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
        if (profile.coverUrl case final url?)
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
        // D278b: the cover fades into the dark block under it, so what is
        // written there reads on any picture, light ones too.
        const Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: KPublicProfile.gradientShare,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.55, 1],
                  colors: [
                    Color(0x0016161A),
                    Color(0x9916161A),
                    KPublicProfile.base,
                  ],
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
    // What is over the cover reads on the dark block in both themes: the
    // dark palette (white text, the dark skeleton).
    final dark = buildAppTheme(
      brightness: Brightness.dark,
      locale: Localizations.localeOf(context),
    );
    // D278b (owner: «صورة شخصية نريد رفعها للاعلى قليلاً»): the photo rises
    // into the cover's lower part, never under the top buttons.
    final contentTop = math.max(
      media.padding.top + KSpacing.md,
      coverHeight - slot.height * KPublicProfile.avatarRise,
    );
    return Stack(
      key: headerKey,
      children: [
        const Positioned.fill(child: ColoredBox(color: KPublicProfile.base)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: coverHeight,
          child: cover,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: coverHeight),
          child: Theme(
            data: dark,
            child: Builder(
              builder: (context) => Column(
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
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      KProfile.inset,
                      KSpacing.xs,
                      KProfile.inset,
                      KSpacing.lg,
                    ),
                    child: _details(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The name with its badges and the level badges on one line (they
  /// wrap), the @username, the numbers, the buttons, the tags, the links.
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
                  shadows: KLiveColors.glassShadow,
                  // D258: the special colour at semi-bold (owner).
                  fontWeight: (profile.vip?.member ?? false)
                      ? FontWeight.w600
                      : FontWeight.w700,
                ),
              ),
            ),
            if (profile.vip?.member ?? false)
              VipNameBadge(vip: profile.vip, height: 20),
            if (agentCode case final code?)
              RechargeAgentBadge(
                key: ProfileHeaderView.agentBadgeKey,
                code: code,
              ),
            if (hostCode case final code?)
              HostAgentBadge(
                key: ProfileHeaderView.hostAgentBadgeKey,
                code: code,
              ),
            if (rechargeBadgeShows(profile.rechargeBadge))
              RechargeTierBadge(
                key: ProfileHeaderView.rechargeBadgeKey,
                badge: profile.rechargeBadge,
              ),
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
        KeyedSubtree(
          key: handleKey,
          child: switch (tier) {
            final tier? => KSpecialUsername(
              username: profile.username,
              tier: tier,
            ),
            null => Text(
              l10n.profileUsername(profile.username),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(
                color: p.textSecondary,
                shadows: KLiveColors.glassShadow,
              ),
            ),
          },
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
            child: ProfileTagChips(tags: profile.tags),
          ),
        if (profile.links.isNotEmpty)
          KeyedSubtree(
            key: linksKey,
            child: ProfileLinksRow(
              links: profile.links,
              reportable: !profile.isSelf,
              color: p.textPrimary,
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
        child: Consumer(
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
                // A thin light ring sets the plain photo off the cover.
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
                                shadows: KLiveColors.glassShadow,
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
class ProfileTagChips extends StatelessWidget {
  const new({required this.tags, super.key});

  final List<String> tags;

  static const wrapKey = Key('profile.tags');
  static const moreKey = Key('profile.tags.more');
  static Key chipKey(int i) => Key('profile.tags.$i');

  static const int maxLines = 2;
  static const double spacing = KSpacing.xs + 2;
  static const double padH = KSpacing.sm;
  static const double padV = KSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final style = t.caption.copyWith(
      color: p.textPrimary,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Measured as the chips' Text lays out (the inherited style merged).
    final measured = DefaultTextStyle.of(context).style.merge(style);
    final locale = Localizations.maybeLocaleOf(context);
    final shown = tags.take(KPublicProfile.maxTags).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        double widthOf(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: measured),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: 1,
          )..layout();
          // Rounded up (and a hair more) so a measured line never wraps.
          final w = painter.width.ceilToDouble() + 1 + 2 * padH;
          painter.dispose();
          return math.min(w, max);
        }

        final widths = [for (final tag in shown) widthOf(tag)];
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
        }) => Semantics(
          key: key,
          label: label,
          excludeSemantics: label != null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.textPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(KRadius.xs),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: padH,
                vertical: padV,
              ),
              child: Text(
                text,
                textDirection: dir,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        );
        return Wrap(
          key: wrapKey,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < count; i++) chip(chipKey(i), shown[i]),
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
    const p = KPalette.dark;
    return OutlinedButton.styleFrom(
      foregroundColor: p.textPrimary,
      backgroundColor: KLiveColors.glass,
      side: BorderSide(color: p.textPrimary.withValues(alpha: 0.55)),
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
/// country and the month joined, the links, then our features (the medals
/// shown, the family, relationship and medals tiles).
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
          if (bio != null && bio.isNotEmpty) ...[
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
          // Our features (D218): the medals shown, the family,
          // relationship and medals tiles (no PK record pill).
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xs),
            child: ProfileBondsBlock(
              levels: const SizedBox.shrink(),
              profile: profile,
              // The own bag and premium tiles stay in the Me hub (D163).
              ownTiles: false,
            ),
          ),
        ],
      ),
    );
  }
}
