import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Me hub geometry (D163). Measured on the owner's reference at 430 × 932
/// lp (DPR 2.1465, an estimate from the Dynamic Island; spec in the D163
/// notes); sizes snap to the Kabso scale where it is within 1 lp.
abstract final class KMeHub {
  /// The top-end actions' row: D142's gap under the status bar, then
  /// 44-lp targets (the reference centres its icons 18 lp under the inset;
  /// the gap puts ours 14 lp lower, the photo stays where it is).
  static const double actionBox = 44;
  static const double actionIcon = 26;

  /// The photo's box (the reference's framed photo is 98.8 × 96 lp).
  static const double avatarBox = 96;
  static const double avatar = KSizes.avatarLg;

  /// The photo inside Kabso's heart frame (CP-021): a 68-lp photo makes a
  /// 98.6-lp frame, the reference's framed width.
  static const double framedAvatar = 68;

  /// From the actions to the photo, and from the photo to the name.
  static const double avatarTop = 7;
  static const double nameTop = 8;
  static const double nameSize = 18;

  /// From the name to the counts, and the counts' numbers.
  static const double statsTop = 42;
  static const double statSize = 20;

  /// The four cards: side inset 16, gap 8, 75.5 lp tall, 40-lp icon disc.
  static const double cardsTop = 14;
  static const double cardHeight = 76;
  static const double cardGap = KSpacing.sm;
  static const double cardRadius = KRadius.sm;
  static const double cardIcon = 40;
  static const double cardLabelSize = 12;

  /// The list: 50-lp rows, a 28-lp icon disc at the start inset, the title
  /// 54 lp from the edge, 8-lp grey bands with 8 lp above and below.
  static const double rowsTop = 16;
  static const double rowHeight = 50;
  static const double rowIcon = 28;
  static const double rowTitleGap = 10;
  static const double rowTitleSize = 16;
  static const double band = KSpacing.sm;

  /// The faded look of a feature that is not built yet (as Room Tools).
  static const double soonOpacity = 0.45;
}

/// The hub's destinations; tests and captures find them by [key].
enum MeHubItem {
  levels,
  vip,
  family,
  earn,
  creatorCenter,
  agency,
  eventCenter,
  wallet,
  bag,
  svip,
  taskCenter,
  medals,
  ranking,
  relationship,
  premium;

  Key get key => Key('meHub.item.$name');
}

/// The Me tab (D163, owner): the person's features in one place, in the
/// layout of the owner's reference (a Bigo-style "Me" page) with Kabso's
/// colours and icons. The photo and the name open the profile
/// ([AppRoutes.myProfile]); the counts open the follow lists. Every button
/// of a feature Kabso has opens its real screen; the ones not built yet are
/// shown faded with a "Soon" tag and do nothing (no stand-in screens).
/// D164: Wallet, Earn money and Creator Center open their real screens.
/// D166: Event Center, SVIP and Task Center too (CP-024 approved with
/// defaults); Purchase VIP waits for the owner's prices.
///
/// Data: `GET /me`, `GET /users/{username}` (counts, family, relationship,
/// medals), `GET /me/levels` and `GET /wallet/me`. The API has no friends
/// count, so the counts are Following and Fans (followers) only.
class MeHubScreen extends ConsumerWidget {
  const new({super.key});

  static const settingsKey = Key('meHub.settings');

  /// D168 (owner): the profile page (posts, reels, reposts, saved) opens
  /// from this icon beside Settings; the «المنشورات» row is gone.
  static const profileKey = Key('meHub.profile');
  static const notificationsKey = Key('meHub.notifications');
  static const avatarKey = Key('meHub.avatar');
  static const nameKey = Key('meHub.name');
  static const followingKey = Key('meHub.stat.following');
  static const fansKey = Key('meHub.stat.fans');
  static const cardsKey = Key('meHub.cards');
  static const soonKey = Key('meHub.soon');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final me = ref.watch(meProvider);
    final user = me.value ?? ref.watch(currentUserProvider);
    final username = user?.username;
    final statsLoad = username == null
        ? null
        : ref.watch(profileStatsProvider(username));
    final stats = statsLoad?.value;
    final coins = ref.watch(liveCoinsProvider).value;

