import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/presentation/cp_actions.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What tapping a profile's family or relationship (CP-018) does, from the
/// profile alone (`PublicProfile.family` / `cp`, §10.21).
enum BondTap {
  /// The family's page.
  openFamily,

  /// Your own empty family: browse families or create one.
  browseFamilies,

  /// Your own relationship: the CP space when you have a partner (CP-021),
  /// else the CP page (requests).
  openCp,

  /// Someone else's couple: its CP space, read-only (CP-021); the partner's
  /// profile when the server did not send the couple's id.
  openPartner,

  /// Someone else without a partner: send them a CP request.
  sendCp,

  /// Nothing to open (someone else's empty family, or a guest).
  none,
}

/// The family box's tap on [profile]'s card or profile.
BondTap familyTap(PublicProfile profile) => profile.family != null
    ? BondTap.openFamily
    : profile.isSelf
    ? BondTap.browseFamilies
    : BondTap.none;

/// The relationship box's tap; [signedIn] = the viewer has an account.
BondTap cpTap(PublicProfile profile, {required bool signedIn}) => profile.isSelf
    ? BondTap.openCp
    : profile.cp != null
    ? BondTap.openPartner
    : signedIn
    ? BondTap.sendCp
    : BondTap.none;

/// Runs [tap] for [profile] (after [before], e.g. closing a sheet), or
/// null when there is nothing to do.
VoidCallback? bondAction(
  BuildContext context,
  WidgetRef ref,
  PublicProfile profile,
  BondTap tap, {
  VoidCallback? before,
}) {
  // Read now, while mounted: a sheet's context is gone once it closes.
  final router = GoRouter.maybeOf(context);
  void go(String location) {
    before?.call();
    if (router != null) unawaited(router.push(location));
  }

  return switch (tap) {
    BondTap.openFamily => () => go(AppRoutes.family(profile.family!.id)),
    BondTap.browseFamilies => () => go(AppRoutes.families),
    BondTap.openCp => () => go(
      profile.cp != null ? AppRoutes.cpSpace : AppRoutes.cp,
    ),
    BondTap.openPartner => () => go(switch (profile.cp!.id) {
      final id? => AppRoutes.cpCouple(id),
      null => AppRoutes.userProfile(profile.cp!.partner.username),
    }),
    BondTap.sendCp => () => unawaited(
      sendCpRequest(
        context,
        ref,
        username: profile.username,
        name: profile.displayName.isEmpty
            ? profile.username
            : profile.displayName,
      ),
    ),
    BondTap.none => null,
  };
}

/// The family, relationship and medals of a profile (CP-018) as three
/// tiles under the header: each says what exists and opens it.
///
/// D218 (owner: «اجعلها بهذه الطريقة بشكل مطابق ١٠٠٪»): each tile IS the
/// owner's glossy pill art (`assets/profile/bonds/`, PROVENANCE.md) — yellow
/// with the shield (family), orange with the flame (couple), purple with
/// the trophy (medals) — at its own aspect ratio, three in a row of equal
/// height, 8 dp apart. The medallion is at the reading start (the art as
/// drawn in Arabic, mirrored in English); the title (white, bold, a soft
/// shadow) and the value (white 85 %) sit in the pill's empty part and
/// shrink to fit, never the art. The same in light and dark (no card).
class ProfileBondsRow extends ConsumerWidget {
  const new({required this.profile, super.key});

  final PublicProfile profile;

  static const familyKey = Key('profile.bonds.family');
  static const cpKey = Key('profile.bonds.cp');
  static const medalsKey = Key('profile.bonds.medals');

