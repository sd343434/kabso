import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/live_leaderboard.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

export 'package:kabso_live/features/debug/live_leaderboard.dart'
    show
        LiveRankingPeriod,
        LiveViewerPreview,
        LiveViewersFilter,
        liveViewersFixture;

/// The ranks' ring colours: gold, silver, bronze.
abstract final class KLiveRanks {
  static const List<Color> rings = [
    Color(0xFFF5C518),
    Color(0xFFC9D1DB),
    Color(0xFFD08A4E),
  ];

  static Color? ring(int index) => index < rings.length ? rings[index] : null;
}

/// D80–D84 (owner, after reference captures kept outside git): the
/// viewers box, opened from the viewer count. Two tabs — **Viewers** (who
/// is here, with their levels) and **Ranking** — the leaderboard (D84:
/// periods, the Attractiveness / Wizard gift systems, the round's
/// countdown, the podium and ranks 4–10) and, pinned at the bottom, the
/// caller's own place with a button to get ranked by sending a gift.
class LiveViewersSheet extends StatefulWidget {
  const new({
    required this.viewers,
    required this.total,
    super.key,
    this.onSendGift,
    this.onOpenProfile,
    this.now = DateTime.now,
  });

  final List<LiveViewerPreview> viewers;

  /// Everyone watching (the header count).
  final int total;

  /// "Get ranked": opens the gift box (the sheet closes first).
  final VoidCallback? onSendGift;

  /// A ranked user was tapped (the sheet closes first).
  final ValueChanged<LiveViewerPreview>? onOpenProfile;
  final DateTime Function() now;

  static const sheetKey = Key('liveViewers.sheet');
  static const viewersTabKey = Key('liveViewers.tab.viewers');
  static const rankingTabKey = Key('liveViewers.tab.ranking');
  static const meKey = Key('liveViewers.me');
  static const getRankedKey = Key('liveViewers.getRanked');
  static const filterSheetKey = Key('liveViewers.filterSheet');
  static Key filterKey(LiveViewersFilter f) =>
      LeaderboardGiftFilters.categoryKey(f);
  static Key periodKey(LiveRankingPeriod p) =>
      LeaderboardPeriodBar.periodKey(p);
  static Key rowKey(int rank) => rank <= 3
      ? LeaderboardPodium.placeKey(rank)
      : LiveLeaderboard.rowKey(rank);

  static Future<void> show(
    BuildContext context, {
    required List<LiveViewerPreview> viewers,
    required int total,
    VoidCallback? onSendGift,
    ValueChanged<LiveViewerPreview>? onOpenProfile,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LiveViewersSheet(
      viewers: viewers,
      total: total,
      onSendGift: onSendGift,
      onOpenProfile: onOpenProfile,
    ),
  );

  @override
  State<LiveViewersSheet> createState() => _LiveViewersSheetState();
}

class _LiveViewersSheetState extends State<LiveViewersSheet> {
  bool _ranking = true;
  LiveViewersFilter _filter = LiveViewersFilter.attraction;
  LiveRankingPeriod _period = LiveRankingPeriod.hourly;

