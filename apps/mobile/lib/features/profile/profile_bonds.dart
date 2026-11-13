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
///
/// D292 (owner, «أ»): outline-only, like the tag chips — no painted body,
/// a thin border in each bond's accent (the art's darker rim colour), the
/// title and value in the theme's text colours; the owner's three shields
/// carry «العائلة» / «العلاقة» / «الميداليات» on their ribbons, so the tiles
/// show only the value, a little larger (the screen reader still says the
/// bond's name).
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
  static const Key ribbonKey = _BondTile.ribbonKey;
  static const Key valueKey = _BondTile.valueKey;

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
  /// D292 (owner's art, 2026-11-06: «اجعلها أيقونة العائلة واكتب العائلة في
  /// الشريط البنفسجي، وفاميلي في حال كانت لغة إنجليزية»): the gold-and-purple
  /// family shield; «العائلة» / "Family" is written live on its empty
  /// purple ribbon ([ribbon]).
  family(
    'assets/profile/bonds/family_shield.webp',
    aspect: 512 / 445,
    ribbon: Rect.fromLTRB(0.273, 0.674, 0.727, 0.775),
    ribbonShadow: Color(0xB3280040),
    top: Color(0xFFFFDB1D),
    middle: Color(0xFFFCC302),
    bottom: Color(0xFFFBCE09),
    shade: Color(0xFFF7A902),
    rimLight: Color(0xFFFBF8C5),
    rimDark: Color(0xFFF4B50B),
  ),

  /// D292 (owner's art, 2026-11-06: «اجعلها أيقونة العلاقة، واكتب العلاقة في
  /// الشريط الأحمر … لا تُعِد كتابتها بجانب الأيقونة، فقط داخل الشريط»): the
  /// heart with the crown and the two rings; «العلاقة» / "Couple" is
  /// written live on its empty red ribbon (measured on `couple_shield.webp`,
  /// 512 × 443: the red band x 110–400, y 302–345, under its top gem).
  couple(
    'assets/profile/bonds/couple_shield.webp',
    aspect: 512 / 443,
    ribbon: Rect.fromLTRB(0.215, 0.682, 0.781, 0.779),
    ribbonShadow: Color(0xB3400000),
    top: Color(0xFFFC7516),
    middle: Color(0xFFFA5101),
    bottom: Color(0xFFFE6205),
    shade: Color(0xFFE83C00),
    rimLight: Color(0xFFFDEE7C),
    rimDark: Color(0xFFF94E06),
  ),

  /// D292 (owner's art, 2026-11-06: «اجعلها أيقونة الميداليات، واكتب
  /// الميداليات في الشريط الأخضر … لا تُعِد كتابتها بجانب الأيقونة»): the
  /// green-and-gold shield with the three medals; «الميداليات» / "Medals" is
  /// written live on its empty green ribbon (measured on
  /// `medals_shield.webp`, 512 × 473: the green band x 120–392, y 340–372,
  /// under its top gem). The tile's border is the ribbon's green (sampled
  /// #036B13 at (300, 355)), replacing the violet of the old pill.
  medals(
    'assets/profile/bonds/medals_shield.webp',
    top: Color(0xFFD054F9),
    middle: Color(0xFF982FF5),
    bottom: Color(0xFFC149FC),
    shade: Color(0xFF751EE8),
    rimLight: Color(0xFFD8C2F4),
    rimDark: Color(0xFF036B13),
    aspect: 512 / 473,
    ribbon: Rect.fromLTRB(0.234, 0.719, 0.766, 0.786),
    ribbonShadow: Color(0xB3002A08),
  );

  new(
    this.medal, {
    required this.top,
    required this.middle,
    required this.bottom,
    required this.shade,
    required this.rimLight,
    required this.rimDark,
    this.aspect = 1,
    this.ribbon,
    this.ribbonShadow = const Color(0xB3000000),
  });

  final String medal;

  /// The art's width ÷ height (the medallions are square).
  final double aspect;

  /// D292: the empty ribbon the bond's name is written on, as fractions of
  /// the art's width and height (measured on `family_shield.webp`, 512 ×
  /// 445: the purple band between the gold edges, x 140–372, y 300–345 —
  /// clear of the gems above and below its middle). Null: no label.
  final Rect? ribbon;

  /// The ribbon label's soft shadow (a dark shade of the ribbon).
  final Color ribbonShadow;

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

  /// D292: the bond's name on the art's ribbon (the family shield).
  static const Key ribbonKey = ValueKey('profile.bonds.ribbon');

  /// The value line (tests).
  static const Key valueKey = ValueKey('profile.bonds.value');

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final p = context.palette;
    final radius = BorderRadius.circular(KBondTile.radius);
    const medal = KBondTile.height * KBondTile.medal;
    final medalWidth = medal * art.aspect;
    final ribbon = art.ribbon;
    return Semantics(
      button: onTap != null,
      label: '$title, $value',
      excludeSemantics: true,
      child: SizedBox(
        height: KBondTile.height,
        // D292 (owner, «أ»): outline-only like the tag chips — no fill, a
        // thin border in the bond's own accent (the art's darker rim
        // colour: amber, orange, violet), in light and dark.
        child: DecoratedBox(
          key: bodyKey,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: art.rimDark, width: KBondTile.rim),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                PositionedDirectional(
                  start: KBondTile.medalInset,
                  top: (KBondTile.height - medal) / 2,
                  width: medalWidth,
                  height: medal,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        art.medal,
                        key: medalKey,
                        fit: BoxFit.contain,
                        // The owner's art, scaled as faithfully as possible.
                        filterQuality: FilterQuality.high,
                        excludeFromSemantics: true,
                      ),
                      // D292: the bond's name on the art's ribbon (absolute
                      // offsets: the art is never mirrored).
                      if (ribbon != null)
                        Positioned(
                          key: ribbonKey,
                          left: ribbon.left * medalWidth,
                          top: ribbon.top * medal,
                          width: ribbon.width * medalWidth,
                          height: ribbon.height * medal,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              maxLines: 1,
                              softWrap: false,
                              textScaler: TextScaler.noScaling,
                              style: t.label.copyWith(
                                color: const Color(0xFFFFE7A3),
                                fontSize: ribbon.height * medal * 0.9,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: 0,
                                shadows: [
                                  Shadow(
                                    color: art.ribbonShadow,
                                    blurRadius: 1.5,
                                    offset: const Offset(0, 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: KBondTile.medalInset + medalWidth + KSpacing.xs,
                  end: KSpacing.sm,
                  top: KSpacing.xs,
                  bottom: KSpacing.xs,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: KBondCard.maxTextScale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // D292 (owner, «أ»): a shield that carries the
                        // name on its ribbon shows no title beside it.
                        if (ribbon == null)
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
                                  color: p.textPrimary,
                                  fontSize: KBondCard.titleFont,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                        if (ribbon == null)
                          Flexible(
                            child: Text(
                              value,
                              key: valueKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.copyWith(
                                color: p.textSecondary,
                                fontSize: KBondCard.valueFont - 1,
                                height: 1.15,
                              ),
                            ),
                          )
                        else
                          // Alone: a little more prominent, on one line
                          // (shrinks to fit rather than break «لا يوجد»).
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                value,
                                key: valueKey,
                                maxLines: 1,
                                softWrap: false,
                                style: t.label.copyWith(
                                  color: p.textPrimary,
                                  fontSize: KBondCard.titleFont,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                ),
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
    this.showMedals = true,
  });

  final Widget levels;

  /// Whether the medals [profile] chose to show are drawn here. D292: the
  /// profile header draws them under the name instead.
  final bool showMedals;
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
          if (showMedals && profile.medals.showcase.isNotEmpty)
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
