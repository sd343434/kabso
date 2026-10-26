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

  /// Your own relationship page (the couple, or requests).
  openCp,

  /// Someone else's partner: their profile.
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
    BondTap.openCp => () => go(AppRoutes.cp),
    BondTap.openPartner => () => go(
      AppRoutes.userProfile(profile.cp!.partner.username),
    ),
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
/// small tiles under the header: each says what exists and opens it.
class ProfileBondsRow extends ConsumerWidget {
  const new({required this.profile, super.key});

  final PublicProfile profile;

  static const familyKey = Key('profile.bonds.family');
  static const cpKey = Key('profile.bonds.cp');
  static const medalsKey = Key('profile.bonds.medals');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final signedIn = ref.watch(currentUserProvider) != null;
    final family = profile.family;
    final cp = profile.cp;
    final cpAction = cpTap(profile, signedIn: signedIn);
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Tile(
                key: familyKey,
                icon: 'assets/leaderboard/rank_shield_1.webp',
                title: l10n.liveUserFamily,
                value: family == null
                    ? l10n.liveUserNone
                    : l10n.familyBoxValue(family.name, family.level),
                onTap: bondAction(context, ref, profile, familyTap(profile)),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: _Tile(
                key: cpKey,
                icon: 'assets/leaderboard/heart.webp',
                title: l10n.liveUserCp,
                value: cp != null
                    ? l10n.cpBoxValue(
                        cp.partner.displayName.isEmpty
                            ? cp.partner.username
                            : cp.partner.displayName,
                        cp.levelName,
                      )
                    : cpAction == BondTap.sendCp
                    ? l10n.cpSendShort
                    : l10n.liveUserNone,
                onTap: bondAction(context, ref, profile, cpAction),
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: _Tile(
                key: medalsKey,
                iconData: Icons.military_tech_rounded,
                title: l10n.liveUserMedals,
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
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
    this.icon,
    this.iconData,
  });

  final String title;
  final String value;
  final String? icon;
  final IconData? iconData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Semantics(
      button: onTap != null,
      label: '$title, $value',
      excludeSemantics: true,
      child: Material(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.sm),
            child: Row(
              children: [
                if (icon case final icon?)
                  Image.asset(
                    icon,
                    width: 24,
                    height: 24,
                    excludeFromSemantics: true,
                  )
                else
                  Icon(iconData, size: 24, color: const Color(0xFFB8860B)),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
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

/// The profile header's block under the name (D72, CP-018): the level
/// badges ([levels]), the medals [profile] chose to show (nothing when none
/// are chosen) and the family, relationship and medals tiles. Only the
/// levels while [profile] is not loaded.
class ProfileBondsBlock extends StatelessWidget {
  const new({required this.levels, required this.profile, super.key});

  final Widget levels;
  final PublicProfile? profile;

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
        ],
      ],
    );
  }
}
