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
/// D218 (owner: «اجعلها بهذه الطريقة بشكل مطابق ١٠٠٪», then «مستطيل بحواف
/// مستديرة قليلاً»): three equal rounded rectangles (12 dp) 8 dp apart, in
/// the owner's colours — the glossy yellow (family), orange (couple) and
/// purple (medals) bodies painted from colours sampled on the owner's pills
/// (`assets/profile/bonds/PROVENANCE.md`), with the owner's medallion art
/// unchanged at the reading start (right in Arabic, left in English; the
/// art itself is never mirrored). The title (white, bold, a soft shadow)
/// and the value (white 85 %) fill the rest and shrink to fit. The same in
/// light and dark.
class ProfileBondsRow extends ConsumerWidget {
  const new({required this.profile, super.key});

  final PublicProfile profile;

  static const familyKey = Key('profile.bonds.family');
  static const cpKey = Key('profile.bonds.cp');
  static const medalsKey = Key('profile.bonds.medals');

  /// Each tile's title (tests: never cut).
  static const Key titleKey = _BondTile.titleKey;

  /// Each tile's body and medallion (tests).
  static const Key bodyKey = _BondTile.bodyKey;
  static const Key medalKey = _BondTile.medalKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final signedIn = ref.watch(currentUserProvider) != null;
    final family = profile.family;
    final cp = profile.cp;
    final cpAction = cpTap(profile, signedIn: signedIn);
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: _BondTile(
              key: familyKey,
              art: BondArt.family,
              title: l10n.profileBondFamily,
              value: family == null
                  ? l10n.liveUserNone
                  : l10n.familyBoxValue(family.name, family.level),
              onTap: bondAction(context, ref, profile, familyTap(profile)),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: _BondTile(
              key: cpKey,
              art: BondArt.couple,
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
          Expanded(
            child: _BondTile(
              key: medalsKey,
              art: BondArt.medals,
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

/// D218 geometry of the bond tiles.
abstract final class KBondTile {
  static const double height = 60;
  static const double radius = 12;
  static const double rim = 1.2;

  /// The medallion's diameter (of the tile height) and its inset.
  static const double medal = 0.92;
  static const double medalInset = 3;
}

/// The owner's art for one bond: the medallion (cut from the owner's pill
/// along its circle, unchanged) and the body colours sampled on the pill
/// (`measure.py sample`, PROVENANCE.md): the top of the body, its middle,
/// its bottom, the shade next to the medallion, the light rim on top and
/// the darker rim below.
enum BondArt {
  family(
    'assets/profile/bonds/family_medal.webp',
    top: Color(0xFFFFDB1D),
    middle: Color(0xFFFCC302),
    bottom: Color(0xFFFBCE09),
    shade: Color(0xFFF7A902),
    rimLight: Color(0xFFFBF8C5),
    rimDark: Color(0xFFF4B50B),
  ),
  couple(
    'assets/profile/bonds/couple_medal.webp',
    top: Color(0xFFFC7516),
    middle: Color(0xFFFA5101),
    bottom: Color(0xFFFE6205),
    shade: Color(0xFFE83C00),
    rimLight: Color(0xFFFDEE7C),
    rimDark: Color(0xFFF94E06),
  ),
  medals(
    'assets/profile/bonds/medals_medal.webp',
    top: Color(0xFFD054F9),
    middle: Color(0xFF982FF5),
    bottom: Color(0xFFC149FC),
    shade: Color(0xFF751EE8),
    rimLight: Color(0xFFD8C2F4),
    rimDark: Color(0xFF9B3AEC),
  );

  new(
    this.medal, {
    required this.top,
    required this.middle,
    required this.bottom,
    required this.shade,
    required this.rimLight,
    required this.rimDark,
  });

  final String medal;
  final Color top;
  final Color middle;
  final Color bottom;
  final Color shade;
  final Color rimLight;
  final Color rimDark;
}

/// D218: one rounded-rectangle tile. A 60 dp target; the ripple is clipped
/// to the rounded rectangle.
class _BondTile extends StatelessWidget {
  const new({
    required this.art,
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
  });

  final BondArt art;
  final String title;
  final String value;
  final VoidCallback? onTap;

  static const Key titleKey = ValueKey('profile.bonds.title');
  static const Key bodyKey = ValueKey('profile.bonds.body');
  static const Key medalKey = ValueKey('profile.bonds.medal');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const white = Color(0xFFFFFFFF);
    const shadow = [
      Shadow(color: Color(0x73000000), blurRadius: 3, offset: Offset(0, 1)),
    ];
    final radius = BorderRadius.circular(KBondTile.radius);
    const medal = KBondTile.height * KBondTile.medal;
    return Semantics(
      button: onTap != null,
      label: '$title, $value',
      excludeSemantics: true,
      child: SizedBox(
        height: KBondTile.height,
        child: DecoratedBox(
          key: bodyKey,
          decoration: BoxDecoration(
            borderRadius: radius,
            // The pill's body: lighter on top and at the bottom edge, deeper
            // in the middle (sampled down a column of the owner's art).
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [art.top, art.middle, art.middle, art.bottom],
              stops: const [0, 0.42, 0.7, 1],
            ),
            border: Border.all(color: art.rimDark, width: KBondTile.rim),
            boxShadow: [
              BoxShadow(
                color: art.shade.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                // Deeper next to the medallion (the art's horizontal shade).
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: rtl
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        end: rtl ? Alignment.centerRight : Alignment.centerLeft,
                        colors: [
                          art.shade.withValues(alpha: 0),
                          art.shade.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                // The glossy band along the top (the art's light rim).
                Positioned(
                  top: KBondTile.rim,
                  left: KBondTile.rim + 2,
                  right: KBondTile.rim + 2,
                  height: KBondTile.height * 0.38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(KBondTile.radius - 2),
                        bottom: Radius.circular(KBondTile.radius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          art.rimLight.withValues(alpha: 0.75),
                          art.rimLight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: KBondTile.medalInset,
                  top: (KBondTile.height - medal) / 2,
                  width: medal,
                  height: medal,
                  child: Image.asset(
                    art.medal,
                    key: medalKey,
                    fit: BoxFit.contain,
                    // The owner's art, scaled as faithfully as possible.
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                ),
                PositionedDirectional(
                  start: KBondTile.medalInset + medal + KSpacing.xs,
                  end: KSpacing.sm,
                  top: KSpacing.xs,
                  bottom: KSpacing.xs,
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
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(borderRadius: radius, onTap: onTap),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // D283: a Kabso Team account shows no family, relationship, medals
        // or bag — only the team's identity.
        if (profile != null && profile.staff == null) ...[
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