  /// Each tile's title (tests: never cut).
  static const Key titleKey = _Pill.titleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final signedIn = ref.watch(currentUserProvider) != null;
    final family = profile.family;
    final cp = profile.cp;
    final cpAction = cpTap(profile, signedIn: signedIn);
    Widget pill(_PillArt art, Widget tile) =>
        Expanded(flex: (art.aspect * 1000).round(), child: tile);
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: Row(
        children: [
          pill(
            _PillArt.family,
            _Pill(
              key: familyKey,
              art: _PillArt.family,
              title: l10n.profileBondFamily,
              value: family == null
                  ? l10n.liveUserNone
                  : l10n.familyBoxValue(family.name, family.level),
              onTap: bondAction(context, ref, profile, familyTap(profile)),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          pill(
            _PillArt.couple,
            _Pill(
              key: cpKey,
              art: _PillArt.couple,
              title: l10n.profileBondCouple,
              value: cp != null
                  ? (cp.partner.displayName.isEmpty
                        ? cp.partner.username
                        : cp.partner.displayName)
                  : cpAction == BondTap.sendCp
                  ? l10n.cpSendShort
                  : l10n.liveUserNone,
              onTap: bondAction(context, ref, profile, cpAction),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          pill(
            _PillArt.medals,
            _Pill(
              key: medalsKey,
              art: _PillArt.medals,
              title: l10n.profileBondMedals,
              value: l10n.medalsOwned(
                profile.medals.owned,
                profile.medals.total,
              ),
              onTap: () => context.push(
                profile.isSelf
                    ? AppRoutes.medals
                    : AppRoutes.userMedals(profile.username),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The owner's pill art and its measured geometry (pixels of the asset;
/// PROVENANCE.md): the image size and the opaque body (the glow margin is
/// 14 px; the medallion is a circle as tall as the body at its right end).
enum _PillArt {
  family('assets/profile/bonds/family.webp', 662, 290, 14, 14, 634, 262),
  couple('assets/profile/bonds/couple.webp', 642, 289, 14, 14, 614, 261),
  medals('assets/profile/bonds/medals.webp', 653, 289, 14, 14, 625, 261);

  new(
    this.asset,
    this.width,
    this.height,
    this.bodyLeft,
    this.bodyTop,
    this.bodyWidth,
    this.bodyHeight,
  );

  final String asset;
  final double width;
  final double height;
  final double bodyLeft;
  final double bodyTop;
  final double bodyWidth;
  final double bodyHeight;

  double get aspect => width / height;

  /// The text area, as fractions of the image, measured from the medallion
  /// side (the reading start) and from the other end.
  double get textFromMedallion =>
      (width - (bodyLeft + bodyWidth) + bodyHeight * 1.04) / width;
  double get textFromEnd => (bodyLeft + bodyHeight * 0.26) / width;
  double get textTop => (bodyTop + bodyHeight * 0.14) / height;
}

/// D218: one pill. A 48 dp+ target; the ripple follows the pill's shape.
class _Pill extends StatelessWidget {
  const new({
    required this.art,
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
  });

  final _PillArt art;
  final String title;
  final String value;
  final VoidCallback? onTap;

  static const Key titleKey = ValueKey('profile.bonds.title');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const white = Color(0xFFFFFFFF);
    const shadow = [
      Shadow(color: Color(0x73000000), blurRadius: 3, offset: Offset(0, 1)),
    ];
    return Semantics(
      button: onTap != null,
      label: '$title, $value',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w / art.aspect;
          final scale = w / art.width;
          final body = Rect.fromLTWH(
            art.bodyLeft * scale,
            art.bodyTop * scale,
            art.bodyWidth * scale,
            art.bodyHeight * scale,
          );
          final box = h < KSizes.minTouchTarget ? KSizes.minTouchTarget : h;
          return SizedBox(
            width: w,
            height: box,
            child: Center(
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Transform.flip(
                        // The art is drawn for Arabic (medallion on the
                        // right); English mirrors it (medallion at the left).
                        flipX: !rtl,
                        child: Image.asset(
                          art.asset,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: w * art.textFromMedallion,
                      end: w * art.textFromEnd,
                      top: h * art.textTop,
                      bottom: h * art.textTop,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: KBondCard.maxTextScale,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  title,
                                  key: titleKey,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: t.label.copyWith(
                                    color: white,
                                    fontSize: KBondCard.titleFont,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    shadows: shadow,
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    // Long names end in «…» rather than
                                    // shrinking to dust.
                                    maxWidth:
                                        w *
                                        (1 -
                                            art.textFromMedallion -
                                            art.textFromEnd) *
                                        1.4,
                                  ),
                                  child: Text(
                                    value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(
                                      color: white.withValues(alpha: 0.85),
                                      fontSize: KBondCard.valueFont - 1,
                                      height: 1.15,
                                      shadows: shadow,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The ripple and the press highlight follow the pill.
                    Positioned.fromRect(
                      rect: body,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: onTap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// D218 geometry of the bond cards.
abstract final class KBondCard {
  static const double radius = 14;
  static const double minHeight = 68;
  static const double circle = 32;
  static const double art = 20;
  static const double titleFont = 13;
  static const double valueFont = 12;

  /// The cards keep their shape with large text: their words grow up to
  /// this scale, then the title shrinks to fit (never cut).
  static const double maxTextScale = 1.3;
}

/// The own profile's bag and premium tiles (the Me hub's look).
class _Tile extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.onTap,
    required this.tint,
    required this.iconData,
    super.key,
  });

  final String title;
  final String value;
  final IconData iconData;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(KBondCard.radius);
    return Semantics(
      button: onTap != null,
      label: '$title, $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? p.surfaceOverlay : p.surface,
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KBondCard.minHeight),
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: KBondCard.circle,
                      height: KBondCard.circle,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tint.withValues(alpha: dark ? 0.22 : 0.12),
                      ),
                      child: Icon(iconData, size: KBondCard.art, color: tint),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.label.copyWith(
                              color: p.textPrimary,
                              fontSize: KBondCard.titleFont,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              color: p.textSecondary,
                              fontSize: KBondCard.valueFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile header's block under the name (D72, CP-018): the level
/// badges ([levels]), the medals [profile] chose to show (nothing when none
/// are chosen), the family, relationship and medals tiles and, on your own
/// profile, the bag. Only the levels while [profile] is not loaded.
class ProfileBondsBlock extends StatelessWidget {
  const new({
    required this.levels,
    required this.profile,
    super.key,
    this.ownTiles = true,
  });

  final Widget levels;
  final PublicProfile? profile;

  /// The bag and premium-username tiles of the own profile; D218 (owner:
  /// the own profile like the public one) leaves them to the Me hub.
  final bool ownTiles;

  /// The bag tile (own profile only, CP-019).
  static const bagKey = Key('profile.bonds.bag');

  /// D146: the premium usernames tile (own profile only).
  static const premiumKey = Key('profile.bonds.premium');

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        levels,
        if (profile != null) ...[
          if (profile.medals.showcase.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.sm),
              child: MedalShowcaseRow(
                medals: profile.medals.showcase,
                alignment: MainAxisAlignment.start,
                onTap: () => context.push(
                  profile.isSelf
                      ? AppRoutes.medals
                      : AppRoutes.userMedals(profile.username),
                ),
              ),
            ),
          ProfileBondsRow(profile: profile),
          // CP-019: your own bag (the profile card you wear, and more
          // categories later).
          if (profile.isSelf && ownTiles)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.sm),
              child: _Tile(
                key: bagKey,
                iconData: Icons.backpack_rounded,
                tint: const Color(0xFFB8860B),
                title: context.l10n.bagTitle,
                value: context.l10n.bagTileValue,
                onTap: () => context.push(AppRoutes.bag),
              ),
            ),
          // D146: premium usernames (the store, and the person's own one).
          if (profile.isSelf && ownTiles)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.sm),
              child: _Tile(
                key: premiumKey,
                iconData: Icons.workspace_premium_rounded,
                tint: const Color(0xFFB8860B),
                title: context.l10n.premiumTitle,
                value: context.l10n.premiumTileValue,
                onTap: () => context.push(AppRoutes.premium),
              ),
            ),
        ],
      ],
    );
  }
}
