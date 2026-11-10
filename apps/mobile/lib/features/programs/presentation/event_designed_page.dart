import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/event_page_design.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_concepts.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:kabso_live/features/programs/presentation/event_page_theme.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

// v1.115-social (D354, owner «اجعل كل الخيارات متاحة», CONVENTIONS §10.150):
// a gift event's page as the team designed it in the panel — one of three
// layouts (HERO_PODIUM, STAGE, DECK), one of five leaderboard styles, one of
// six countdowns, one of six card presets, a rules button (six styles, either
// edge) or none, the sections in the team's order (hidden ones left out), the
// rewards tab from the team's rank tiers over the boards' own prize lines, the
// leaderboard background and the motion settings. Everything shown is the
// event's real data (`EventDetail`, `EventLeaderboard`); reduced motion stops
// every animation. A null design never reaches this page (today's page).

/// The page's preset theme (null: today's cards, CLASSIC).
EventPageTheme? eventPresetTheme(EventCardPreset preset) => switch (preset) {
  EventCardPreset.classic => null,
  EventCardPreset.luxuryGold => EventPageTheme.luxuryGold,
  EventCardPreset.glass => EventPageTheme.glass,
  EventCardPreset.darkMinimal => EventPageTheme.darkMinimal,
  EventCardPreset.neon => EventPageTheme.neon,
  EventCardPreset.kabsoRed => EventPageTheme.kabsoRed,
};

/// The widget style of a design's leaderboard choice.
LeaderboardStyle eventStageStyle(EventBoardStyle s) => switch (s) {
  EventBoardStyle.throne => LeaderboardStyle.throne,
  EventBoardStyle.podium => LeaderboardStyle.podium,
  EventBoardStyle.cardsRow => LeaderboardStyle.cardsRow,
  EventBoardStyle.spotlight => LeaderboardStyle.spotlight,
  EventBoardStyle.shieldCrest => LeaderboardStyle.shieldCrest,
};

String _nameOf(UserSummary u) =>
    u.displayName.isEmpty ? u.username : u.displayName;

/// A board's rows as the styles draw them (CP: the pair; AGENCIES: the
/// agency), with the entrants' own photos.
List<LbEntry> eventStageEntries(AppLocalizations l10n, EventLeaderboard b) => [
  for (final r in b.giftRows)
    LbEntry(
      rank: r.rank,
      name: r.isAgency
          ? (r.agencyName ?? _nameOf(r.user))
          : r.partner != null
          ? l10n.eventsCpPair(_nameOf(r.user), _nameOf(r.partner!))
          : _nameOf(r.user),
      score: r.score,
      photo: r.user.avatarUrl == null
          ? null
          : GiftEventBackdrop.image(r.user.avatarUrl!),
      isMe: b.myRank == r.rank,
    ),
];

/// The page.
class EventDesignedPage extends ConsumerStatefulWidget {
  const new({
    required this.event,
    required this.design,
    required this.onRefresh,
    this.now,
    super.key,
  });

  final EventDetail event;
  final EventPageDesign design;
  final Future<void> Function() onRefresh;

  /// Tests and goldens: a fixed clock for the countdowns.
  final DateTime Function()? now;

  static const pageKey = Key('event.design.page');
  static const rulesButtonKey = Key('event.rulesButton');
  static const rulesSectionKey = Key('event.design.rules');
  static const boardsKey = Key('event.design.boards');
  static const milestonesKey = Key('event.design.milestones');
  static const rewardsKey = Key('event.design.rewards');
  static const footerKey = Key('event.design.footer');
  static Key sectionKey(EventPageSectionId id) =>
      Key('event.design.section.${id.wire}');
  static Key boardKey(EventBoardKind kind) =>
      Key('event.design.board.${kind.wire}');

  @override
  ConsumerState<EventDesignedPage> createState() => _EventDesignedPageState();
}

class _EventDesignedPageState extends ConsumerState<EventDesignedPage> {
  late int _tab = _rewardsFirst ? 1 : 0;
  Timer? _refresh;

  EventDetail get _e => widget.event;
  EventPageDesign get _d => widget.design;

