import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The layouts of the live preview (D71): one host, a 1-v-1 PK, or a
/// 2-v-2 PK.
enum LivePreviewMode { solo, pk2, pk4 }

/// PK stage geometry from the owner's references (923×2000 px phone
/// captures, 430 lp wide: 2.1465 px/lp). M = measured, E = estimated.
abstract final class KLivePreviewPk {
  /// The stage starts under the second chip row (M: 388 px).
  /// D71 owner follow-up: a taller, more finished bar than the
  /// reference's 17 lp.
  static const double barHeight = 22;

  /// D73: Kabi on the seam is 58 lp (owner: about 2.6 × the bar's
  /// height); he and the flames rise about 40 lp above the bar, which
  /// `headerToStage` leaves free.
  static const double timerHeight = 20; // M: 42 px
  static const double timerWidth = 128; // M: 275 px
  static const double pk2Height = 374; // M: 423–1225 px
  static const double pk4Height = 389; // M: 423–1258 px
  static const double seam = 2; // M: 4 px
  static const double paneInset = 6; // E
  static const double pillHeight = 22; // M: 46 px
  static const double followDot = 18; // E
  static const double supporterAvatar = 28; // M: 60 px
  static const double supporterGap = 4; // E
  static const double supportersTop = 8; // M: 18 px

  /// Team fills, top → bottom (owner, D71): the host's team in Kabso red,
  /// the opponents in blazing orange; the host's team on the start side
  /// (D36, mirrors in Arabic). The last colour is the team's solid colour.
  static const List<Color> startTeam = [
    Color(0xFFFF4A4A),
    Color(0xFFE50914),
    Color(0xFFA3000B),
  ];
  static const List<Color> endTeam = [
    Color(0xFFFFC94D),
    Color(0xFFFF7A00),
    Color(0xFFD94400),
  ];
  static const Color glass = Color(0x59000000);

  /// [KabsoPkBar] fills, outer edge → seam, from the team colours above.
  static final List<Color> startFill = startTeam.reversed.toList();
  static final List<Color> endFill = endTeam.reversed.toList();

  /// The win / lose / draw animations on each side after a round.
  static const double outcomeBattle = 150;
}

/// One person in a PK (labelled test data).
@immutable
class PkPanePreview {
  const new({
    required this.name,
    required this.photo,
    required this.score,
    this.host = false,
    this.muted = false,
    this.gift,
  });

  final String name;

  /// Index of a portrait preview photo (`PreviewPhotos.portrait`).
  final int photo;
  final int score;
  final bool host;
  final bool muted;

  /// A gift banner across the pane: (gift, count, sender).
  final (GiftShape, int, String)? gift;
}

/// A labelled test PK: the start team and the end team (1 or 2 each),
/// their top supporters, the time left and the battle animation that
/// plays when the preview opens.
@immutable
class PkPreview {
  const new({
    required this.start,
    required this.end,
    required this.startSupporters,
    required this.endSupporters,
    required this.timeLeft,
    this.opening,
    this.outcome,
  });

  final List<PkPanePreview> start;
  final List<PkPanePreview> end;
  final List<String> startSupporters;
  final List<String> endSupporters;
  final Duration timeLeft;

  /// Played in the middle of the stage when the preview opens.
  final KabsoBattle? opening;

  /// Set when the round is over.
  final PkOutcome? outcome;

  /// The same PK at another moment of a (simulated) round.
  PkPreview at({
    required int startScore,
    required int endScore,
    required Duration timeLeft,
    PkOutcome? outcome,
  }) {
    // Each team's points go to its first person (the simulator plays 1-v-1).
    List<PkPanePreview> scored(List<PkPanePreview> team, int score) => [
      for (final (i, p) in team.indexed)
        PkPanePreview(
          name: p.name,
          photo: p.photo,
          score: i == 0
              ? score - team.skip(1).fold(0, (s, q) => s + q.score)
              : p.score,
          host: p.host,
          muted: p.muted,
          gift: p.gift,
        ),
    ];
    return PkPreview(
      start: scored(start, startScore),
      end: scored(end, endScore),
      startSupporters: startSupporters,
      endSupporters: endSupporters,
      timeLeft: timeLeft,
      opening: opening,
      outcome: outcome,
    );
  }

  int get startScore => start.fold(0, (s, p) => s + p.score);
  int get endScore => end.fold(0, (s, p) => s + p.score);
}