    Future<void> refresh() async {
      try {
        ref
          ..invalidate(meProvider)
          ..invalidate(profileLevelsProvider(null))
          ..invalidate(liveCoinsProvider);
        if (username != null) ref.invalidate(profileStatsProvider(username));
        await ref.read(meProvider.future);
      } on Object catch (e) {
        if (context.mounted) {
          KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        }
      }
    }

    void push(String location) => unawaited(context.push(location));
    void openProfile() => push(AppRoutes.myProfile);

    final family = stats?.family;
    final cp = stats?.cp;
    final medals = stats?.medals;

    final cards = [
      _HubCard(
        item: MeHubItem.levels,
        icon: Icons.diamond_rounded,
        hue: p.primary,
        label: l10n.meHubLevels,
        onTap: () => push(AppRoutes.levels),
      ),
      _HubCard(
        item: MeHubItem.vip,
        icon: Icons.workspace_premium_rounded,
        hue: _Hues.gold,
        label: l10n.meHubVip,
      ),
      _HubCard(
        item: MeHubItem.family,
        icon: Icons.shield_rounded,
        hue: _Hues.orange,
        label: family?.name ?? l10n.liveUserFamily,
        onTap: () => push(
          family == null ? AppRoutes.families : AppRoutes.family(family.id),
        ),
      ),
      _HubCard(
        item: MeHubItem.earn,
        icon: Icons.payments_rounded,
        hue: _Hues.blue,
        label: l10n.meHubEarn,
        onTap: () => push(AppRoutes.walletCherries),
      ),
    ];

    final groups = <List<Widget>>[
      [
        _HubRow(
          item: MeHubItem.creatorCenter,
          icon: Icons.insights_rounded,
          hue: _Hues.teal,
          title: l10n.meHubCreatorCenter,
          onTap: () => push(AppRoutes.creatorCenter),
        ),
        // D179: host agencies (join by code; the agent's dashboard).
        _HubRow(
          item: MeHubItem.agency,
          icon: Icons.groups_rounded,
          hue: _Hues.pink,
          title: l10n.meHubAgency,
          onTap: () => push(AppRoutes.agency),
        ),
        _HubRow(
          item: MeHubItem.eventCenter,
          icon: Icons.campaign_rounded,
          hue: _Hues.teal,
          title: l10n.meHubEventCenter,
          onTap: () => push(AppRoutes.eventCenter),
        ),
      ],
      [
        // D164: the wallet screen (balance and coin history); recharge
        // stays "Soon" inside it (no purchases yet, B5).
        _HubRow(
          item: MeHubItem.wallet,
          icon: Icons.account_balance_wallet_rounded,
          hue: _Hues.pink,
          title: l10n.meHubWallet,
          value: coins == null ? null : KFormat.grouped(coins),
          valueLabel: coins == null
              ? null
              : l10n.meHubCoins(KFormat.grouped(coins)),
          valueArt: KabsoArt.coin,
          onTap: () => push(AppRoutes.wallet),
        ),
        _HubRow(
          item: MeHubItem.bag,
          icon: Icons.backpack_rounded,
          hue: _Hues.gold,
          title: l10n.meHubItemBag,
          onTap: () => push(AppRoutes.bag),
        ),
      ],
      [
        _HubRow(
          item: MeHubItem.svip,
          icon: Icons.military_tech_rounded,
          hue: _Hues.gold,
          title: l10n.meHubSvip,
          onTap: () => push(AppRoutes.svip),
        ),
        _HubRow(
          item: MeHubItem.taskCenter,
          icon: Icons.task_alt_rounded,
          hue: _Hues.gold,
          title: l10n.meHubTaskCenter,
          onTap: () => push(AppRoutes.taskCenter),
        ),
        _HubRow(
          item: MeHubItem.medals,
          icon: Icons.emoji_events_rounded,
          hue: _Hues.orange,
          title: l10n.medalsTitle,
          // Nothing until the catalogue is known (no "0 of 0").
          value: medals == null || medals.total == 0
              ? null
              : l10n.medalsOwned(medals.owned, medals.total),
          onTap: () => push(AppRoutes.medals),
        ),
        _HubRow(
          item: MeHubItem.ranking,
          icon: Icons.leaderboard_rounded,
          hue: _Hues.teal,
          title: l10n.meHubRanking,
          onTap: () => unawaited(showLiveRankings(context)),
        ),
      ],
      [
        _HubRow(
          item: MeHubItem.relationship,
          icon: Icons.favorite_rounded,
          hue: p.primary,
          title: l10n.cpTitle,
          value: cp == null
              ? null
              : (cp.partner.displayName.isEmpty
                    ? cp.partner.username
                    : cp.partner.displayName),
          onTap: () => push(cp != null ? AppRoutes.cpSpace : AppRoutes.cp),
        ),
        _HubRow(
          item: MeHubItem.premium,
          icon: Icons.alternate_email_rounded,
          hue: _Hues.blue,
          title: l10n.premiumTitle,
          onTap: () => push(AppRoutes.premium),
        ),
      ],
    ];