  bool get _rewardsFirst {
    final order = _d.visibleSections;
    final r = order.indexOf(EventPageSectionId.rewards);
    final b = order.indexOf(EventPageSectionId.boards);
    return r >= 0 && (b < 0 || r < b);
  }

  ValueNotifier<int> get _selection => GiftEventBoards.selection(_e.id);

  int get _board => _selection.value.clamp(0, _e.boards.length - 1);

  @override
  void initState() {
    super.initState();
    // As today's page: a running board reloads while shown.
    if (_e.status == EventStatus.running && _e.boards.isNotEmpty) {
      _refresh = Timer.periodic(GiftEventBoards.refreshEvery, (_) {
        if (!mounted || !TickerMode.valuesOf(context).enabled) return;
        ref.invalidate(
          eventBoardProvider((id: _e.id, board: _e.boards[_board].kind)),
        );
      });
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    // The page is gone: its board choice goes with it (after the bar).
    final id = _e.id;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => GiftEventBoards.release(id),
    );
    super.dispose();
  }

  void _openRules() {
    final l10n = context.l10n;
    unawaited(
      showEventRulesSheet(
        context,
        lines: [
          if (_e.rules.trim().isNotEmpty) _e.rules.trim(),
          l10n.eventsRuleOnlyGifts,
          if (_e.boards.any((b) => b.minPoints > 0)) l10n.eventsRuleMinimum,
          l10n.eventsRuleAutoPayout,
        ],
      ),
    );
  }

  /// The rewards tab's tiers of the selected board.
  List<RewardTier> _tiers(BuildContext context) {
    if (_e.boards.isEmpty) return const [];
    return rewardTiersOf(
      context.l10n,
      Localizations.localeOf(context).languageCode,
      _e.boards[_board],
      _d.tiers,
    );
  }

  bool get _hasTabs =>
      _d.isVisible(EventPageSectionId.rewards) &&
      _e.boards.any((b) => b.prizes.isNotEmpty);

  // ---- sections ------------------------------------------------------------

  Widget _entrance(int index, Widget child) =>
      _Entrance(motion: _d.motion, index: index, child: child);

  List<Widget> _rankingSections(BuildContext context, {required bool deck}) {
    final out = <Widget>[];
    var i = 0;
    for (final id in _d.visibleSections) {
      final section = switch (id) {
        EventPageSectionId.gifts => _gifts(context),
        EventPageSectionId.rules => _rules(context),
        EventPageSectionId.boards =>
          deck ? _deckBoards(context) : _boards(context),
        EventPageSectionId.milestones => _milestones(context),
        // The rewards are a tab of their own.
        EventPageSectionId.rewards => null,
      };
      if (section == null) continue;
      out
        ..add(
          KeyedSubtree(
            key: EventDesignedPage.sectionKey(id),
            child: _entrance(i++, section),
          ),
        )
        ..add(const SizedBox(height: KSpacing.xl));
    }
    return out;
  }