  /// Test data: each period's round ends a fixed time after the sheet
  /// opened (a real ranking takes the end time from the server).
  late final DateTime _opened = widget.now();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    Widget tab(
      Key key,
      String label,
      VoidCallback onTap, {
      required bool selected,
    }) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: t.title.copyWith(
                  fontSize: 16,
                  color: selected ? p.textPrimary : p.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: KMotion.of(context, KMotion.fast),
                width: selected ? 14 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final size = MediaQuery.sizeOf(context);
    return SafeArea(
      key: LiveViewersSheet.sheetKey,
      child: AnimatedContainer(
        duration: KMotion.of(context, KMotion.fast),
        // D84: the leaderboard takes nearly the whole screen.
        height: size.height * (_ranking ? 0.94 : 0.72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: KSpacing.lg),
              child: Row(
                children: [
                  // Both tabs on one line; they shrink together if needed.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: [
                          tab(
                            LiveViewersSheet.viewersTabKey,
                            l10n.liveViewersTab(KFormat.grouped(widget.total)),
                            () => setState(() => _ranking = false),
                            selected: !_ranking,
                          ),
                          const SizedBox(width: KSpacing.xl),
                          tab(
                            LiveViewersSheet.rankingTabKey,
                            l10n.liveRankingTab,
                            () => setState(() => _ranking = true),
                            selected: _ranking,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.liveClose,
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.close_rounded, color: p.textPrimary),
                  ),
                ],
              ),
            ),
            if (_ranking) ...[
              Expanded(
                child: LiveLeaderboard(
                  viewers: widget.viewers,
                  period: _period,
                  filter: _filter,
                  endsAt: switch (_period.fixtureRemaining) {
                    final left? => _opened.add(left),
                    null => null,
                  },
                  now: widget.now,
                  onPeriod: (v) => setState(() => _period = v),
                  onFilter: (v) => setState(() => _filter = v),
                  onGiftFilter: () => _chooseFilter(context),
                  onInfo: () => _help(context),
                  onOpen: widget.onOpenProfile == null
                      ? null
                      : (v) {
                          Navigator.maybePop(context);
                          widget.onOpenProfile!(v);
                        },
                ),
              ),
              _MeBar(
                filter: _filter,
                onGetRanked: () {
                  Navigator.maybePop(context);
                  widget.onSendGift?.call();
                },
              ),
            ] else
              Expanded(child: _viewersList(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _help(BuildContext context) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.liveRankingHelp),
        content: Text(l10n.liveRankingHelpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(l10n.actionContinue),
          ),
        ],
      ),
    );
  }

  /// "Gift filter": pick the gift system in a small sheet.
  Future<void> _chooseFilter(BuildContext context) async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<LiveViewersFilter>(
      context: context,
      builder: (sheet) => SafeArea(
        key: LiveViewersSheet.filterSheetKey,
        child: RadioGroup<LiveViewersFilter>(
          groupValue: _filter,
          onChanged: (v) => Navigator.of(sheet).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(l10n.liveGiftFilter)),
              for (final f in LiveViewersFilter.values)
                RadioListTile<LiveViewersFilter>(
                  value: f,
                  title: Text(LeaderboardGiftFilters.label(l10n, f)),
                  secondary: LeaderboardGiftFilters.icon(f, 24),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _filter = chosen);
  }

  Widget _viewersList(BuildContext context) {
    final t = context.textStyles;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      itemCount: widget.viewers.length,
      itemBuilder: (context, i) {
        final v = widget.viewers[i];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.lg,
            vertical: KSpacing.xs + 2,
          ),
          child: Row(
            children: [
              _Photo(viewer: v),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final c in LevelCategory.values)
                          if (v.levels[c] case final level?)
                            KLevelBadge(
                              category: c,
                              levelNumber: level,
                              height: 13,
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Photo extends StatelessWidget {
  const new({required this.viewer});

  final LiveViewerPreview viewer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(2),
    child: KAvatar(
      name: viewer.name,
      image: PreviewPhotos.asset(viewer.photo),
      size: 40,
    ),
  );
}

/// D82: the caller's own place, pinned under the list: rank (30+ while
/// outside the list), photo, name and what they sent, and a button to get
/// ranked (it opens the gift box).
class _MeBar extends StatelessWidget {
  const new({required this.filter, required this.onGetRanked});

  final LiveViewersFilter filter;
  final VoidCallback onGetRanked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      key: LiveViewersSheet.meKey,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '30+',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: t.bodyStrong.copyWith(color: p.textTertiary),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          KAvatar(
            name: l10n.liveRankingYou,
            image: PreviewPhotos.asset(PreviewPhotos.layla),
            size: 40,
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.liveRankingYou,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const KabsoArtIcon(KabsoArt.coin, size: 16),
                    const SizedBox(width: 3),
                    Text(
                      '0',
                      style: t.caption.copyWith(
                        color: const Color(0xFFFFC93C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Semantics(
            button: true,
            label: l10n.liveGetRanked,
            excludeSemantics: true,
            child: InkWell(
              key: LiveViewersSheet.getRankedKey,
              onTap: onGetRanked,
              borderRadius: BorderRadius.circular(KRadius.pill),
              child: Container(
                height: 44,
                padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4A4A), Color(0xFFE50914)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KabsoArtIcon(KabsoArt.giftBox, size: 30),
                    const SizedBox(width: 6),
                    Text(
                      l10n.liveGetRanked,
                      style: t.bodyStrong.copyWith(
                        color: Colors.white,
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
    );
  }
}
