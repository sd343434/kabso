import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/svip` (D166): SVIP in the layout of the owner's reference, in Kabso's
/// dark theme with gold — the person and their status, the SVIP emblem (a
/// Kabso composition until the owner's art), the tier track, what is left
/// to spend, the perks (each locked or unlocked, and «قريباً» until it is
/// built) and a sticky bar with a gold button to the lives (gifts). SVIP is
/// earned by sending gifts, never bought (`GET /me/svip`).
class SvipScreen extends ConsumerWidget {
  const new({super.key});

  static const statusKey = Key('svip.status');
  static const emblemKey = Key('svip.emblem');
  static const trackKey = Key('svip.track');
  static const lockKey = Key('svip.lock');
  static const ctaKey = Key('svip.cta');
  static const rulesKey = Key('svip.rules');
  static const barKey = Key('svip.bar');

  static Key nodeKey(int tier) => Key('svip.node.$tier');
  static Key perkKey(String code) => Key('svip.perk.$code');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    return Theme(
      data: buildAppTheme(brightness: Brightness.dark, locale: locale),
      child: const _SvipPage(),
    );
  }
}

class _SvipPage extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final svip = ref.watch(mySvipProvider);
    final status = svip.value;

    Future<void> refresh() async {
      ref.invalidate(mySvipProvider);
      try {
        await ref.read(mySvipProvider.future);
      } on Object {
        // The page shows the failure with a retry.
      }
    }

    final body = switch (svip) {
      AsyncValue(value: final s?) => [
        _Header(status: s),
        const SizedBox(height: KSpacing.lg),
        _Emblem(tier: s.tier),
        const SizedBox(height: KSpacing.md),
        _Track(status: s),
        const SizedBox(height: KSpacing.md),
        _LockLine(status: s),
        const SizedBox(height: KSpacing.xl),
        _Perks(perks: s.perks),
      ],
      AsyncValue(:final error?, isLoading: false) => [
        const SizedBox(height: KSpacing.xxl),
        FailureErrorState(
          title: l10n.svipLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(mySvipProvider),
          compact: true,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(KSpacing.xxxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };

    return Scaffold(
      backgroundColor: p.background,
      extendBodyBehindAppBar: true,
      appBar: KAppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        centerTitle: true,
        title: Text(
          l10n.meHubSvip,
          style: context.textStyles.title.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            key: SvipScreen.rulesKey,
            tooltip: l10n.svipRules,
            onPressed: status == null
                ? null
                : () => unawaited(_showRules(context, status)),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                KBrandColors.gold.withValues(alpha: 0.16),
                p.surfaceRaised,
              ),
              p.background,
              p.background,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.xl,
              ),
              children: body,
            ),
          ),
        ),
      ),
      bottomNavigationBar: status == null ? null : _BottomBar(status: status),
    );
  }

  Future<void> _showRules(BuildContext context, SvipStatus s) {
    final l10n = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final p = context.palette;
        final t = context.textStyles;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.svipRules,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  l10n.svipRulesBody('${s.windowDays}'),
                  style: t.body.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.sm),
                for (final (i, threshold) in s.thresholds.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.xxs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.svipTier('${i + 1}'),
                            style: t.bodyStrong.copyWith(
                              color: KBrandColors.gold,
                            ),
                          ),
                        ),
                        CoinAmount(threshold),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const new({required this.status});

  final SvipStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final user = ref.watch(currentUserProvider);
    final name = user == null
        ? ''
        : (user.displayName.isEmpty ? user.username : user.displayName);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final expires = status.expiresAt;
    final line = status.tier == 0 || expires == null
        ? l10n.svipNotYet
        : l10n.svipUntil(
            l10n.svipTier('${status.tier}'),
            KFormat.date(expires, localeTag),
          );
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: KBrandColors.gold, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: KAvatar(name: name, imageUrl: user?.avatarUrl, size: 56),
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.title.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                line,
                key: SvipScreen.statusKey,
                style: t.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The SVIP emblem: a Kabso composition (gold ring, the brand red, the
/// tier) — no third-party art. Owner art can replace it.
class _Emblem extends StatelessWidget {
  const new({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = tier > 0;
    return Semantics(
      key: SvipScreen.emblemKey,
      label: active ? l10n.svipTier('$tier') : l10n.svipNotYet,
      excludeSemantics: true,
      child: Center(
        child: Column(
          children: [
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    KBrandColors.gold,
                    Color(0xFFFFE7A3),
                    Color(0xFFB7811A),
                    KBrandColors.gold,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: KBrandColors.gold.withValues(
                      alpha: active ? 0.45 : 0.18,
                    ),
                    blurRadius: 36,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: active
                        ? KBrandColors.gradientLive
                        : const [Color(0xFF34343D), Color(0xFF16161A)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 56,
                        color: KBrandColors.gold,
                      ),
                      Text(
                        active ? 'SVIP $tier' : 'SVIP',
                        textDirection: TextDirection.ltr,
                        style: context.textStyles.title.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tier track: a node per tier (0 and SVIP 1…n), the reached ones in
/// gold, the caller's own one enlarged.
class _Track extends StatelessWidget {
  const new({required this.status});

  final SvipStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final count = status.thresholds.length;
    return Semantics(
      key: SvipScreen.trackKey,
      label: l10n.svipTrack('${status.tier}', '$count'),
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 12,
              right: 12,
              top: 15,
              child: Container(height: 2, color: p.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var tier = 0; tier <= count; tier++)
                  Column(
                    key: SvipScreen.nodeKey(tier),
                    children: [
                      Transform.rotate(
                        angle: 0.785398,
                        child: Container(
                          width: tier == status.tier ? 18 : 12,
                          height: tier == status.tier ? 18 : 12,
                          margin: EdgeInsets.all(tier == status.tier ? 6 : 9),
                          decoration: BoxDecoration(
                            color: tier <= status.tier
                                ? KBrandColors.gold
                                : p.surfaceOverlay,
                            border: Border.all(
                              color: tier <= status.tier
                                  ? const Color(0xFFFFE7A3)
                                  : p.border,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        tier == 0 ? '0' : 'SVIP $tier',
                        textDirection: TextDirection.ltr,
                        style: context.textStyles.caption.copyWith(
                          color: tier <= status.tier
                              ? KBrandColors.gold
                              : p.textTertiary,
                          fontWeight: tier == status.tier
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «مقفل» / the next step: what is left to spend within the window.
class _LockLine extends StatelessWidget {
  const new({required this.status});

  final SvipStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final next = status.nextTier;
    final toNext = status.coinsToNext;
    final text = next == null || toNext == null
        ? l10n.svipTop
        : l10n.svipSpendToUpgrade(
            KFormat.grouped(status.thresholds[next - 1]),
            '${status.windowDays}',
          );
    return Column(
      key: SvipScreen.lockKey,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KSpacing.xs,
          children: [
            if (status.tier == 0)
              ProgramTag(
                l10n.svipLocked,
                color: p.surfaceOverlay,
                onColor: p.textSecondary,
              ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: p.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.svipSpent(
            KFormat.grouped(status.spentCoins),
            '${status.windowDays}',
          ),
          style: context.textStyles.caption.copyWith(color: p.textTertiary),
        ),
      ],
    );
  }
}

class _Perks extends StatelessWidget {
  const new({required this.perks});

  final List<SvipPerk> perks;

  static IconData _icon(String code) => switch (code) {
    'BADGE' => Icons.verified_rounded,
    'AVATAR_FRAME' => Icons.account_circle_rounded,
    'CHAT_NAME_COLOR' => Icons.format_color_text_rounded,
    'ENTRY_BANNER' => Icons.flag_rounded,
    'ENTRY_EFFECT' => Icons.auto_awesome_rounded,
    'DAILY_BULLET' => Icons.campaign_rounded,
    'VIEWER_LIST_PRIORITY' => Icons.format_list_numbered_rounded,
    'MONTHLY_GIFT' => Icons.redeem_rounded,
    _ => Icons.star_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.svipPerksTitle,
            style: t.headline.copyWith(color: KBrandColors.gold),
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.svipPerksSoon,
          style: t.caption.copyWith(color: p.textTertiary),
        ),
        const SizedBox(height: KSpacing.md),
        for (var i = 0; i < perks.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _PerkCard(perk: perks[i], icon: _icon),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: i + 1 < perks.length
                        ? _PerkCard(perk: perks[i + 1], icon: _icon)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PerkCard extends StatelessWidget {
  const new({required this.perk, required this.icon});

  final SvipPerk perk;
  final IconData Function(String code) icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final state = !perk.available
        ? l10n.liveSoon
        : perk.unlocked
        ? l10n.svipUnlocked
        : l10n.svipTier('${perk.unlockTier}');
    return Semantics(
      key: SvipScreen.perkKey(perk.code),
      label: [
        perk.name,
        if (perk.unlocked) l10n.svipUnlocked else l10n.svipLocked,
        l10n.svipTier('${perk.unlockTier}'),
        if (!perk.available) l10n.liveSoon,
      ].join('، '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.surfaceRaised, p.surface],
          ),
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: perk.unlocked
                ? KBrandColors.gold.withValues(alpha: 0.7)
                : p.border,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon(perk.code),
                  size: 40,
                  color: perk.unlocked ? KBrandColors.gold : p.textTertiary,
                ),
                if (!perk.unlocked)
                  PositionedDirectional(
                    end: -6,
                    bottom: -4,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: p.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              perk.name,
              textAlign: TextAlign.center,
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              state,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(
                color: perk.unlocked ? KBrandColors.gold : p.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticky bar: what is left to spend for the next tier and the gold
/// button to the lives (gifts are sent there). No purchase.
class _BottomBar extends StatelessWidget {
  const new({required this.status});

  final SvipStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final next = status.nextTier;
    final toNext = status.coinsToNext;
    final text = next == null || toNext == null
        ? l10n.svipTop
        : l10n.svipSpendMore(KFormat.grouped(toNext), l10n.svipTier('$next'));
    return DecoratedBox(
      key: SvipScreen.barKey,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.body.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              Semantics(
                button: true,
                label: l10n.svipCta,
                excludeSemantics: true,
                child: Material(
                  key: SvipScreen.ctaKey,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFE7A3), KBrandColors.gold],
                      ),
                    ),
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.home),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.lg,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              l10n.svipCta,
                              style: context.textStyles.bodyStrong.copyWith(
                                color: KStatusColors.onStatus,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