  Widget? _gifts(BuildContext context) {
    if (_e.gifts.isEmpty) return null;
    final l10n = context.l10n;
    return Column(
      children: [
        OrnamentHeading(l10n.eventsGifts),
        const SizedBox(height: KSpacing.md),
        GiftsStrip(
          _e.gifts,
          onTap: (g) => unawaited(showEventGiftSheet(context, ref, g)),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, Widget child) {
    final theme = EventPageTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: EventFrame(
        radius: theme?.radius ?? KRadius.lg,
        fill:
            theme?.cardFill ??
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xE6400810), Color(0xE61E0307)],
            ),
        border:
            theme?.cardBorder ??
            LinearGradient(
              colors: [
                kGold.withValues(alpha: .4),
                kGold.withValues(alpha: .4),
              ],
            ),
        borderWidth: theme?.cardBorderWidth ?? 1,
        blur: theme?.blur ?? 0,
        glow: theme?.glow ?? const [],
        padding: const EdgeInsets.all(KSpacing.md),
        child: child,
      ),
    );
  }

  Widget _rules(BuildContext context) => Column(
    key: EventDesignedPage.rulesSectionKey,
    children: [
      OrnamentHeading(context.l10n.eventsRules),
      const SizedBox(height: KSpacing.md),
      _card(
        context,
        GiftEventRules(
          rules: _e.rules,
          hasMinimum: _e.boards.any((b) => b.minPoints > 0),
        ),
      ),
    ],
  );

  Widget? _milestones(BuildContext context) {
    if (_e.milestones.isEmpty) return null;
    final l10n = context.l10n;
    final t = context.textStyles;
    final theme = EventPageTheme.of(context);
    final many = _e.boards.length > 1;
    return Column(
      key: EventDesignedPage.milestonesKey,
      children: [
        OrnamentHeading(l10n.eventsMilestonesTitle),
        const SizedBox(height: KSpacing.md),
        _card(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in _e.milestones)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 20,
                        color: theme?.title ?? kGoldLight,
                      ),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                l10n.eventsMilestoneAt(
                                  KFormat.grouped(m.points),
                                ),
                                if (many) eventBoardLabel(l10n, m.board),
                              ].join(' · '),
                              style: t.bodyStrong.copyWith(
                                color: theme?.text ?? Colors.white,
                              ),
                            ),
                            const SizedBox(height: KSpacing.xxs),
                            EventPrizeChips(m.prize, tappable: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pills(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<int>(
      valueListenable: _selection,
      builder: (context, _, _) => BoardPills(
        labels: [for (final b in _e.boards) eventBoardLabel(l10n, b.kind)],
        keys: [for (final b in _e.boards) GiftEventBoards.tabKey(b.kind)],
        selected: _board,
        onSelected: (i) => setState(() => _selection.value = i),
      ),
    );
  }

  ImageProvider? get _stageImage {
    final url = _d.leaderboardBackgroundUrl;
    return url == null ? null : GiftEventBackdrop.image(url);
  }

  Widget? _boards(BuildContext context) {
    if (_e.boards.isEmpty) return null;
    final l10n = context.l10n;
    final t = context.textStyles;
    final board = _e.boards[_board];
    final key = (id: _e.id, board: board.kind);
    final live = ref.watch(eventBoardProvider(key));
    final ended = eventBoardEnded(_e, live.value);
    final subtitle = ended
        ? (live.value?.isFinal ?? false)
              ? l10n.eventsBoardFinal
              : l10n.eventsResultsPending
        : board.minPoints > 0
        ? l10n.eventsMinPoints(KFormat.grouped(board.minPoints))
        : null;
    return Column(
      key: EventDesignedPage.boardsKey,
      children: [
        if (_e.boards.length > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: _pills(context),
          ),
          const SizedBox(height: KSpacing.md),
        ] else ...[
          OrnamentHeading(eventBoardLabel(l10n, board.kind)),
          const SizedBox(height: KSpacing.sm),
        ],
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.sm,
            ),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: kGoldLight),
            ),
          ),
        switch (live) {
          AsyncValue(value: final b?) => Column(
            key: EventDesignedPage.boardKey(board.kind),
            children: [
              if (b.giftRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: Text(
                    l10n.eventsBoardEmpty,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: kGoldLight),
                  ),
                ),
              LeaderboardStage(
                style: eventStageStyle(_d.leaderboard),
                entries: eventStageEntries(l10n, b),
                background: _stageImage,
                rowsLimit: (board.shown - 3).clamp(0, 97),
              ),
            ],
          ),
          AsyncValue(:final error?, isLoading: false) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: FailureErrorState(
              title: l10n.eventsLoadError,
              failure: toAppFailure(error),
              onRetry: () => ref.invalidate(eventBoardProvider(key)),
              compact: true,
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator(color: kGold)),
          ),
        },
      ],
    );
  }

  /// The deck: one swipeable card per board (each loads its own board).
  Widget? _deckBoards(BuildContext context) {
    if (_e.boards.isEmpty) return null;
    final l10n = context.l10n;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      key: EventDesignedPage.boardsKey,
      height: 520 + 80 * (scale - 1),
      child: PageView.builder(
        controller: PageController(
          viewportFraction: _e.boards.length > 1 ? .88 : .94,
          initialPage: _board,
        ),
        itemCount: _e.boards.length,
        onPageChanged: (i) => setState(() => _selection.value = i),
        itemBuilder: (context, i) {
          final board = _e.boards[i];
          final live = ref.watch(
            eventBoardProvider((id: _e.id, board: board.kind)),
          );
          return Padding(
            key: EventDesignedPage.boardKey(board.kind),
            padding: const EdgeInsets.fromLTRB(5, KSpacing.md, 5, 0),
            child: BoardDeckCard(
              title: eventBoardLabel(l10n, board.kind),
              entries: live.value == null
                  ? const []
                  : eventStageEntries(l10n, live.value!),
              loading: live.value == null && live.isLoading,
              background: _stageImage,
              rows: (board.shown - 3).clamp(0, 4),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _rewards(BuildContext context, {required bool carousel}) {
    final l10n = context.l10n;
    final tiers = _tiers(context);
    return [
      if (_e.boards.length > 1) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: _pills(context),
        ),
        const SizedBox(height: KSpacing.lg),
      ],
      if (tiers.isEmpty)
        Padding(
          padding: const EdgeInsets.all(KSpacing.xl),
          child: Text(
            l10n.eventsNoPrizes,
            textAlign: TextAlign.center,
            style: context.textStyles.body.copyWith(color: kGoldLight),
          ),
        ),
      for (final (i, t) in tiers.indexed) ...[
        _entrance(i, carousel ? RewardTierCarousel(t) : RewardTierCard(t)),
        const SizedBox(height: KSpacing.xl),
      ],
    ];
  }

  // ---- chrome --------------------------------------------------------------

  Widget _tabs({bool compact = false}) => GoldTabs(
    selected: _tab,
    rewardsFirst: _rewardsFirst,
    compact: compact,
    onSelected: (i) => setState(() => _tab = i),
  );

  /// The rules button over the page (EDGE_RIBBON, ROUND_ICON, GLASS_CHIP,
  /// SIDE_TAB; GOLD_PILL sits under the countdown, APP_BAR_LINK in the top
  /// bar).
  Widget? _floatingRules(BuildContext context, double heroRow) {
    final spec = _d.rulesButton;
    if (spec == null) return null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // START is the reading start: right in Arabic, left in English.
    final left = spec.atStart != rtl;
    final top = MediaQuery.paddingOf(context).top;
    const k = EventDesignedPage.rulesButtonKey;
    return switch (spec.style) {
      EventRulesStyle.edgeRibbon => Positioned(
        top: heroRow,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: EventRulesRibbon(key: k, edgeIsLeft: left, onTap: _openRules),
      ),
      EventRulesStyle.roundIcon => Positioned(
        top: top + 60,
        left: left ? KSpacing.md : null,
        right: left ? null : KSpacing.md,
        child: EventRulesRoundButton(key: k, onTap: _openRules),
      ),
      EventRulesStyle.glassChip => Positioned(
        top: top + 64,
        left: left ? KSpacing.md : null,
        right: left ? null : KSpacing.md,
        child: EventRulesGlassChip(key: k, onTap: _openRules),
      ),
      EventRulesStyle.sideTab => Positioned(
        top: MediaQuery.sizeOf(context).height * 0.36,
        left: left ? 0 : null,
        right: left ? null : 0,
        child: EventRulesSideTab(key: k, edgeIsLeft: left, onTap: _openRules),
      ),
      _ => null,
    };
  }

  Widget? get _pillRules => _d.rulesButton?.style == EventRulesStyle.goldPill
      ? EventRulesGoldPill(
          key: EventDesignedPage.rulesButtonKey,
          onTap: _openRules,
        )
      : null;

  Widget? get _linkRules => _d.rulesButton?.style == EventRulesStyle.appBarLink
      ? EventRulesAppBarLink(
          key: EventDesignedPage.rulesButtonKey,
          onTap: _openRules,
        )
      : null;

  String _dates(BuildContext context) => eventDates(
    context.l10n,
    _e,
    Localizations.localeOf(context).toLanguageTag(),
  );

  double _heroHeight(BuildContext context, double max) {
    final h = MediaQuery.sizeOf(context).height;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return (h * .56).clamp(360.0, max) + 40 * (scale - 1);
  }

  // ---- the three layouts ---------------------------------------------------

  Widget _footer() => const Padding(
    padding: EdgeInsets.only(top: KSpacing.lg, bottom: 104),
    child: Center(
      child: Image(
        key: EventDesignedPage.footerKey,
        image: AssetImage(
          'assets/brand/kabso_live_logo_horizontal_dark_bg.webp',
        ),
        width: 160,
        semanticLabel: 'Kabso Live',
      ),
    ),
  );

  Widget _heroPodium(BuildContext context) {
    final height = _heroHeight(context, 452);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              EventHero(
                event: _e,
                dates: _dates(context),
                countdown: _d.countdown,
                height: height,
                titleTop: MediaQuery.paddingOf(context).top + 60,
                belowCountdown: _pillRules,
                now: widget.now,
              ),
              Positioned.fill(child: HeroChrome(trailing: _linkRules)),
            ],
          ),
        ),
        if (_hasTabs)
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedBar(
              height:
                  66 +
                  12 *
                      (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                        0.0,
                        0.6,
                      ),
              child: Container(
                color: kPageBg.withValues(alpha: .96),
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  8,
                  KSpacing.lg,
                  8,
                ),
                child: _tabs(),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: KSpacing.md),
              if (_tab == 1 && _hasTabs)
                ..._rewards(context, carousel: false)
              else
                ..._rankingSections(context, deck: false),
              _footer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stage(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StageHeader(
            event: _e,
            design: _d,
            dates: _dates(context),
            top: top,
            maxHeight: _heroHeight(context, 470) + (_hasTabs ? 58 : 0),
            tabs: _hasTabs ? _tabs(compact: true) : null,
            belowCountdown: _pillRules,
            trailing: _linkRules,
            now: widget.now,
            textScale: MediaQuery.textScalerOf(context)
                .scale(1)
                .clamp(1.0, 1.6),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: KSpacing.lg),
              if (_tab == 1 && _hasTabs)
                ..._rewards(context, carousel: false)
              else
                ..._rankingSections(context, deck: false),
              _footer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _deck(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Stack(
          children: [
            EventHero(
              event: _e,
              dates: _dates(context),
              countdown: _d.countdown,
              height: _heroHeight(context, 440),
              titleTop: MediaQuery.paddingOf(context).top + 60,
              belowCountdown: _pillRules,
              now: widget.now,
            ),
            Positioned.fill(child: HeroChrome(trailing: _linkRules)),
          ],
        ),
      ),
      if (_hasTabs)
        SliverPersistentHeader(
          pinned: true,
          delegate: PinnedBar(
            height:
                60 +
                12 *
                    (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                      0.0,
                      0.6,
                    ),
            child: Container(
              color: kPageBg.withValues(alpha: .96),
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                6,
                KSpacing.lg,
                10,
              ),
              child: _tabs(compact: true),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Column(
          children: [
            const SizedBox(height: KSpacing.md),
            if (_tab == 1 && _hasTabs)
              ..._rewards(context, carousel: true)
            else
              ..._rankingSections(context, deck: true),
            _footer(),
          ],
        ),
      ),
    ],
  );

  /// The page, built under its dark theme and its preset (every section
  /// reads them from [context]).
  Widget _scaffold(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final body = switch (_d.layout) {
      EventPageLayout.heroPodium => _heroPodium(context),
      EventPageLayout.stage => _stage(context),
      EventPageLayout.deck => _deck(context),
    };
    final rules = _floatingRules(context, top + 220);
    return Scaffold(
      key: EventDesignedPage.pageKey,
      backgroundColor: kPageBg,
      body: Stack(
        children: [
          // The event's overlay over the whole page (the hero draws the
          // background).
          if (_e.art.overlayUrl != null)
            Positioned.fill(
              child: GiftEventBackdrop(
                art: EventArt(
                  overlayUrl: _e.art.overlayUrl,
                  overlayFormat: _e.art.overlayFormat,
                ),
                overlaySpeed: _d.motion.overlaySpeed,
                overlayOpacity: _d.motion.overlayOpacity,
              ),
            ),
          RefreshIndicator(onRefresh: widget.onRefresh, child: body),
          ?rules,
        ],
      ),
      bottomNavigationBar: GiftEventMyBar(event: _e, gold: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = eventPresetTheme(_d.preset);
    return Theme(
      data: buildAppTheme(
        brightness: Brightness.dark,
        locale: Localizations.localeOf(context),
      ),
      child: StageMotion(
        shimmer: _d.motion.shimmer,
        pulseFirst: _d.motion.pulseFirst,
        child: Builder(
          builder: (themed) {
            final page = Builder(builder: _scaffold);
            return theme == null ? page : theme.apply(themed, page);
          },
        ),
      ),
    );
  }
}

/// How a section comes in (the design's motion); none with reduced motion,
/// with entrance NONE or a zero length.
class _Entrance extends StatelessWidget {
  const new({required this.motion, required this.index, required this.child});

  final EventDesignMotion motion;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        motion.entrance == EventEntrance.none ||
        motion.durationMs == 0) {
      return child;
    }
    final ms = motion.durationMs + 60 * index.clamp(0, 6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => switch (motion.entrance) {
        EventEntrance.slide => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - v)),
            child: child,
          ),
        ),
        EventEntrance.scale => Opacity(
          opacity: v,
          child: Transform.scale(scale: .94 + .06 * v, child: child),
        ),
        _ => Opacity(opacity: v, child: child),
      },
    );
  }
}