PkPreview pkPreviewFixture({required LivePreviewMode mode, required bool ar}) {
  String n(String a, String e) => ar ? '$a (تجربة)' : '$e (test)';
  return switch (mode) {
    LivePreviewMode.pk4 => PkPreview(
      start: [
        PkPanePreview(
          name: n('سارة', 'Sara'),
          photo: 0,
          score: 532700,
          host: true,
        ),
        PkPanePreview(
          name: n('ليلى', 'Layla'),
          photo: 3,
          score: 124100,
          muted: true,
        ),
      ],
      end: [
        PkPanePreview(
          name: n('كريم', 'Karim'),
          photo: 1,
          score: 503400,
          muted: true,
        ),
        PkPanePreview(
          name: n('زياد', 'Ziad'),
          photo: 2,
          score: 130900,
          muted: true,
          gift: (GiftShape.crown, 6, n('عمر', 'Omar')),
        ),
      ],
      startSupporters: [n('هند', 'Hind'), n('نور', 'Nour'), n('سامي', 'Sami')],
      endSupporters: [n('عمر', 'Omar'), n('رنا', 'Rana'), n('خالد', 'Khalid')],
      timeLeft: const Duration(minutes: 2, seconds: 45),
      opening: KabsoBattle.start,
    ),
    _ => PkPreview(
      start: [
        PkPanePreview(
          name: n('سارة', 'Sara'),
          photo: 0,
          score: 7976,
          host: true,
        ),
      ],
      end: [PkPanePreview(name: n('كريم', 'Karim'), photo: 1, score: 2020)],
      startSupporters: [n('هند', 'Hind'), n('نور', 'Nour'), n('سامي', 'Sami')],
      endSupporters: [n('عمر', 'Omar'), n('رنا', 'Rana'), n('خالد', 'Khalid')],
      timeLeft: const Duration(seconds: 6),
      opening: KabsoBattle.win,
    ),
  };
}

/// The PK stage (D71): score bar with Kabi on the seam, the round timer
/// hanging under it, the panes (1-v-1 side by side, 2-v-2 in a grid; the
/// start team on the start side), the owner's battle animation in the
/// middle while [battle] is set, and the top three supporters per team.
class LivePreviewPkStage extends StatelessWidget {
  const new({
    required this.pk,
    super.key,
    this.battle,
    this.battleRun = 0,
    this.onBattleDone,
    this.showOutcome = false,
  });

  final PkPreview pk;

  /// The battle animation playing now, if any.
  final KabsoBattle? battle;

  /// Bumped to play [battle] again from the start.
  final int battleRun;
  final VoidCallback? onBattleDone;

  /// Plays win / lose / draw on each team's side for [PkPreview.outcome]
  /// (the screen sets it about 600 ms after the result).
  final bool showOutcome;

  static const barKey = Key('livePreview.pk.bar');
  static const timerKey = Key('livePreview.pk.timer');
  static const battleKey = Key('livePreview.pk.battle');
  static const startOutcomeKey = Key('livePreview.pk.outcome.start');
  static const endOutcomeKey = Key('livePreview.pk.outcome.end');
  static Key paneKey(String name) => Key('livePreview.pk.pane.$name');

