import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart'
    show KWizardHatIcon;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D199b (owner: «اريد ان تكون شريحة التارجت بنفس هذا التصميم … مطابق
/// ١٠٠٪»): the «تارجت» sheet laid out as the owner's contribution-ranking
/// reference (layout only; Kabso's own art, avatars, level badges and data),
/// measured at 393 × 852 pt (spec in the D199b fidelity report):
///
/// - a white sheet (the dark surface in the dark theme), 75 % of the screen,
///   16 pt corners; the tab row «الكرز» | «هدايا الحظ» (D224: the selected
///   bold on the theme's pill, [_Ink.chosen]) and ✕ at the end;
/// - the period pills يومي / أسبوعي / شهري / الكل (D224: the selected on
///   the same pill — white in the light theme, black in the dark one —
///   bold) and «?» at the end; a viewer has today only (the
///   public endpoint never shows longer totals), so a single pill;
/// - «العد التنازلي» to the period's reset (Riyadh; none for الكل) and the
///   period on the far side; on the daily tab today's two targets, compact;
/// - the ranked list: 1–3 on Kabso's shields, 4+ grey numbers, the avatar
///   in its frame, the name, the support level and the amount (cherries
///   under «الكرز», coins under «هدايا الحظ») on the far side;
/// - the bar pinned at the bottom with the caller's own place and the
///   turquoise button: «مركز المهام» for the host, «ادعم» (the gift panel)
///   for a viewer.
///
/// The host reads `GET /me/host-gift-stats?period=`; a viewer
/// `GET /live/hosts/{username}/targets` (today).
class HostTargetSheet extends ConsumerStatefulWidget {
  const new({required this.isHost, super.key, this.username, this.onSupport})
    : assert(isHost || username != null, 'a viewer reads a host by name');

  /// The host's own sheet (every period, the task center).
  final bool isHost;

  /// The host whose targets a viewer reads.
  final String? username;

  /// A viewer's «ادعم»: opens the room's gift panel (null: no button, e.g.
  /// a guest).
  final VoidCallback? onSupport;

  static const sheetKey = Key('targetSheet.sheet');
  static const closeKey = Key('targetSheet.close');
  static const helpKey = Key('targetSheet.help');
  static const countdownKey = Key('targetSheet.countdown');

  /// D224: the selected «الكرز» / «هدايا الحظ» tab's pill.
  static const chosenTabKey = Key('targetSheet.chosenTab');
  static const rangeKey = Key('targetSheet.range');
  static const targetsKey = Key('targetSheet.targets');
  static const meKey = Key('targetSheet.me');
  static const taskCenterKey = Key('targetSheet.taskCenter');
  static const supportKey = Key('targetSheet.support');
  static Key tabKey(TargetTab t) => Key('targetSheet.tab.${t.name}');
  static Key periodKey(HostStatsPeriod p) =>
      Key('targetSheet.period.${p.wire}');
  static Key rowKey(String username) => Key('targetSheet.row.$username');

  /// How many people a list holds (`HostSupporter` lists, D199b): a place
  /// below it reads «20+», as the reference's «50+».
  static const listLimit = 20;

  /// The countdown's clock (tests and captures pin it).
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @override
  ConsumerState<HostTargetSheet> createState() => _HostTargetSheetState();
}

/// The sheet's two tabs.
enum TargetTab { cherries, lucky }

/// The reference's measured values (logical pt at 393 × 852; M = measured,
/// E = estimated from cap heights for Kabso's fonts).
abstract final class _G {
  static const radius = 16.0; // M ≈ 16
  static const tabsHeight = 44.0; // M: tab text centre 22 pt down
  static const tabFont = 15.5; // E (cap 11.1 pt)
  static const tabGap = 24.5; // M
  /// D224: the selected tab's pill (the mark under it is gone).
  static const tabPill = 30.0;
  static const closeGlyph = 11.2; // M: 12.8 with the 1.6 pt stroke
  static const pillsTop = 8.2; // M: pill top 52.2 pt down
  static const pillHeight = 27.25; // M
  static const pillPad = 10.6; // M
  static const pillGap = 3.4; // M
  static const pillFont = 14.5; // E (cap 10.6 pt)
  static const help = 18.3; // M
  static const countdownHeight = 20.0; // M: centre 99.8 pt down
  static const countdownGap = 10.4; // M
  static const smallFont = 11.0; // E (cap 8.1 pt)
  static const row = 58.5; // M (row pitch)
  static const rankCentre = 22.2; // M
  static const avatar = 36.2; // M
  static const framed = 46.0; // M ≈ 42.6 frame (Kabso frames are wider)
  static const avatarCentre = 63.9; // M
  static const nameStart = 94.0; // M

  /// From the avatar's box (centred on [avatarCentre]) to the name.
  static const double nameGap = nameStart - 2 * avatarCentre + 2 * rankCentre;
  static const nameFont = 12.5; // E (cap 8.9 pt)
  static const rankFont = 10.5; // E (cap 7.7 pt)
  static const amountFont = 11.5; // E (digits 8.1 pt)
  static const coin = 13.2; // M
  static const coinGap = 5.5; // M
  static const rowEnd = 15.8; // M
  static const medalWidth = 18.0; // M (17.9 × 20.4)
  static const badgeHeight = 11.0; // E: the reference's pill is 15.3 pt tall
  static const barHeight = 56.0; // M (+ the 34 pt bottom inset: 90 pt)
  static const meNameFont = 14.0; // E
  static const ctaWidth = 118.4; // M
  static const ctaHeight = 31.5; // M
  static const ctaEnd = 13.6; // M
  static const ctaFont = 13.5; // E (cap 9.8 pt)
}

/// Colours: measured on the reference for the light sheet, the app's
/// palette for the dark one.
@immutable
class _Ink {
  const new({
    required this.sheet,
    required this.strong,
    required this.soft,
    required this.hairline,
    required this.track,
    required this.arrow,
    required this.chosen,
    required this.chosenText,
    required this.chosenEdge,
  });

  factory of(BuildContext context) {
    final p = context.palette;
    return Theme.of(context).brightness == Brightness.dark
        ? _Ink(
            sheet: p.surfaceRaised,
            strong: p.textPrimary,
            soft: p.textTertiary,
            hairline: p.border,
            track: p.surfaceOverlay,
            arrow: p.textTertiary,
            chosen: p.background,
            chosenText: p.textPrimary,
            chosenEdge: p.border,
          )
        : _Ink(
            sheet: const Color(0xFFFFFFFF),
            strong: const Color(0xFF26282A), // M
            soft: const Color(0xFF88898E), // M
            hairline: const Color(0xFFF0F0F0), // M
            track: const Color(0xFFF4F6F8),
            arrow: const Color(0xFFC1C1C1), // M
            chosen: p.background,
            chosenText: p.textPrimary,
            chosenEdge: p.border,
          );
  }

  final Color sheet;
  final Color strong;
  final Color soft;
  final Color hairline;
  final Color track;
  final Color arrow;

  /// D224 (owner: «التارجت تصنيفات تكون حسب نظام مختار لونها ابيض في لايت
  /// مود واسود في دارك مود»): the selected tab's and period's pill — the
  /// theme's page colour (white in the light theme, black in the dark one)
  /// with its strongest text and a hairline edge (a white pill on the
  /// white sheet stays visible).
  final Color chosen;
  final Color chosenText;
  final Color chosenEdge;

  static const amount = Color(0xFFF5BD15); // M
  static const ctaStart = Color(0xFF29E6DD); // M
  static const ctaEnd = Color(0xFF04D6E3); // M
  static const cherry = Color(0xFFFF5A7A);
  static const magic = Color(0xFFB57BFF);
  static const gold = Color(0xFFFFC547);
}

class _HostTargetSheetState extends ConsumerState<HostTargetSheet> {
  TargetTab _tab = TargetTab.cherries;
  HostStatsPeriod _period = HostStatsPeriod.day;
  HostGiftStats? _stats;
  Object? _error;
  int _request = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) unawaited(_load());
    // The countdown moves each 30 s; at the period's end the data reloads.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final end = _endsAt();
      if (end != null && !HostTargetSheet.clock().isBefore(end)) {
        if (widget.isHost) {
          unawaited(_load());
        } else {
          ref.invalidate(liveHostTargetsProvider(widget.username!));
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _error = null);
    try {
      final stats = await ref
          .read(liveHostTargetsRepositoryProvider)
          .mine(_period);
      if (mounted && request == _request) setState(() => _stats = stats);
    } on Object catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    }
  }

  void _choose(HostStatsPeriod p) {
    if (p == _period) return;
    setState(() => _period = p);
    unawaited(_load());
  }

  HostGiftStats? get _current => _stats?.period == _period ? _stats : null;

  LiveHostTargets? _publicTargets() => widget.isHost
      ? null
      : ref.watch(liveHostTargetsProvider(widget.username!)).value;

  DateTime? _endsAt() {
    if (widget.isHost) {
      return _period == HostStatsPeriod.all ? null : _current?.to;
    }
    return ref.read(liveHostTargetsProvider(widget.username!)).value?.endsAt;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = _Ink.of(context);
    final public = _publicTargets();
    final stats = _current;
    final loading = widget.isHost ? stats == null : public == null;
    final targets = widget.isHost ? stats?.targets : public;
    final list = switch ((widget.isHost, _tab)) {
      (true, TargetTab.cherries) => stats?.topSupporters,
      (true, TargetTab.lucky) => stats?.luckySupporters,
      (false, TargetTab.cherries) => public?.topSupporters,
      (false, TargetTab.lucky) => public?.luckySupporters,
    };
    final daily = !widget.isHost || _period == HostStatsPeriod.day;
    final height = MediaQuery.sizeOf(context).height * 0.75;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final Widget content;
    if (loading) {
      final error = widget.isHost
          ? _error
          : ref.watch(liveHostTargetsProvider(widget.username!)).error;
      content = Center(
        child: error == null
            ? const CircularProgressIndicator()
            : KErrorState(
                title: l10n.liveTargetLoadError,
                message: failureMessage(l10n, toAppFailure(error)),
                retryLabel: l10n.actionRetry,
                onRetry: () => widget.isHost
                    ? unawaited(_load())
                    : ref.invalidate(liveHostTargetsProvider(widget.username!)),
                compact: true,
              ),
      );
    } else {
      final people = list ?? const <HostSupporter>[];
      content = ListView(
        // M: the first row's centre 140.5 pt under the sheet's top.
        padding: const EdgeInsets.only(top: 1.7),
        children: [
          if (daily &&
              targets != null &&
              (targets.cherries.hasTarget || targets.lucky.hasTarget))
            _TargetsBlock(
              key: HostTargetSheet.targetsKey,
              targets: targets,
              ink: ink,
            ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
              child: Text(
                l10n.liveTargetNoSupporters,
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(color: ink.soft),
              ),
            )
          else
            Semantics(
              label: l10n.liveTargetTopSupporters,
              container: true,
              explicitChildNodes: true,
              child: Column(
                children: [
                  for (final (i, s) in people.indexed)
                    _Row(
                      key: HostTargetSheet.rowKey(s.user.username),
                      rank: i + 1,
                      supporter: s,
                      tab: _tab,
                      ink: ink,
                    ),
                ],
              ),
            ),
        ],
      );
    }

    return Semantics(
      key: HostTargetSheet.sheetKey,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.liveTargetChip,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ink.sheet,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_G.radius),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabs(context, ink),
            const SizedBox(height: _G.pillsTop),
            _pills(context, ink),
            const SizedBox(height: _G.countdownGap),
            _countdownLine(context, ink),
            Expanded(child: content),
            _bar(context, ink, stats: stats, public: public, bottom: bottom),
          ],
        ),
      ),
    );
  }

  /// D224: the selected tab's / period's pill ([_Ink.chosen]) of [height].
  static BoxDecoration _chosen(_Ink ink, double height) => BoxDecoration(
    color: ink.chosen,
    borderRadius: BorderRadius.circular(height / 2),
    border: Border.all(color: ink.chosenEdge, width: 0.8),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
  );

  Widget _tabs(BuildContext context, _Ink ink) {
    final l10n = context.l10n;
    final t = context.textStyles;
    Widget tab(TargetTab tab, String label) {
      final selected = tab == _tab;
      return Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          key: HostTargetSheet.tabKey(tab),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = tab),
          child: SizedBox(
            height: _G.tabsHeight,
            child: Center(
              child: Container(
                key: selected ? HostTargetSheet.chosenTabKey : null,
                height: _G.tabPill,
                // The unselected tab keeps its place and look (no pill).
                padding: const EdgeInsets.symmetric(horizontal: _G.pillPad),
                alignment: Alignment.center,
                decoration: selected ? _chosen(ink, _G.tabPill) : null,
                child: Text(
                  label,
                  maxLines: 1,
                  style: t.body.copyWith(
                    fontSize: _G.tabFont,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? ink.chosenText : ink.soft,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  tab(TargetTab.cherries, l10n.liveTargetCherriesSection),
                  // D224: the pills' padding takes part of the gap.
                  const SizedBox(width: _G.tabGap - 2 * _G.pillPad),
                  tab(TargetTab.lucky, l10n.liveTargetLuckySection),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.liveTargetClose,
            excludeSemantics: true,
            child: GestureDetector(
              key: HostTargetSheet.closeKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: KSizes.minTouchTarget - 8,
                height: _G.tabsHeight,
                child: Center(
                  child: CustomPaint(
                    size: const Size.square(_G.closeGlyph),
                    painter: _CrossPainter(ink.strong),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pills(BuildContext context, _Ink ink) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final labels = {
      HostStatsPeriod.day: l10n.liveTargetPeriodDay,
      HostStatsPeriod.week: l10n.liveTargetPeriodWeek,
      HostStatsPeriod.month: l10n.liveTargetPeriodMonth,
      HostStatsPeriod.all: l10n.liveTargetPeriodAll,
    };
    final periods = widget.isHost
        ? HostStatsPeriod.values
        : const [HostStatsPeriod.day];
    return SizedBox(
      height: _G.pillHeight,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Row(
                children: [
                  for (final (i, p) in periods.indexed) ...[
                    if (i > 0) const SizedBox(width: _G.pillGap),
                    Semantics(
                      selected: p == _period,
                      button: true,
                      child: GestureDetector(
                        key: HostTargetSheet.periodKey(p),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _choose(p),
                        child: Container(
                          height: _G.pillHeight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: _G.pillPad,
                          ),
                          alignment: Alignment.center,
                          decoration: p == _period
                              ? _chosen(ink, _G.pillHeight)
                              : null,
                          child: Text(
                            labels[p]!,
                            maxLines: 1,
                            style: t.body.copyWith(
                              fontSize: _G.pillFont,
                              height: 1.2,
                              fontWeight: p == _period
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: p == _period ? ink.chosenText : ink.soft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.liveTargetHelpTitle,
            excludeSemantics: true,
            child: GestureDetector(
              key: HostTargetSheet.helpKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_help(context)),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: 16.6),
                child: Container(
                  width: _G.help,
                  height: _G.help,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink.soft, width: 1.3),
                  ),
                  child: Text(
                    '?',
                    textDirection: TextDirection.ltr,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: KFonts.latin,
                      fontSize: 12.5,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: ink.soft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _help(BuildContext context) {
    final l10n = context.l10n;
    // D232: the live's card style.
    return showKLiveInfo(
      context,
      leading: const KLiveDialogIcon(Icons.info_outline_rounded),
      title: l10n.liveTargetHelpTitle,
      message: l10n.liveTargetHelp,
    );
  }

  String? _countdown(AppLocalizations l10n) {
    final end = _endsAt();
    if (end == null) return null;
    var left = end.difference(HostTargetSheet.clock());
    if (left.isNegative) left = Duration.zero;
    return left.inDays > 0
        ? l10n.liveTargetCountdownDays('${left.inDays}', '${left.inHours % 24}')
        : l10n.liveTargetCountdownHours(
            '${left.inHours}',
            '${left.inMinutes % 60}',
          );
  }

  Widget _countdownLine(BuildContext context, _Ink ink) {
    final l10n = context.l10n;
    final style = context.textStyles.caption.copyWith(
      fontSize: _G.smallFont,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: ink.soft,
    );
    final countdown = _countdown(l10n);
    final range = switch (_period) {
      HostStatsPeriod.day => l10n.liveTargetRangeToday,
      HostStatsPeriod.week => l10n.liveTargetRangeWeek,
      HostStatsPeriod.month => l10n.liveTargetRangeMonth,
      HostStatsPeriod.all => l10n.liveTargetRangeAll,
    };
    final rangeLabel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(range, style: style),
        if (widget.isHost) ...[
          const SizedBox(width: 7),
          CustomPaint(
            size: const Size(6, 3.8),
            painter: _TrianglePainter(ink.arrow),
          ),
        ],
      ],
    );
    return SizedBox(
      height: _G.countdownHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 14.5, end: 21),
        child: Row(
          children: [
            Expanded(
              child: countdown == null
                  ? const SizedBox.shrink()
                  : Text(
                      countdown,
                      key: HostTargetSheet.countdownKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
            ),
            if (widget.isHost)
              PopupMenuButton<HostStatsPeriod>(
                key: HostTargetSheet.rangeKey,
                tooltip: '',
                padding: EdgeInsets.zero,
                initialValue: _period,
                onSelected: _choose,
                itemBuilder: (_) => [
                  for (final p in HostStatsPeriod.values)
                    PopupMenuItem(
                      value: p,
                      child: Text(switch (p) {
                        HostStatsPeriod.day => l10n.liveTargetRangeToday,
                        HostStatsPeriod.week => l10n.liveTargetRangeWeek,
                        HostStatsPeriod.month => l10n.liveTargetRangeMonth,
                        HostStatsPeriod.all => l10n.liveTargetRangeAll,
                      }),
                    ),
                ],
                child: rangeLabel,
              )
            else
              KeyedSubtree(key: HostTargetSheet.rangeKey, child: rangeLabel),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    _Ink ink, {
    required HostGiftStats? stats,
    required LiveHostTargets? public,
    required double bottom,
  }) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final user = ref.watch(currentUserProvider);
    // A guest: nothing of their own and no button.
    if (user == null) return SizedBox(height: bottom);
    final String rank;
    final int amount;
    if (widget.isHost) {
      rank = '—';
      amount = switch (_tab) {
        TargetTab.cherries => stats?.cherries ?? 0,
        TargetTab.lucky => stats?.luckyCoins ?? 0,
      };
    } else {
      final mine = _tab == TargetTab.cherries
          ? public?.meCherries
          : public?.meLucky;
      final place = mine?.rank;
      rank = place == null || place > HostTargetSheet.listLimit
          ? '${HostTargetSheet.listLimit}+'
          : '$place';
      amount = mine?.amount ?? 0;
    }
    final Widget? cta = widget.isHost
        ? _Cta(
            key: HostTargetSheet.taskCenterKey,
            label: l10n.liveTargetTaskCenter,
            onTap: () {
              Navigator.of(context).pop();
              unawaited(context.push(AppRoutes.taskCenter));
            },
          )
        : widget.onSupport == null
        ? null
        : _Cta(
            key: HostTargetSheet.supportKey,
            label: l10n.liveTargetSupport,
            onTap: () {
              Navigator.of(context).pop();
              widget.onSupport!();
            },
          );
    return Container(
      key: HostTargetSheet.meKey,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: ink.sheet,
        border: Border(top: BorderSide(color: ink.hairline, width: 0.8)),
      ),
      child: SizedBox(
        height: _G.barHeight,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                label: l10n.liveTargetMyPlace(rank, KFormat.grouped(amount)),
                excludeSemantics: true,
                child: Row(
                  children: [
                    SizedBox(
                      width: _G.rankCentre * 2,
                      child: Text(
                        rank,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: KFonts.latin,
                          fontSize: _G.smallFont,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: ink.soft,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: (_G.avatarCentre - _G.rankCentre * 2) * 2,
                      child: Center(
                        child: KAvatar(
                          name: user.displayName,
                          imageUrl: user.avatarUrl,
                          size: _G.avatar,
                        ),
                      ),
                    ),
                    const SizedBox(width: _G.nameGap),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(
                              fontSize: _G.meNameFont,
                              height: 1.25,
                              color: ink.strong,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _Amount(
                            tab: _tab,
                            amount: amount,
                            iconSize: 10,
                            gap: 5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (cta != null) ...[
              const SizedBox(width: 8),
              cta,
              const SizedBox(width: _G.ctaEnd),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's two targets, compact in the reference's language (grey text, a
/// thin bar): between the countdown and the list on the daily tab.
class _TargetsBlock extends StatelessWidget {
  const new({required this.targets, required this.ink, super.key});

  final LiveHostTargets targets;
  final _Ink ink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = context.textStyles.caption.copyWith(
      fontSize: _G.smallFont,
      height: 1.2,
      color: ink.soft,
    );
    Widget line(Widget icon, String title, HostTarget target, Color color) {
      final value = target.hasTarget
          ? '${KFormat.grouped(target.received)} / '
                '${KFormat.grouped(target.target)}'
          : l10n.liveTargetNoTarget;
      return Semantics(
        container: true,
        label: target.reached
            ? '$title: $value, ${l10n.liveTargetReached}'
            : '$title: $value',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (target.reached) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Color(0xFF34C759),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    value,
                    textDirection: TextDirection.ltr,
                    style: style.copyWith(
                      fontWeight: FontWeight.w600,
                      color: target.reached ? _Ink.amount : ink.strong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: target.progress,
                  minHeight: 3,
                  backgroundColor: ink.track,
                  color: target.reached ? _Ink.gold : color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14.5, 0, 21, 6),
      child: Semantics(
        label: l10n.liveTargetToday,
        container: true,
        explicitChildNodes: true,
        child: Column(
          children: [
            if (targets.cherries.hasTarget)
              line(
                const KCherryIcon(size: 13),
                l10n.liveTargetCherriesGoal,
                targets.cherries,
                _Ink.cherry,
              ),
            if (targets.lucky.hasTarget)
              line(
                const KWizardHatIcon(size: 13),
                l10n.liveTargetLuckyGoal,
                targets.lucky,
                _Ink.magic,
              ),
          ],
        ),
      ),
    );
  }
}

/// One ranked person: the place (1–3 on Kabso's shields), the avatar in its
/// frame, the name over the support level, the amount on the far side.
class _Row extends StatelessWidget {
  const new({
    required this.rank,
    required this.supporter,
    required this.tab,
    required this.ink,
    super.key,
  });

  final int rank;
  final HostSupporter supporter;
  final TargetTab tab;
  final _Ink ink;

  @override
  Widget build(BuildContext context) {
    final user = supporter.user;
    final amount = tab == TargetTab.cherries
        ? supporter.cherries
        : supporter.coins;
    final art = AvatarFrameArt.of(user.avatarFrame);
    // A framed photo is smaller, so the frame keeps to the reference's box.
    final size = art == null ? _G.avatar : art.pictureForWidth(_G.framed);
    final picture = KAvatar(
      name: user.displayName,
      imageUrl: user.avatarUrl,
      size: size,
    );
    final level = supporter.supportLevel;
    return Semantics(
      container: true,
      label: '$rank. ${user.displayName}: ${KFormat.grouped(amount)}',
      excludeSemantics: true,
      child: SizedBox(
        height: _G.row,
        child: Row(
          children: [
            SizedBox(
              width: _G.rankCentre * 2,
              child: Center(
                child: rank <= 3
                    ? _Medal(rank: rank)
                    : Text(
                        '$rank',
                        textDirection: TextDirection.ltr,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: KFonts.latin,
                          fontSize: _G.rankFont,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: ink.soft,
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: (_G.avatarCentre - _G.rankCentre * 2) * 2,
              child: Center(
                child: art == null
                    ? picture
                    : FramedAvatar(art: art, picture: size, child: picture),
              ),
            ),
            const SizedBox(width: _G.nameGap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.body.copyWith(
                      fontSize: _G.nameFont,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: ink.strong,
                    ),
                  ),
                  if (level != null) ...[
                    const SizedBox(height: 3),
                    KLevelBadge(
                      category: LevelCategory.support,
                      levelNumber: level,
                      height: _G.badgeHeight,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Amount(tab: tab, amount: amount),
            const SizedBox(width: _G.rowEnd),
          ],
        ),
      ),
    );
  }
}

/// The amount with its currency (a cherry or a coin) at the reading start.
class _Amount extends StatelessWidget {
  const new({
    required this.tab,
    required this.amount,
    this.iconSize = _G.coin,
    this.gap = _G.coinGap,
  });

  final TargetTab tab;
  final int amount;
  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (tab == TargetTab.cherries)
        KCherryIcon(size: iconSize)
      else
        KabsoArtIcon(KabsoArt.coin, size: iconSize),
      SizedBox(width: gap),
      Flexible(
        child: Text(
          KFormat.grouped(amount),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: KFonts.latin,
            fontSize: _G.amountFont,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: _Ink.amount,
          ),
        ),
      ),
    ],
  );
}

/// Places 1–3: Kabso's gold, silver and bronze shields with the number.
class _Medal extends StatelessWidget {
  const new({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _G.medalWidth,
    height: _G.medalWidth * 155 / 128,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/leaderboard/rank_shield_$rank.webp',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        Text(
          '$rank',
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontFamily: KFonts.latin,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFFFFFF),
            shadows: [Shadow(color: Color(0x99000000), offset: Offset(0, 0.6))],
          ),
        ),
      ],
    ),
  );
}

/// The turquoise pill button of the bottom bar.
class _Cta extends StatelessWidget {
  const new({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: _G.ctaWidth),
        height: _G.ctaHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_G.ctaHeight / 2),
          gradient: const LinearGradient(colors: [_Ink.ctaStart, _Ink.ctaEnd]),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: context.textStyles.body.copyWith(
            fontSize: _G.ctaFont,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    ),
  );
}

class _CrossPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}

class _TrianglePainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// The sheet over the dimmed live; it keeps the room's providers even where
/// the scope sits under the navigator (as in `LiveDataNowPage`).
Future<void> _show(BuildContext context, Widget child) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    barrierColor: const Color(0x33000000),
    builder: (_) =>
        UncontrolledProviderScope(container: container, child: child),
  );
}

/// The host's own «تارجت» sheet (every period, the task center).
Future<void> showHostGiftStats(BuildContext context) =>
    _show(context, const HostTargetSheet(isHost: true));

/// A viewer's «تارجت» sheet (today; «ادعم» opens the gift panel).
Future<void> showHostTargetsPublic(
  BuildContext context,
  String username, {
  VoidCallback? onSupport,
}) => _show(
  context,
  HostTargetSheet(isHost: false, username: username, onSupport: onSupport),
);
