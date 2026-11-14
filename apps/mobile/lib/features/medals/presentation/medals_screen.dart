import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/medals/application/medals_providers.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/medals/presentation/medal_stage.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/medals` (CP-018, §10.21; redesigned D291, §10.104.6): over the owner's
/// light or dark page background (the app theme), the stage — the owner's
/// pedestal with the medals the caller wears (the showcase, ≤ 5) or the empty
/// pedestal, the tabs «الإنجازات» / «النشاط» and a two-column grid of medal
/// cards (the art, the name, «لم تُحصَّل» / «المستوى n»
/// with the progress / «مرتدية»); a card opens [MedalDetailSheet] with every
/// level and wear / take off. `/users/:username/medals` ([username]): that
/// user's earned medals as cards with their levels, newest first.
///
/// The layout follows the idea of a third-party reference the owner shared
/// (kept out of git, D40); the art is the owner's own (2026-11-06,
/// `assets/medals/PROVENANCE.md`): pedestal, card frame, backgrounds.
class MedalsScreen extends ConsumerWidget {
  const new({super.key, this.username});

  /// Another user; null = the caller.
  final String? username;

  static const chooseKey = Key('medals.choose');
  static const gridKey = Key('medals.grid');
  static const tabsKey = Key('medals.tabs');

  static Key medalKey(String code) => Key('medals.medal.$code');
  static Key tabKey(MedalCategory c) => Key('medals.tab.${c.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = this.username;
    if (username == null) return const _MyMedals();
    final l10n = context.l10n;
    final look = MedalsLook.of(context);
    final load = ref.watch(userMedalsProvider(username));
    final body = switch (load) {
      AsyncValue(:final value?) when value.data.isEmpty => Center(
        child: KEmptyState(
          icon: Icons.military_tech_outlined,
          title: l10n.medalsEmptyTitle,
          message: l10n.medalsEmptyBody,
        ),
      ),
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: () => ref.refresh(userMedalsProvider(username).future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.md,
                KSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.medalsOwned(value.owned, value.total),
                  textAlign: TextAlign.center,
                  style: context.textStyles.title.copyWith(color: look.text),
                ),
              ),
            ),
            _MedalGrid(
              cards: [
                for (final m in value.data)
                  MedalCardData(
                    code: m.code,
                    name: m.name,
                    description: m.description,
                    iconKey: m.iconKey,
                    iconUrl: m.iconUrl,
                    iconAsset: m.iconAsset,
                    level: m.level < 1 ? 1 : m.level,
                    maxLevel: m.maxLevel,
                    awardedAt: m.awardedAt,
                  ),
              ],
              onTap: (card) => showMedalSheet(context, card: card),
            ),
          ],
        ),
      ),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.medalsLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(userMedalsProvider(username)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return MedalsScaffold(title: l10n.medalsTitle, body: body);
  }
}

/// The medals pages' frame (D291): the app bar over the owner's page
/// background for the app theme (cover, top-aligned so the arches stay at
/// the top; it does not scroll).
class MedalsScaffold extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    super.key,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  static const backgroundKey = Key('medals.background');

  @override
  Widget build(BuildContext context) {
    final look = MedalsLook.of(context);
    // The background sits behind the whole scaffold (under the status bar
    // and the transparent app bar too); the content scrolls below the bar.
    return ColoredBox(
      color: look.base,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              look.background,
              key: backgroundKey,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: KAppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: look.text,
              scrolledUnderElevation: 0,
              systemOverlayStyle: look.overlay,
              centerTitle: true,
              title: Text(
                title,
                style: context.textStyles.title.copyWith(color: look.text),
              ),
              actions: actions,
            ),
            body: body,
          ),
        ],
      ),
    );
  }
}

/// What a medal card and its sheet show, for the caller's catalogue and for
/// another user's list alike.
@immutable
class MedalCardData {
  const new({
    required this.code,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.level,
    required this.maxLevel,
    this.iconUrl,
    this.iconAsset,
    this.awardedAt,
    this.worn = false,
    this.progress,
    this.levels = const [],
    this.metric,
    this.eligible = true,
  });

  /// From `GET /medals`.
  factory fromMedal(Medal m) => MedalCardData(
    code: m.code,
    name: m.shownName,
    description: m.description,
    iconKey: m.iconKey,
    iconUrl: m.shownIconUrl,
    iconAsset: m.shownIconAsset,
    level: m.currentLevel,
    maxLevel: m.maxLevel < 1 ? 1 : m.maxLevel,
    awardedAt: m.awardedAt,
    worn: m.worn,
    progress: m.progress,
    levels: m.levels,
    metric: m.metric,
    eligible: m.eligible,
  );

  final String code;
  final String name;
  final String description;
  final String iconKey;
  final String? iconUrl;

  /// D291: the shown level's bundled art key.
  final String? iconAsset;

  /// 0 = not earned.
  final int level;
  final int maxLevel;
  final DateTime? awardedAt;
  final bool worn;

  /// The caller's own medals only.
  final MedalProgress? progress;
  final List<MedalLevel> levels;
  final String? metric;

  /// D300: false for a creators-only medal when the caller is not a content
  /// creator now (no progress; a level reached is kept).
  final bool eligible;

  bool get locked => level == 0;

  /// D300: a multi-requirement medal («مدرسة المحتوى»): its levels need
  /// several numbers together.
  bool get multiRequirement =>
      metric == 'ALL_REQUIREMENTS' ||
      levels.any((l) => l.requirements.isNotEmpty);

  /// D300: the caller's requirements toward the next level, in the app's
  /// order (followers, likes, views); unknown metrics are skipped.
  List<MedalRequirementProgress> get requirements => [
    for (final metric in medalRequirementMetrics)
      ...?progress?.requirements.where((r) => r.metric == metric),
  ];

  /// D300: the requirement furthest from its target (the card's bar: the
  /// lowest of the three ratios), or null at the top / without any.
  MedalRequirementProgress? get weakestRequirement {
    MedalRequirementProgress? weakest;
    var lowest = double.infinity;
    for (final r in requirements) {
      final next = r.next;
      if (next == null || next <= 0) continue;
      final ratio = r.value / next;
      if (ratio < lowest) {
        lowest = ratio;
        weakest = r;
      }
    }
    return weakest;
  }
}

/// D300: the name of a requirement metric («المتابعون» …), or null for one
/// this app does not know.
String? medalRequirementName(AppLocalizations l10n, String metric) =>
    switch (metric) {
      'CREATOR_FOLLOWERS' => l10n.medalsReqFollowers,
      'CREATOR_LIKES' => l10n.medalsReqLikes,
      'CREATOR_VIEWS' => l10n.medalsReqViews,
      _ => null,
    };

class _MyMedals extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MyMedals> createState() => _MyMedalsState();
}

class _MyMedalsState extends ConsumerState<_MyMedals> {
  MedalCategory _tab = MedalCategory.achievement;

  /// The medal the caller put on the stage (page-local: no API, not
  /// saved); null = the default.
  String? _staged;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The stage's medal: the chosen one if still earned, else the first worn,
  /// else the highest-level earned (catalogue order on a tie); null when
  /// nothing is earned.
  static Medal? stagedOf(List<Medal> medals, List<Medal> worn, String? chosen) {
    final earned = [
      for (final m in medals)
        if (m.unlocked) m,
    ];
    if (earned.isEmpty) return null;
    for (final m in earned) {
      if (m.code == chosen) return m;
    }
    if (worn.isNotEmpty) return worn.first;
    var best = earned.first;
    for (final m in earned.skip(1)) {
      if (m.currentLevel > best.currentLevel) best = m;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final load = ref.watch(medalCatalogueProvider);
    final body = switch (load) {
      AsyncValue(:final value?) => _page(value),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.medalsLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(medalCatalogueProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return MedalsScaffold(
      title: l10n.medalsTitle,
      actions: [
        IconButton(
          key: MedalsScreen.chooseKey,
          tooltip: l10n.medalsChoose,
          icon: const Icon(Icons.push_pin_outlined),
          onPressed: () => context.push(AppRoutes.medalShowcase),
        ),
      ],
      body: body,
    );
  }

  Widget _page(MedalCatalogue catalogue) {
    final worn = [
      for (final m in catalogue.data)
        if (m.worn && m.unlocked) m,
    ]..sort((a, b) => a.showcasePosition!.compareTo(b.showcasePosition!));
    final wornCodes = [for (final m in worn) m.code];
    final staged = stagedOf(catalogue.data, worn, _staged);
    final shown = [
      for (final m in catalogue.data)
        if (m.category == _tab) MedalCardData.fromMedal(m),
    ];
    void open(MedalCardData card) =>
        showMedalSheet(context, card: card, wornCodes: wornCodes, mine: true);
    // D291: a tap on an earned card puts it on the stage (and scrolls back
    // to it); a tap on the card already there, on the stage's medal, on a
    // locked card, or a long press opens the sheet.
    void tap(MedalCardData card) {
      if (card.locked || card.code == staged?.code) {
        open(card);
        return;
      }
      setState(() => _staged = card.code);
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: KMotion.slow, curve: KMotion.standard);
      }
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(medalCatalogueProvider.future),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: MedalStage(
              staged: staged == null ? null : MedalCardData.fromMedal(staged),
              wornCount: worn.length,
              onOpen: open,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _Tabs(
                selected: _tab,
                onSelect: (c) => setState(() => _tab = c),
              ),
            ),
          ),
          if (shown.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(KSpacing.xl),
              sliver: SliverToBoxAdapter(
                child: Text(
                  context.l10n.medalsTabEmpty,
                  textAlign: TextAlign.center,
                  style: context.textStyles.body.copyWith(
                    color: MedalsLook.of(context).textSecondary,
                  ),
                ),
              ),
            )
          else
            _MedalGrid(cards: shown, onTap: tap, onLongPress: open),
        ],
      ),
    );
  }
}

/// «الإنجازات» / «النشاط»: two equal tabs; the selected one is gold.
class _Tabs extends StatelessWidget {
  const new({required this.selected, required this.onSelect});

  final MedalCategory selected;
  final ValueChanged<MedalCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = MedalsLook.of(context);
    final t = context.textStyles;
    Widget tab(MedalCategory c, String label) {
      final on = c == selected;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: InkWell(
            key: MedalsScreen.tabKey(c),
            borderRadius: BorderRadius.circular(KRadius.md),
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: KMotion.fast,
              constraints: const BoxConstraints(
                minHeight: KSizes.minTouchTarget,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.sm,
                vertical: KSpacing.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KRadius.md),
                gradient: on ? MedalsLook.goldGradient : null,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(
                  color: on ? KStatusColors.onStatus : look.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: MedalsScreen.tabsKey,
      padding: const EdgeInsets.all(KSpacing.xs),
      decoration: BoxDecoration(
        color: look.panel,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: look.panelBorder),
      ),
      child: Row(
        children: [
          tab(MedalCategory.achievement, l10n.medalsTabAchievements),
          const SizedBox(width: KSpacing.xs),
          tab(MedalCategory.activity, l10n.medalsTabActivity),
        ],
      ),
    );
  }
}

class _MedalGrid extends StatelessWidget {
  const new({required this.cards, required this.onTap, this.onLongPress});

  final List<MedalCardData> cards;
  final ValueChanged<MedalCardData> onTap;
  final ValueChanged<MedalCardData>? onLongPress;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.all(KSpacing.lg),
    sliver: SliverGrid(
      key: MedalsScreen.gridKey,
      // The owner's frame keeps its own aspect (3:4).
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: KSpacing.sm,
        crossAxisSpacing: KSpacing.sm,
        childAspectRatio: MedalsLook.cardAspect,
      ),
      delegate: SliverChildBuilderDelegate(
        childCount: cards.length,
        (context, i) => MedalCard(
          card: cards[i],
          onTap: () => onTap(cards[i]),
          onLongPress: switch (onLongPress) {
            final f? => () => f(cards[i]),
            null => null,
          },
        ),
      ),
    ),
  );
}

/// One medal of the grid (D291): the owner's card frame (desaturated while
/// the medal is not obtained) around the art (no number on it)
/// (greyscale while not earned), the name and the status. The content sits
/// in the frame's inner area; its text scale stops at × 1.3 (like the other
/// framed Kabso badges) and it scales down rather than overflow.
class MedalCard extends StatelessWidget {
  const new({
    required this.card,
    required this.onTap,
    super.key,
    this.onLongPress,
  });

  final MedalCardData card;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const progressKey = Key('medals.card.progress');
  static const frameKey = Key('medals.card.frame');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = MedalsLook.of(context);
    final t = context.textStyles;
    final c = card;
    final status = c.locked
        ? l10n.medalsNotObtained
        : c.worn
        ? '${l10n.medalsLevel(c.level)}، ${l10n.medalsWorn}'
        : l10n.medalsLevel(c.level);
    const inner = MedalsLook.cardInner;
    final frame = Image.asset(
      MedalsLook.cardFrame,
      key: frameKey,
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );
    return Semantics(
      key: MedalsScreen.medalKey(c.code),
      button: true,
      label: l10n.medalsCardLabel(c.name, status),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final innerW = w * (1 - inner.left - inner.right);
          final art = (innerW * 0.52).clamp(40.0, 76.0);
          return Stack(
            children: [
              Positioned(
                left: w * (inner.left - 0.01),
                right: w * (inner.right - 0.01),
                top: h * (inner.top - 0.01),
                bottom: h * (inner.bottom - 0.01),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: look.cardFill,
                    borderRadius: BorderRadius.circular(KRadius.md),
                  ),
                ),
              ),
              Positioned.fill(
                child: c.locked
                    ? Opacity(
                        opacity: 0.8,
                        child: ColorFiltered(
                          colorFilter: medalGreyscale,
                          child: frame,
                        ),
                      )
                    : frame,
              ),
              Positioned(
                left: w * inner.left,
                right: w * inner.right,
                top: h * inner.top + KSpacing.xs,
                bottom: h * inner.bottom + KSpacing.xs,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: innerW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MedalIcon(
                              iconKey: c.iconKey,
                              iconUrl: c.iconUrl,
                              iconAsset: c.iconAsset,
                              size: art,
                              locked: c.locked,
                            ),
                            const SizedBox(height: KSpacing.xs),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KSpacing.xs,
                              ),
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: t.bodyStrong.copyWith(color: look.text),
                              ),
                            ),
                            const SizedBox(height: KSpacing.xs),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KSpacing.sm,
                              ),
                              child: _Status(card: c),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(KRadius.lg),
                    onTap: onTap,
                    onLongPress: onLongPress,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const new({required this.card});

  final MedalCardData card;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final look = MedalsLook.of(context);
    final t = context.textStyles;
    final c = card;
    // D300: a creators-only medal for someone who is not a creator now.
    final creatorsOnly = c.multiRequirement && !c.eligible;
    if (c.locked) {
      return _Pill(
        label: creatorsOnly ? l10n.medalsCreatorsOnly : l10n.medalsNotObtained,
        background: look.mutedPill,
        foreground: look.textSecondary,
      );
    }
    // A Wrap: at a large text scale «مرتدية» moves under the level instead
    // of cutting it.
    final head = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: KSpacing.xs,
      runSpacing: KSpacing.xxs,
      children: [
        Text(
          l10n.medalsLevel(c.level),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.label.copyWith(color: look.text),
        ),
        if (c.worn)
          _Pill(
            label: l10n.medalsWorn,
            gradient: MedalsLook.goldGradient,
            foreground: KStatusColors.onStatus,
          ),
      ],
    );
    final progress = c.progress;
    if (progress == null) return head;
    if (c.multiRequirement) {
      // D300: the card's bar is the lowest of the three requirements.
      final weakest = c.weakestRequirement;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          const SizedBox(height: KSpacing.xxs),
          if (creatorsOnly || weakest == null)
            Text(
              creatorsOnly ? l10n.medalsCreatorsOnly : l10n.medalsTopLevel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: look.textSecondary),
            )
          else
            MedalProgressBar(
              value: weakest.value,
              next: weakest.next!,
              compact: true,
            ),
        ],
      );
    }
    final next = progress.next;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        head,
        const SizedBox(height: KSpacing.xxs),
        if (next == null)
          Text(
            l10n.medalsTopLevel,
            maxLines: 1,
            style: t.caption.copyWith(color: look.textSecondary),
          )
        else
          MedalProgressBar(value: progress.value, next: next, compact: true),
      ],
    );
  }
}

/// A thin bar toward the next level and «x / y» under it (Western digits).
class MedalProgressBar extends StatelessWidget {
  const new({
    required this.value,
    required this.next,
    super.key,
    this.compact = false,
  });

  final int value;
  final int next;

  /// Short numbers (1.2M / 3B) for a narrow card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final look = MedalsLook.of(context);
    final t = context.textStyles;
    final shown = value > next ? next : value;
    return Column(
      key: MedalCard.progressKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.pill),
          child: LinearProgressIndicator(
            value: next <= 0 ? 0 : shown / next,
            minHeight: 4,
            backgroundColor: look.track,
            valueColor: AlwaysStoppedAnimation(look.bar),
          ),
        ),
        const SizedBox(height: KSpacing.xxs),
        Text(
          context.l10n.medalsProgress(
            compact ? KFormat.compactLatin(shown) : KFormat.grouped(shown),
            compact ? KFormat.compactLatin(next) : KFormat.grouped(next),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.caption.copyWith(color: look.textSecondary),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const new({
    required this.label,
    required this.foreground,
    this.background,
    this.gradient,
  });

  final String label;
  final Color foreground;
  final Color? background;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: KSpacing.md,
      vertical: KSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: background,
      gradient: gradient,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textStyles.label.copyWith(color: foreground),
    ),
  );
}

/// Opens [MedalDetailSheet] for [card]. [mine]: the caller's medal (wear /
/// take off); [wornCodes]: the caller's showcase in order.
void showMedalSheet(
  BuildContext context, {
  required MedalCardData card,
  List<String> wornCodes = const [],
  bool mine = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      MedalDetailSheet(card: card, wornCodes: wornCodes, mine: mine),
);

/// A medal's sheet (D291): the art, the name and
/// description, when it was earned, the progress, every level with its
/// threshold (reached ones ticked) and, for the caller's earned medal,
/// «ارتداء» / «خلع» under the showcase rules (owned only, at most
/// [maxShowcaseMedals]).
class MedalDetailSheet extends ConsumerStatefulWidget {
  const new({
    required this.card,
    super.key,
    this.wornCodes = const [],
    this.mine = false,
  });

  final MedalCardData card;
  final List<String> wornCodes;
  final bool mine;

  static const wearKey = Key('medals.sheet.wear');
  static Key levelKey(int level) => Key('medals.sheet.level.$level');

  /// D300: a requirement's row (its name and bar) in the sheet.
  static Key requirementKey(String metric) =>
      Key('medals.sheet.requirement.$metric');
  static const creatorsOnlyKey = Key('medals.sheet.creatorsOnly');

  @override
  ConsumerState<MedalDetailSheet> createState() => _MedalDetailSheetState();
}

class _MedalDetailSheetState extends ConsumerState<MedalDetailSheet> {
  bool _saving = false;

  Future<void> _toggleWear() async {
    final l10n = context.l10n;
    final c = widget.card;
    final current = widget.wornCodes;
    if (!c.worn && current.length >= maxShowcaseMedals) {
      KSnack.info(context, l10n.medalsShowcaseLimit(maxShowcaseMedals));
      return;
    }
    final next = c.worn
        ? [
            for (final code in current)
              if (code != c.code) code,
          ]
        : [...current, c.code];
    setState(() => _saving = true);
    try {
      await ref.read(medalsRepositoryProvider).setShowcase(next);
      if (!mounted) return;
      ref
        ..invalidate(medalCatalogueProvider)
        ..invalidate(myShowcaseProvider)
        ..invalidate(profileStatsProvider)
        ..invalidate(publicProfileProvider);
      KSnack.success(context, l10n.medalsWearSaved);
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _threshold(AppLocalizations l10n, int n) =>
      switch (widget.card.metric) {
        'LIVES_HOSTED' => l10n.medalsThresholdLives(n),
        'LIVE_HOURS' => l10n.medalsThresholdHours(n),
        'CHARM_LEVEL' => l10n.medalsThresholdCharm(n),
        'BULLETS_SENT' => l10n.medalsThresholdBullets(n),
        'GIFTS_SENT_COINS' => l10n.medalsThresholdGiftCoins(KFormat.grouped(n)),
        'LUCKY_GIFTS_SENT_COINS' => l10n.medalsThresholdLuckyCoins(
          KFormat.grouped(n),
        ),
        'FAMILY_JOINED' || 'CP_FORMED' => l10n.medalsThresholdOnce,
        // D300 «لاعب الأحكام».
        'PK_DARES_POINTS' => l10n.medalsThresholdPkPoints(KFormat.grouped(n)),
        _ => KFormat.grouped(n),
      };

  /// D300: a multi-requirement level's thresholds; each «name number» pair
  /// is kept on one line (a no-break space), lines break between pairs.
  String _requirementsText(AppLocalizations l10n, MedalLevel level) => [
    for (final metric in medalRequirementMetrics)
      for (final r in level.requirements.where((r) => r.metric == metric))
        if (medalRequirementName(l10n, r.metric) case final name?)
          '$name\u00A0${KFormat.grouped(r.threshold)}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final c = widget.card;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final at = c.awardedAt;
    final progress = c.progress;
    final towards = c.locked && c.levels.isNotEmpty
        ? c.levels.first.threshold
        : progress?.next;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.xl,
          KSpacing.lg,
          KSpacing.xl,
          KSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: MedalIcon(
                iconKey: c.iconKey,
                iconUrl: c.iconUrl,
                iconAsset: c.iconAsset,
                size: 96,
                locked: c.locked,
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Text(
              c.name,
              textAlign: TextAlign.center,
              style: t.title.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              c.description,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              [
                if (at == null)
                  l10n.medalsNotObtained
                else ...[
                  l10n.medalsLevel(c.level),
                  l10n.medalsEarnedOn(KFormat.date(at, locale)),
                ],
                if (c.worn) l10n.medalsWorn,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textTertiary),
            ),
            if (c.multiRequirement) ...[
              const SizedBox(height: KSpacing.md),
              if (!c.eligible)
                Text(
                  l10n.medalsCreatorsOnlyBody,
                  key: MedalDetailSheet.creatorsOnlyKey,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: p.textSecondary),
                )
              else if (c.weakestRequirement != null) ...[
                Text(
                  l10n.medalsReqAllTogether,
                  style: t.label.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.xs),
                for (final r in c.requirements)
                  if (medalRequirementName(l10n, r.metric) case final name?)
                    _RequirementRow(
                      key: MedalDetailSheet.requirementKey(r.metric),
                      name: name,
                      value: r.value,
                      next: r.next!,
                    ),
              ],
            ] else if (progress != null && towards != null) ...[
              const SizedBox(height: KSpacing.md),
              MedalProgressBar(value: progress.value, next: towards),
            ],
            if (c.levels.length > 1) ...[
              const SizedBox(height: KSpacing.lg),
              Text(
                l10n.medalsLevelsTitle,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: KSpacing.sm),
              for (final l in c.levels)
                _LevelRow(
                  key: MedalDetailSheet.levelKey(l.level),
                  iconKey: c.iconKey,
                  level: l,
                  reached: l.level <= c.level,
                  current: l.level == c.level,
                  name: l.name ?? l10n.medalsLevel(l.level),
                  threshold: l.requirements.isNotEmpty
                      ? _requirementsText(l10n, l)
                      : _threshold(l10n, l.threshold),
                ),
            ],
            if (widget.mine && !c.locked) ...[
              const SizedBox(height: KSpacing.lg),
              KButton(
                key: MedalDetailSheet.wearKey,
                label: c.worn ? l10n.medalsTakeOff : l10n.medalsWear,
                variant: c.worn
                    ? KButtonVariant.secondary
                    : KButtonVariant.primary,
                icon: c.worn
                    ? Icons.remove_circle_outline_rounded
                    : Icons.military_tech_rounded,
                loading: _saving,
                onPressed: _saving ? null : () => unawaited(_toggleWear()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const new({
    required this.iconKey,
    required this.level,
    required this.reached,
    required this.current,
    required this.name,
    required this.threshold,
    super.key,
  });

  final String iconKey;
  final MedalLevel level;
  final bool reached;
  final bool current;
  final String name;
  final String threshold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    // D291: a level with its own art shows it (dimmed until reached);
    // otherwise its number on the gold plate.
    final Widget numeral = level.iconAsset != null || level.iconUrl != null
        ? MedalIcon(
            iconKey: iconKey,
            iconAsset: level.iconAsset,
            iconUrl: level.iconUrl,
            size: 44,
          )
        : MedalLevelNumeral(level: level.level, size: 44);
    return Semantics(
      label: reached ? l10n.medalsLevelReachedLabel(name) : name,
      value: threshold,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: KSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: current ? p.surfaceRaised : p.surface,
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: current
                ? KBrandColors.gold.withValues(alpha: 0.7)
                : p.border,
          ),
        ),
        child: Row(
          children: [
            if (reached)
              numeral
            else
              Opacity(
                opacity: 0.5,
                child: ColorFiltered(
                  colorFilter: medalGreyscale,
                  child: numeral,
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
                    style: t.label.copyWith(
                      color: reached ? p.textPrimary : p.textSecondary,
                    ),
                  ),
                  Text(
                    threshold,
                    // D300: three thresholds may need a second line.
                    maxLines: level.requirements.isEmpty ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
            if (reached)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: KBrandColors.gold,
              ),
          ],
        ),
      ),
    );
  }
}

/// D300: one requirement of a multi-requirement medal in the sheet — its
/// name, then a bar toward the next level's threshold with «x / y».
class _RequirementRow extends StatelessWidget {
  const new({
    required this.name,
    required this.value,
    required this.next,
    super.key,
  });

  final String name;
  final int value;
  final int next;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final done = value >= next;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ),
              if (done)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: KBrandColors.gold,
                ),
            ],
          ),
          const SizedBox(height: KSpacing.xxs),
          MedalProgressBar(value: value, next: next),
        ],
      ),
    );
  }
}