    final top = MediaQuery.paddingOf(context).top;
    final header = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(p.background, p.primary, 0.10)!,
            Color.lerp(p.background, p.primary, 0.04)!,
            p.background,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      // D142: the actions start the status bar gap under the inset.
      child: KTopSafeArea(
        child: Column(
          children: [
            SizedBox(
              height: KMeHub.actionBox,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionIcon(
                    key: profileKey,
                    asset: AppIcons.grid,
                    tooltip: l10n.meHubMyProfile,
                    onTap: openProfile,
                    labelled: true,
                  ),
                  _ActionIcon(
                    key: settingsKey,
                    asset: AppIcons.settings,
                    tooltip: l10n.settingsTitle,
                    onTap: () => push(AppRoutes.settings),
                  ),
                  _ActionIcon(
                    key: notificationsKey,
                    asset: AppIcons.bell,
                    tooltip: l10n.notificationsTitle,
                    onTap: () => push(AppRoutes.notifications),
                  ),
                  const SizedBox(width: KSpacing.xxs),
                ],
              ),
            ),
            const SizedBox(height: KMeHub.avatarTop),
            Semantics(
              key: avatarKey,
              button: true,
              label: l10n.meHubOpenProfile,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openProfile,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: KMeHub.avatarBox,
                  ),
                  child: Center(
                    child: cpWearsSpecialFrame(cp)
                        ? CpSpecialFrameAvatar(
                            width: CpSpecialFrameAvatar.widthForAvatar(
                              KMeHub.framedAvatar,
                            ),
                            name: user?.displayName ?? '',
                            imageUrl: user?.avatarUrl,
                          )
                        : KAvatar(
                            name: user?.displayName ?? '',
                            imageUrl: user?.avatarUrl,
                            size: KMeHub.avatar,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KMeHub.nameTop),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: KSpacing.sm,
                runSpacing: KSpacing.xs,
                children: [
                  if (user == null)
                    const KSkeleton(width: 120)
                  else
                    Semantics(
                      button: true,
                      hint: l10n.meHubOpenProfile,
                      child: GestureDetector(
                        key: nameKey,
                        onTap: openProfile,
                        child: Text(
                          user.displayName.isEmpty
                              ? user.username
                              : user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.textStyles.title.copyWith(
                            color: p.textPrimary,
                            fontSize: KMeHub.nameSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // D163: the level badge beside the name.
                  ProfileLevels(
                    onOpen: () => push(AppRoutes.levels),
                    padding: EdgeInsetsDirectional.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: KMeHub.statsTop),
            Row(
              children: [
                _Stat(
                  key: followingKey,
                  value: stats?.followingCount,
                  failed: statsLoad?.hasError ?? false,
                  label: l10n.profileFollowingCount,
                  hint: l10n.profileOpenFollowing,
                  onTap: username == null
                      ? null
                      : () => push(
                          AppRoutes.userFollows(username, following: true),
                        ),
                ),
                _Stat(
                  key: fansKey,
                  value: stats?.followerCount,
                  failed: statsLoad?.hasError ?? false,
                  label: l10n.meHubFans,
                  hint: l10n.profileOpenFollowers,
                  onTap: username == null
                      ? null
                      : () => push(AppRoutes.userFollows(username)),
                ),
              ],
            ),
            const SizedBox(height: KMeHub.cardsTop),
            Padding(
              key: cardsKey,
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              // Equal heights when a large text size grows one card.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, card) in cards.indexed) ...[
                      if (i > 0) const SizedBox(width: KMeHub.cardGap),
                      Expanded(child: card),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: p.background,
      body: RefreshIndicator(
        onRefresh: refresh,
        edgeOffset: top,
        child: ListView(
          padding: const EdgeInsets.only(bottom: KSpacing.lg),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header,
            const SizedBox(height: KMeHub.rowsTop),
            for (final (i, group) in groups.indexed) ...[
              if (i > 0) ...[
                const SizedBox(height: KMeHub.band),
                ColoredBox(
                  color: p.surface,
                  child: const SizedBox(height: KMeHub.band),
                ),
                const SizedBox(height: KMeHub.band),
              ],
              ...group,
            ],
          ],
        ),
      ),
    );
  }
}

/// Card and icon hues: Kabso's palette tones (gold = `KBrandColors.gold`,
/// the rest the status tones), chosen per feature like the reference's four
/// tinted cards.
abstract final class _Hues {
  static const gold = Color(0xFFE0A21B);
  static const orange = Color(0xFFF5A623);
  static const blue = Color(0xFF4DA3FF);
  static const teal = Color(0xFF14B8A6);
  static const pink = Color(0xFFFF3B6B);
}

class _ActionIcon extends StatelessWidget {
  const new({
    required this.asset,
    required this.tooltip,
    required this.onTap,
    super.key,
    this.labelled = false,
  });

  final String asset;
  final String tooltip;
  final VoidCallback onTap;

  /// D168: screen readers get [tooltip] as the button's label (once, not
  /// also as a tooltip); the long-press tooltip still shows.
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: KMeHub.actionBox,
        height: KMeHub.actionBox,
      ),
      icon: AppIcon(
        asset,
        size: KMeHub.actionIcon,
        color: context.palette.textPrimary,
      ),
    );
    if (!labelled) return button;
    return Semantics(
      button: true,
      enabled: true,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: button,
    );
  }
}

class _Stat extends StatelessWidget {
  const new({
    required this.value,
    required this.failed,
    required this.label,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final int? value;
  final bool failed;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final value = this.value;
    return Expanded(
      child: Semantics(
        button: onTap != null,
        hint: onTap == null ? null : hint,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
            child: Column(
              children: [
                if (value == null && !failed)
                  const KSkeleton(width: KSpacing.xl, height: KMeHub.statSize)
                else
                  Text(
                    value == null ? '–' : KFormat.compact(value, context.l10n),
                    maxLines: 1,
                    style: t.title.copyWith(
                      color: p.textPrimary,
                      fontSize: KMeHub.statSize,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: p.textTertiary,
                    fontWeight: FontWeight.w400,
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

/// The small "Soon" tag of a feature that is not built yet (also on the
/// wallet's recharge and the earnings' withdraw buttons, D164).
class MeHubSoonTag extends StatelessWidget {
  const new({super.key = MeHubScreen.soonKey});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.xs + KSpacing.xxs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: p.surfaceOverlay,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Text(
        context.l10n.liveSoon,
        maxLines: 1,
        style: context.textStyles.caption.copyWith(
          color: p.textSecondary,
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One of the four cards under the counts: an icon disc over a label, on a
/// tint of [hue]. Without [onTap] the feature is not built: faded, "Soon".
class _HubCard extends StatelessWidget {
  const new({
    required this.item,
    required this.icon,
    required this.hue,
    required this.label,
    this.onTap,
  });

  final MeHubItem item;
  final IconData icon;
  final Color hue;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final soon = onTap == null;
    final face = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(hue, const Color(0xFFFFFFFF), 0.25)!, hue],
            ),
          ),
          child: SizedBox.square(
            dimension: KMeHub.cardIcon,
            child: Icon(icon, size: 24, color: const Color(0xFFFFFFFF)),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.xs,
            0,
            KSpacing.xs,
            KSpacing.xs,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textStyles.label.copyWith(
              color: Color.lerp(hue, p.textPrimary, 0.25),
              fontSize: KMeHub.cardLabelSize,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      key: item.key,
      button: true,
      enabled: !soon,
      label: soon ? context.l10n.meHubSoonItem(label) : label,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(hue.withValues(alpha: 0.12), p.background),
        borderRadius: BorderRadius.circular(KMeHub.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KMeHub.cardRadius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KMeHub.cardHeight),
            child: soon
                ? Stack(
                    children: [
                      Opacity(opacity: KMeHub.soonOpacity, child: face),
                      const PositionedDirectional(
                        top: KSpacing.xs,
                        end: KSpacing.xs,
                        child: MeHubSoonTag(),
                      ),
                    ],
                  )
                : face,
          ),
        ),
      ),
    );
  }
}

/// One row of the list: a round tinted icon, the title, an optional value
/// and a chevron. Without [onTap] the feature is not built: faded, "Soon"
/// in place of the chevron (a real [value], like the coin balance, still
/// shows).
class _HubRow extends StatelessWidget {
  const new({
    required this.item,
    required this.icon,
    required this.hue,
    required this.title,
    this.value,
    this.valueLabel,
    this.valueArt,
    this.onTap,
  });

  final MeHubItem item;
  final IconData icon;
  final Color hue;
  final String title;
  final String? value;
  final String? valueLabel;
  final KabsoArt? valueArt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final soon = onTap == null;
    final value = this.value;
    final lead = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hue.withValues(alpha: 0.18),
          ),
          child: SizedBox.square(
            dimension: KMeHub.rowIcon,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: hue),
                child: SizedBox.square(
                  dimension: KMeHub.rowIcon - 6,
                  child: Icon(icon, size: 14, color: const Color(0xFFFFFFFF)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: KMeHub.rowTitleGap),
      ],
    );
    final label = [
      if (soon) context.l10n.meHubSoonItem(title) else title,
      ?(valueLabel ?? value),
    ].join(', ');
    return Semantics(
      key: item.key,
      button: true,
      enabled: !soon,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: KMeHub.rowHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: KSpacing.lg,
              end: KSpacing.md,
            ),
            child: Row(
              children: [
                Opacity(opacity: soon ? KMeHub.soonOpacity : 1, child: lead),
                Expanded(
                  child: Opacity(
                    opacity: soon ? KMeHub.soonOpacity : 1,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(
                        color: p.textPrimary,
                        fontSize: KMeHub.rowTitleSize,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: KSpacing.sm),
                  if (valueArt case final art?) ...[
                    KabsoArtIcon(art, size: KMetrics.iconSm),
                    const SizedBox(width: KSpacing.xxs),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(color: p.textTertiary),
                    ),
                  ),
                ],
                const SizedBox(width: KSpacing.xs),
                if (soon)
                  const MeHubSoonTag()
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: KMetrics.iconMd,
                    color: p.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