  @override
  Widget build(BuildContext context) {
    final four = pk.start.length > 1;
    final battle = this.battle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreBar(
          key: barKey,
          start: pk.startScore,
          end: pk.endScore,
          remaining: pk.timeLeft,
          outcome: pk.outcome,
        ),
        SizedBox(
          height: four ? KLivePreviewPk.pk4Height : KLivePreviewPk.pk2Height,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Column(panes: pk.start, four: four),
                  ),
                  const SizedBox(width: KLivePreviewPk.seam),
                  Expanded(
                    child: _Column(panes: pk.end, four: four),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.topCenter,
                child: _RoundTimer(key: timerKey, left: pk.timeLeft),
              ),
              if (pk.outcome case final outcome? when showOutcome) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: KabsoBattleEmoji(
                    key: startOutcomeKey,
                    switch (outcome) {
                      PkOutcome.startWins => KabsoBattle.win,
                      PkOutcome.endWins => KabsoBattle.lose,
                      PkOutcome.draw => KabsoBattle.draw,
                    },
                    size: KLivePreviewPk.outcomeBattle,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: KabsoBattleEmoji(key: endOutcomeKey, switch (outcome) {
                    PkOutcome.startWins => KabsoBattle.lose,
                    PkOutcome.endWins => KabsoBattle.win,
                    PkOutcome.draw => KabsoBattle.draw,
                  }, size: KLivePreviewPk.outcomeBattle),
                ),
              ],
              if (battle != null)
                Center(
                  child: KeyedSubtree(
                    key: battleKey,
                    child: KabsoBattleEmoji(
                      battle,
                      key: ValueKey((battle, battleRun)),
                      onDone: onBattleDone,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: KLivePreviewPk.supportersTop),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: _Supporters(
                  names: pk.startSupporters,
                  colors: KLivePreviewPk.startTeam,
                  start: true,
                ),
              ),
              Expanded(
                child: _Supporters(
                  names: pk.endSupporters,
                  colors: KLivePreviewPk.endTeam,
                  start: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Who won a PK round, from the teams' point of view (start = the host's
/// team).
enum PkOutcome { startWins, endWins, draw }

/// The score bar (D73): the owner's [KabsoPkBar] with Kabi living on the
/// seam. The bar is laid out left-to-right; the host's team is on the
/// reading start (D36), so in Arabic it is the right-hand team.
class _ScoreBar extends StatelessWidget {
  const new({
    required this.start,
    required this.end,
    required this.remaining,
    required this.outcome,
    super.key,
  });

  final int start;
  final int end;
  final Duration remaining;
  final PkOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final startIsLeft = Directionality.of(context) == TextDirection.ltr;
    final result = switch (outcome) {
      null => null,
      PkOutcome.draw => KabsoPkResult.draw,
      PkOutcome.startWins =>
        startIsLeft ? KabsoPkResult.leftWins : KabsoPkResult.rightWins,
      PkOutcome.endWins =>
        startIsLeft ? KabsoPkResult.rightWins : KabsoPkResult.leftWins,
    };
    return Semantics(
      label: l10n.pkScoreSemantics(
        KFormat.grouped(start),
        KFormat.grouped(end),
      ),
      excludeSemantics: true,
      child: RepaintBoundary(
        child: KabsoPkBar(
          left: startIsLeft ? start : end,
          right: startIsLeft ? end : start,
          // Whole seconds: the bar rebuilds only when something changes.
          remaining: Duration(seconds: remaining.inSeconds),
          result: result,
          // height 22 (barHeight) and kabiSize 58 are the widget's
          // defaults.
          leftColors: startIsLeft
              ? KLivePreviewPk.startFill
              : KLivePreviewPk.endFill,
          rightColors: startIsLeft
              ? KLivePreviewPk.endFill
              : KLivePreviewPk.startFill,
          formatScore: KFormat.grouped,
        ),
      ),
    );
  }
}

/// The round's time, hanging from the bar on the seam.
class _RoundTimer extends StatelessWidget {
  const new({required this.left, super.key});

  final Duration left;

  @override
  Widget build(BuildContext context) => Container(
    height: KLivePreviewPk.timerHeight,
    constraints: const BoxConstraints(minWidth: KLivePreviewPk.timerWidth),
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xCC1A0A06), Color(0x991A0A06)],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(KRadius.md)),
      // A faint ember glow (a partial border cannot take a radius).
      boxShadow: [BoxShadow(color: Color(0x40FF7A00), blurRadius: 6)],
    ),
    // Hugs its label (an aligned Container would fill the width).
    child: Center(
      widthFactor: 1,
      child: Text(
        context.l10n.pkFinalRound(KFormat.countdown(left)),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
        style: context.textStyles.label.copyWith(
          fontWeight: FontWeight.w800,
          color: KPalette.dark.textPrimary,
        ),
      ),
    ),
  );
}

/// One team's panes: one tall pane, or two stacked.
class _Column extends StatelessWidget {
  const new({required this.panes, required this.four});

  final List<PkPanePreview> panes;
  final bool four;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, pane) in panes.indexed) ...[
        if (i > 0) const SizedBox(height: KLivePreviewPk.seam),
        Expanded(
          child: _Pane(
            key: LivePreviewPkStage.paneKey(pane.name),
            pane: pane,
            showScore: four,
          ),
        ),
      ],
    ],
  );
}

class _Pane extends StatelessWidget {
  const new({required this.pane, required this.showScore, super.key});

