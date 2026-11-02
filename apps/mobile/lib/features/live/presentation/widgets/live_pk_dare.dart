import 'dart:async';
import 'dart:math' as math;

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// What this device may do with a «PK أحكام» dare (null: not allowed here).
/// The losing host accepts / refuses, the winning host judges, anyone signed
/// in reports.
class PkDareActions {
  const new({this.onAccept, this.onRefuse, this.onVerdict, this.onReport});

  final Future<void> Function()? onAccept;
  final Future<void> Function()? onRefuse;
  final Future<void> Function({required bool done})? onVerdict;
  final Future<void> Function(String dareId)? onReport;
}

/// Kabso's colours of the three levels.
Color pkDareLevelColor(PkDareLevel level) => switch (level) {
  PkDareLevel.easy => const Color(0xFF22C27A),
  PkDareLevel.medium => const Color(0xFFFFB020),
  PkDareLevel.hard => const Color(0xFFE50914),
};

String pkDareLevelName(AppLocalizations l10n, PkDareLevel level) =>
    switch (level) {
      PkDareLevel.easy => l10n.pkDareLevelEasy,
      PkDareLevel.medium => l10n.pkDareLevelMedium,
      PkDareLevel.hard => l10n.pkDareLevelHard,
    };

TextScaler _scaler(BuildContext context) =>
    MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);

const _cardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xF22A0A0E), Color(0xF2120608)],
);

/// v1.50-live (D229, CONVENTIONS §10.80): «PK أحكام» in both rooms — the
/// server's draw (the three cards shuffle and land on the drawn one at
/// `revealAt`; reduced motion: the drawn card at once) over the PK stage,
/// then the loser's «قبول» / «رفض» with the decision ring, the dare's banner
/// with its 3:00 countdown, the winner's «نُفّذ ✅» / «لم يُنفّذ ❌», and the
/// outcome — D238: those in [PkDareDock], the small card at the bottom of
/// the room. The text is the app's language; the server decides everything.
///
/// This layer is the draw only (nothing in the other phases).
class PkDareLayer extends StatefulWidget {
  const new({
    required this.match,
    required this.dare,
    required this.roomId,
    required this.now,
    super.key,
    this.ticks = true,
  });

  final PkMatch match;
  final PkDare dare;

  /// This screen's room.
  final String roomId;
  final DateTime Function() now;

  /// The shuffle animates (off in widget tests and goldens).
  final bool ticks;

  /// The dare's semantics container: the draw here, the card in the dock
  /// (one at a time).
  static const layerKey = Key('pk.dare');
  static const drawKey = Key('pk.dare.draw');
  static const decideKey = Key('pk.dare.decide');
  static const acceptKey = Key('pk.dare.accept');
  static const refuseKey = Key('pk.dare.refuse');
  static const refuseConfirmKey = Key('pk.dare.refuse.confirm');
  static const waitingKey = Key('pk.dare.waiting');
  static const bannerKey = Key('pk.dare.banner');
  static const timerKey = Key('pk.dare.timer');
  static const doneKey = Key('pk.dare.done');
  static const notDoneKey = Key('pk.dare.notDone');
  static const reportKey = Key('pk.dare.report');
  static const outcomeKey = Key('pk.dare.outcome');
  static Key cardKey(int i) => Key('pk.dare.card.$i');

  /// Goldens: the countdowns pinned (the timer's time left, the ring's
  /// seconds), so a slow run never moves them (as `PkPowerBanner`).
  @visibleForTesting
  static Duration? debugRemaining;
  @visibleForTesting
  static int? debugDecideSeconds;

  @override
  State<PkDareLayer> createState() => _PkDareLayerState();
}