/// The stage layout's header: the full hero that collapses into a bar with
/// the title, a small countdown and the tabs.
class _StageHeader extends SliverPersistentHeaderDelegate {
  new({
    required this.event,
    required this.design,
    required this.dates,
    required this.top,
    required this.maxHeight,
    required this.textScale,
    this.tabs,
    this.belowCountdown,
    this.trailing,
    this.now,
  });

  final EventDetail event;
  final EventPageDesign design;
  final String dates;
  final double top;
  final double maxHeight;
  final double textScale;
  final Widget? tabs;
  final Widget? belowCountdown;
  final Widget? trailing;
  final DateTime Function()? now;

  double get _tabsH => tabs == null ? 0 : 58 + 12 * (textScale - 1);

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => top + 56 + 48 * textScale + _tabsH;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final still = event.art.stillUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 1 - t,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: maxExtent,
            child: Stack(
              children: [
                EventHero(
                  event: event,
                  dates: dates,
                  countdown: design.countdown,
                  height: maxExtent - _tabsH,
                  titleTop: top + 60,
                  belowCountdown: belowCountdown,
                  now: now,
                ),
                Positioned.fill(child: HeroChrome(trailing: trailing)),
              ],
            ),
          ),
        ),
        if (t > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: minExtent - _tabsH,
            child: Opacity(
              opacity: t,
              child: Container(
                decoration: BoxDecoration(
                  color: kPageBg,
                  image: still == null
                      ? null
                      : DecorationImage(
                          image: GiftEventBackdrop.image(still),
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -.6),
                          colorFilter: const ColorFilter.mode(
                            Color(0xB3140206),
                            BlendMode.srcOver,
                          ),
                        ),
                  border: Border(
                    bottom: BorderSide(color: kGold.withValues(alpha: .5)),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: top + 46,
                  left: KSpacing.lg + KSizes.minTouchTarget,
                  right: KSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.title.copyWith(
                          color: kGoldLight,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    MiniCountdown(event: event, now: now),
                  ],
                ),
              ),
            ),
          ),
        if (t > 0) Positioned.fill(child: HeroChrome(trailing: trailing)),
        if (tabs != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _tabsH,
            child: Container(
              color: kPageBg,
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                6,
                KSpacing.lg,
                6,
              ),
              child: tabs,
            ),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(_StageHeader old) => true;
}