  final PkPanePreview pane;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    final t = context.textStyles;
    final gift = pane.gift;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: l10n.liveVideoPlaceholder,
            child: PreviewPhoto(
              pane.photo + 1,
              photoSeed: pane.photo,
              // Faces sit in the upper half of the portrait photos.
              alignment: const Alignment(0, -0.45),
            ),
          ),
          if (gift != null)
            PositionedDirectional(
              start: KLivePreviewPk.paneInset,
              end: KLivePreviewPk.paneInset,
              bottom: KLivePreviewPk.paneInset * 2 + KLivePreviewPk.pillHeight,
              child: _GiftBanner(gift: gift),
            ),
          PositionedDirectional(
            start: KLivePreviewPk.paneInset,
            end: KLivePreviewPk.paneInset,
            bottom: KLivePreviewPk.paneInset,
            child: Row(
              children: [
                // On narrow panes the score shrinks before the name pill
                // loses its controls.
                if (showScore)
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: _Pill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const KGiftArt(shape: GiftShape.heart, size: 14),
                            const SizedBox(width: KSpacing.xxs),
                            Text(
                              KFormat.compact(pane.score, l10n),
                              textScaler: scaler,
                              style: t.caption.copyWith(
                                fontWeight: FontWeight.w800,
                                color: white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: KSpacing.xs),
                // The name pill takes what is left and truncates the name.
                if (!pane.host)
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _Pill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pane.muted) ...[
                              Semantics(
                                label: l10n.livePreviewMuted,
                                child: Icon(
                                  Icons.volume_off_rounded,
                                  size: 14,
                                  color: white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: KSpacing.xxs),
                            ],
                            Flexible(
                              child: Text(
                                pane.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textScaler: scaler,
                                style: t.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: white,
                                ),
                              ),
                            ),
                            const SizedBox(width: KSpacing.xs),
                            Semantics(
                              button: true,
                              label: l10n.liveFollow,
                              excludeSemantics: true,
                              child: Container(
                                width: KLivePreviewPk.followDot,
                                height: KLivePreviewPk.followDot,
                                decoration: BoxDecoration(
                                  color: KPalette.dark.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add, size: 14, color: white),
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
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: KLivePreviewPk.pillHeight),
    padding: const EdgeInsetsDirectional.only(
      start: KSpacing.sm,
      end: KSpacing.xxs + 1,
    ),
    decoration: BoxDecoration(
      color: KLivePreviewPk.glass,
      borderRadius: BorderRadius.circular(KLivePreviewPk.pillHeight / 2),
    ),
    child: Center(widthFactor: 1, child: child),
  );
}

/// A gift banner across a pane: the gift, ×N and who sent it.
class _GiftBanner extends StatelessWidget {
  const new({required this.gift});

  final (GiftShape, int, String) gift;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (shape, count, sender) = gift;
    final name = switch (shape) {
      GiftShape.heart => l10n.giftNameHeart,
      GiftShape.star => l10n.giftNameStar,
      GiftShape.diamond => l10n.giftNameDiamond,
      GiftShape.crown => l10n.giftNameCrown,
    };
    final white = KPalette.dark.textPrimary;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        height: KLivePreviewPk.pillHeight + 4,
        padding: const EdgeInsetsDirectional.only(
          start: KSpacing.sm,
          end: KSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [
              KBrandColors.gold.withValues(alpha: 0.85),
              KLivePreviewPk.glass,
            ],
          ),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.giftCombo(count),
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
              style: context.textStyles.label.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900,
                color: white,
              ),
            ),
            const SizedBox(width: KSpacing.xxs),
            KGiftArt(shape: shape, size: 18),
            const SizedBox(width: KSpacing.xs),
            Flexible(
              child: Text(
                l10n.livePreviewGiftSent(sender, name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                style: context.textStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A team's top three, rank 1 nearest the seam, ringed in the team colour.
class _Supporters extends StatelessWidget {
  const new({required this.names, required this.colors, required this.start});

  final List<String> names;
  final List<Color> colors;
  final bool start;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = names.take(3).toList();
    // Edge → seam: 3, 2, 1 on the start side; 1, 2, 3 on the end side.
    final ordered = [for (final (i, n) in top.indexed) (i + 1, n)];
    final shown = start ? ordered.reversed.toList() : ordered;
    final separator = Directionality.of(context) == TextDirection.rtl
        ? '، '
        : ', ';
    return Align(
      alignment: start
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Semantics(
        label: l10n.pkSupporters(top.join(separator)),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (rank, name)) in shown.indexed) ...[
              if (i > 0) const SizedBox(width: KLivePreviewPk.supporterGap),
              SizedBox(
                width: KLivePreviewPk.supporterAvatar + 4,
                height: KLivePreviewPk.supporterAvatar + 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors),
                      ),
                      child: KAvatar(
                        name: name,
                        size: KLivePreviewPk.supporterAvatar,
                      ),
                    ),
                    PositionedDirectional(
                      end: -2,
                      bottom: -3,
                      child: Text(
                        '$rank',
                        textScaler: TextScaler.noScaling,
                        style: context.textStyles.label.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: colors[1],
                          shadows: [
                            for (final o in const [
                              Offset(1, 1),
                              Offset(-1, -1),
                              Offset(1, -1),
                              Offset(-1, 1),
                            ])
                              Shadow(
                                color: KPalette.dark.textPrimary,
                                offset: o,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