class _PkDareLayerState extends State<PkDareLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shuffle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 540),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PkDareLayer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final drawing =
        widget.dare.statusAt(widget.now()) == PkDareStatus.drawing &&
        widget.ticks &&
        !MediaQuery.disableAnimationsOf(context);
    if (drawing && !_shuffle.isAnimating) {
      _shuffle.repeat();
    } else if (!drawing && _shuffle.isAnimating) {
      _shuffle.stop();
    }
  }

  @override
  void dispose() {
    _shuffle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dare = widget.dare;
    if (dare.statusAt(widget.now()) != PkDareStatus.drawing) {
      return const SizedBox.shrink();
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: PkDareLayer.layerKey,
      container: true,
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
            child: AnimatedBuilder(
              animation: _shuffle,
              builder: (context, _) => PkDareCards(
                key: PkDareLayer.drawKey,
                options: dare.options,
                // The highlight runs over the three cards; reduced motion
                // (or no animation): the drawn card at once.
                highlight: reduced || !_shuffle.isAnimating
                    ? dare.drawn
                    : (_shuffle.value * 3).floor().clamp(0, 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D238 (owner, 2026-11-02: «اجعل صندوق اصغر ويظهر في الاسفل»): the dare's
/// card after the draw — the loser's decision, the banner (the winner
/// judges; everyone else reads it) and the outcome — small, docked at the
/// bottom of the room above the bar (`KLiveRoomScaffold.dock`), so both
/// videos stay in sight. A dense [KLiveDialogCard]: the level pill and the
/// ring / timer on one header row, the dare in 15 lp (3 lines at most), the
/// two 40 lp buttons side by side (the red primary at the reading start).
/// Same content, timings and states as D236's card; nothing while drawing.
class PkDareDock extends StatefulWidget {
  const new({
    required this.match,
    required this.dare,
    required this.roomId,
    required this.now,
    super.key,
    this.isHost = false,
    this.actions = const PkDareActions(),
    this.ticks = true,
  });

  final PkMatch match;
  final PkDare dare;

  /// This screen's room.
  final String roomId;

  /// This device is [roomId]'s host.
  final bool isHost;
  final PkDareActions actions;
  final DateTime Function() now;

  /// The countdowns rebuild every second (off in widget tests and goldens).
  final bool ticks;

  /// D238: the dare text's size on the docked card.
  static const double textSize = 15;

  /// D238: the ring on the docked card's header row.
  static const double ring = 32;

  @override
  State<PkDareDock> createState() => _PkDareDockState();
}

class _PkDareDockState extends State<PkDareDock> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.ticks) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) KSnack.error(context, pkDareFailureMessage(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refuse() async {
    final l10n = context.l10n;
    // D232: the live's card style (red confirm, outlined cancel).
    final ok = await showKLiveConfirm(
      context,
      title: l10n.pkDareRefuseTitle,
      message: l10n.pkDareRefuseBody(KFormat.signed(widget.dare.refusePoints)),
      confirmKey: PkDareLayer.refuseConfirmKey,
      confirmLabel: l10n.pkDareRefuse,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    );
    if (ok) await _run(widget.actions.onRefuse);
  }

  Future<void> _report(String dareId) async {
    final report = widget.actions.onReport;
    if (report == null) return;
    await _run(() async {
      await report(dareId);
      if (mounted) KSnack.info(context, context.l10n.pkDareReported);
    });
  }

  String _loserName() {
    final (a, b) = widget.match.sides;
    final loser = a.roomId == widget.dare.loserRoomId ? a : b;
    return loser.host.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now();
    final child = switch (widget.dare.statusAt(now)) {
      PkDareStatus.drawing || PkDareStatus.cancelled => null,
      PkDareStatus.deciding => _deciding(context, now),
      PkDareStatus.active => _banner(context, now),
      _ => _outcome(context),
    };
    if (child == null) return const SizedBox.shrink();
    return Semantics(
      key: PkDareLayer.layerKey,
      container: true,
      liveRegion: true,
      child: Center(child: child),
    );
  }

  /// D236 (owner: «نفس ستايل تابع واخرج»): the shared live card — the
  /// white card with the red wash (dark: the card's own dark surface), dark
  /// ink, the red primary and the outlined secondary. D238: dense (see
  /// [PkDareDock]).
  Widget _card({
    required Key key,
    required List<Widget> header,
    required List<Widget> below,
    List<KLiveDialogAction> actions = const [],
    String? semanticsLabel,
  }) => KLiveDialogCard(
    key: key,
    semanticsLabel: semanticsLabel,
    padding: KLiveDialogCard.densePadding,
    dense: true,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: PkDareDock.ring,
          child: Row(children: header),
        ),
        const SizedBox(height: KSpacing.xxs),
        ...below,
      ],
    ),
    actions: actions,
  );

  Widget _text(BuildContext context, PkDareOption option, {int maxLines = 3}) =>
      Text(
        option.text(Localizations.localeOf(context)),
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textScaler: _scaler(context),
        style: context.textStyles.body.copyWith(
          color: KLiveDialogCard.inkOf(context),
          fontSize: PkDareDock.textSize,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      );

  Widget _soft(
    BuildContext context,
    String text, {
    Key? key,
    TextAlign align = TextAlign.start,
  }) => Text(
    text,
    key: key,
    textAlign: align,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textScaler: _scaler(context),
    style: context.textStyles.caption.copyWith(
      color: KLiveDialogCard.softInkOf(context),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _deciding(BuildContext context, DateTime now) {
    final l10n = context.l10n;
    final dare = widget.dare;
    final option = dare.chosen;
    if (option == null) return const SizedBox.shrink();
    final total = math.max(
      1,
      dare.decideBy.difference(dare.revealAt).inSeconds,
    );
    final left =
        PkDareLayer.debugDecideSeconds ??
        math.max(0, dare.decideBy.difference(now).inSeconds);
    final loser = widget.isHost && dare.loserRoomId == widget.roomId;
    return _card(
      key: PkDareLayer.decideKey,
      semanticsLabel: option.text(Localizations.localeOf(context)),
      header: [
        PkDareLevelChip(level: option.level, onCard: true),
        const SizedBox(width: KSpacing.xs),
        // D238: the role line on the header row (saves a line): «حكمك» for
        // the loser, «{name} يقرّر…» for everyone else.
        Expanded(
          child: loser
              ? Text(
                  l10n.pkDareYourDare,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: _scaler(context),
                  style: context.textStyles.caption.copyWith(
                    color: context.palette.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : _soft(
                  context,
                  l10n.pkDareLoserDeciding(KFormat.bidiIsolate(_loserName())),
                  key: PkDareLayer.waitingKey,
                ),
        ),
        const SizedBox(width: KSpacing.xs),
        PkDareRing(
          seconds: left,
          fraction: left / total,
          onCard: true,
          size: PkDareDock.ring,
        ),
      ],
      below: [_text(context, option)],
      actions: [
        if (loser) ...[
          KLiveDialogAction(
            key: PkDareLayer.acceptKey,
            label: l10n.pkDareAccept,
            primary: true,
            loading: _busy,
            onPressed: () => unawaited(_run(widget.actions.onAccept)),
          ),
          KLiveDialogAction(
            key: PkDareLayer.refuseKey,
            label: l10n.pkDareRefuse,
            onPressed: _busy ? null : () => unawaited(_refuse()),
          ),
        ],
      ],
    );
  }

  Widget _banner(BuildContext context, DateTime now) {
    final l10n = context.l10n;
    final dare = widget.dare;
    final option = dare.chosen;
    if (option == null) return const SizedBox.shrink();
    final ends = dare.endsAt ?? now;
    final left =
        PkDareLayer.debugRemaining ??
        (ends.isAfter(now) ? ends.difference(now) : Duration.zero);
    final winner = widget.isHost && dare.winnerRoomId == widget.roomId;
    final time = KFormat.countdown(left);
    final ink = KLiveDialogCard.inkOf(context);
    return Semantics(
      label: l10n.pkDareSemantics(
        option.text(Localizations.localeOf(context)),
        time,
      ),
      child: _card(
        key: PkDareLayer.bannerKey,
        header: [
          PkDareLevelChip(level: option.level, onCard: true),
          const SizedBox(width: KSpacing.xs),
          Container(
            key: PkDareLayer.timerKey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Text(
              time,
              textDirection: TextDirection.ltr,
              textScaler: _scaler(context),
              style: context.textStyles.label.copyWith(
                color: ink,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          // D238: the winner's «هل نُفّذ الحكم؟» on the header row.
          Expanded(
            child: winner
                ? _soft(context, l10n.pkDareJudge)
                : const SizedBox.shrink(),
          ),
          if (widget.actions.onReport != null)
            IconButton(
              key: PkDareLayer.reportKey,
              tooltip: l10n.pkDareReport,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: PkDareDock.ring + 8,
                height: PkDareDock.ring,
              ),
              onPressed: _busy ? null : () => unawaited(_report(option.id)),
              icon: Icon(
                Icons.warning_amber_rounded,
                color: context.palette.primaryText,
                size: 20,
              ),
            ),
        ],
        below: [_text(context, option)],
        actions: [
          if (winner) ...[
            KLiveDialogAction(
              key: PkDareLayer.doneKey,
              label: l10n.pkDareDone,
              primary: true,
              loading: _busy,
              onPressed: () => unawaited(
                _run(() async {
                  await widget.actions.onVerdict?.call(done: true);
                }),
              ),
            ),
            KLiveDialogAction(
              key: PkDareLayer.notDoneKey,
              label: l10n.pkDareNotDone,
              onPressed: _busy
                  ? null
                  : () => unawaited(
                      _run(() async {
                        await widget.actions.onVerdict?.call(done: false);
                      }),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _outcome(BuildContext context) {
    final l10n = context.l10n;
    final dare = widget.dare;
    final done = dare.status == PkDareStatus.done;
    final text = done
        ? l10n.pkDareOutcomeDone
        : dare.notDone
        ? l10n.pkDareOutcomeNotDone
        : l10n.pkDareOutcomeRefused;
    final option = dare.chosen;
    return KLiveDialogCard(
      key: PkDareLayer.outcomeKey,
      padding: KLiveDialogCard.densePadding,
      dense: true,
      semanticsLabel: text,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: _scaler(context),
            style: context.textStyles.bodyStrong.copyWith(
              fontSize: 16,
              color: done
                  ? KLiveDialogCard.inkOf(context)
                  : context.palette.primaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (option != null) ...[
            const SizedBox(height: KSpacing.xxs),
            _text(context, option, maxLines: 2),
          ],
          if (!done && dare.points != 0) ...[
            const SizedBox(height: KSpacing.xxs),
            _soft(
              context,
              l10n.pkRecordPoints(KFormat.signed(dare.points)),
              align: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// The three cards of the draw (EASY, MEDIUM, HARD); [highlight] is the card
/// lit now (the shuffle, then the drawn one).
class PkDareCards extends StatelessWidget {
  const new({required this.options, required this.highlight, super.key});

  final List<PkDareOption> options;
  final int highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.pkDareDrawSemantics,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.pkDareDrawTitle,
            textScaler: _scaler(context),
            style: context.textStyles.label.copyWith(
              color: const Color(0xFFFFC94D),
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6)],
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _Card(
                    key: PkDareLayer.cardKey(i),
                    option: options[i],
                    lit: i == highlight,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const new({required this.option, required this.lit, super.key});

  final PkDareOption option;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final color = pkDareLevelColor(option.level);
    return AnimatedScale(
      scale: lit ? 1.06 : 0.94,
      duration: const Duration(milliseconds: 120),
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: _cardGradient,
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: lit ? color : const Color(0x55FFFFFF),
            width: lit ? 2.5 : 1,
          ),
          boxShadow: [
            if (lit)
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14),
          ],
        ),
        child: Column(
          children: [
            PkDareLevelChip(level: option.level, dense: true),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Text(
                  option.text(Localizations.localeOf(context)),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  textScaler: _scaler(context),
                  style: context.textStyles.caption.copyWith(
                    color: lit
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xB3FFFFFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.25,
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

/// «سهل» / «متوسط» / «صعب» in the level's colour.
///
/// D236: [onCard] — on the live card ([KLiveDialogCard]) a small red-tinted
/// pill (brand red at 12 %, the theme's red text ≥ 4.5:1 on the card).
class PkDareLevelChip extends StatelessWidget {
  const new({
    required this.level,
    super.key,
    this.dense = false,
    this.onCard = false,
  });

  final PkDareLevel level;
  final bool dense;
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final red = context.palette.primaryText;
    final color = onCard ? red : pkDareLevelColor(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: onCard
            ? KBrandColors.red500.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: onCard ? null : Border.all(color: color),
      ),
      child: Text(
        pkDareLevelName(context.l10n, level),
        textScaler: _scaler(context),
        style: context.textStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: dense ? 10 : null,
        ),
      ),
    );
  }
}

/// The loser's decision ring (seconds left, the arc shrinking).
///
/// D236: [onCard] — on the live card a red arc (the theme's `primary`) over
/// a faint track, the seconds in the card's ink.
class PkDareRing extends StatelessWidget {
  const new({
    required this.seconds,
    required this.fraction,
    super.key,
    this.onCard = false,
    this.size = 40,
  });

  final int seconds;
  final double fraction;
  final bool onCard;

  /// The ring's side (D238: 32 on the docked card).
  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = onCard
        ? KLiveDialogCard.inkOf(context)
        : const Color(0xFFFFFFFF);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: fraction.clamp(0, 1),
            strokeWidth: size < 40 ? 3 : 3.5,
            backgroundColor: onCard
                ? ink.withValues(alpha: 0.12)
                : const Color(0x33FFFFFF),
            valueColor: AlwaysStoppedAnimation(
              onCard ? context.palette.primary : const Color(0xFFFFC94D),
            ),
          ),
          Text(
            '$seconds',
            textDirection: TextDirection.ltr,
            textScaler: _scaler(context),
            style: context.textStyles.label.copyWith(
              color: ink,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The message of a refused dare action (409 `PK_DARE_CLOSED`, else generic).
String pkDareFailureMessage(AppLocalizations l10n, Object error) {
  final failure = toAppFailure(error);
  final code = failure is ServerFailure ? failure.rawCode : null;
  return code == 'PK_DARE_CLOSED'
      ? l10n.pkFailureDareClosed
      : failureMessage(l10n, failure);
}
