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

/// v1.50-live (D229, CONVENTIONS §10.80): «PK أحكام» over the PK stage in both
/// rooms — the server's draw (the three cards shuffle and land on the drawn
/// one at `revealAt`; reduced motion: the drawn card at once), the loser's
/// «قبول» / «رفض» with the decision ring, the dare's banner with its 3:00
/// countdown, the winner's «نُفّذ ✅» / «لم يُنفّذ ❌», and the outcome. The
/// text is the app's language; the server decides everything.
class PkDareLayer extends StatefulWidget {
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

  /// The shuffle animates (off in widget tests and goldens).
  final bool ticks;

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
  bool _busy = false;

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
    final dare = widget.dare;
    final now = widget.now();
    final status = dare.statusAt(now);
    if (status == PkDareStatus.cancelled) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final child = switch (status) {
      PkDareStatus.drawing => AnimatedBuilder(
        animation: _shuffle,
        builder: (context, _) => PkDareCards(
          key: PkDareLayer.drawKey,
          options: dare.options,
          // The highlight runs over the three cards; reduced motion (or no
          // animation): the drawn card at once.
          highlight: reduced || !_shuffle.isAnimating
              ? dare.drawn
              : (_shuffle.value * 3).floor().clamp(0, 2),
        ),
      ),
      PkDareStatus.deciding => _deciding(context, now),
      PkDareStatus.active => _banner(context, now),
      _ => _outcome(context),
    };
    return Semantics(
      key: PkDareLayer.layerKey,
      container: true,
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _frame({required Widget child, Key? key, Color? border}) => Container(
    key: key,
    padding: const EdgeInsets.all(KSpacing.sm),
    decoration: BoxDecoration(
      gradient: _cardGradient,
      borderRadius: BorderRadius.circular(KRadius.lg),
      border: Border.all(color: border ?? const Color(0xFFFFC94D), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 16)],
    ),
    child: child,
  );

  Widget _text(BuildContext context, PkDareOption option, {int maxLines = 3}) =>
      Text(
        option.text(Localizations.localeOf(context)),
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textScaler: _scaler(context),
        style: context.textStyles.body.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w800,
          height: 1.3,
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
    return _frame(
      key: PkDareLayer.decideKey,
      border: pkDareLevelColor(option.level),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PkDareLevelChip(level: option.level),
              const Spacer(),
              PkDareRing(seconds: left, fraction: left / total),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          if (loser)
            Text(
              l10n.pkDareYourDare,
              textScaler: _scaler(context),
              style: context.textStyles.caption.copyWith(
                color: const Color(0xFFFFC94D),
                fontWeight: FontWeight.w800,
              ),
            ),
          _text(context, option),
          const SizedBox(height: KSpacing.sm),
          if (loser)
            Row(
              children: [
                Expanded(
                  child: KButton(
                    key: PkDareLayer.refuseKey,
                    variant: KButtonVariant.secondary,
                    label: l10n.pkDareRefuse,
                    onPressed: _busy ? null : () => unawaited(_refuse()),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: KButton(
                    key: PkDareLayer.acceptKey,
                    label: l10n.pkDareAccept,
                    loading: _busy,
                    onPressed: () => unawaited(_run(widget.actions.onAccept)),
                  ),
                ),
              ],
            )
          else
            Text(
              l10n.pkDareLoserDeciding(KFormat.bidiIsolate(_loserName())),
              key: PkDareLayer.waitingKey,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: _scaler(context),
              style: context.textStyles.caption.copyWith(
                color: const Color(0xCCFFFFFF),
              ),
            ),
        ],
      ),
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
    return Semantics(
      label: l10n.pkDareSemantics(
        option.text(Localizations.localeOf(context)),
        time,
      ),
      child: _frame(
        key: PkDareLayer.bannerKey,
        border: pkDareLevelColor(option.level),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                PkDareLevelChip(level: option.level),
                const SizedBox(width: KSpacing.xs),
                Container(
                  key: PkDareLayer.timerKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Text(
                    time,
                    textDirection: TextDirection.ltr,
                    textScaler: _scaler(context),
                    style: context.textStyles.label.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.actions.onReport != null)
                  IconButton(
                    key: PkDareLayer.reportKey,
                    tooltip: l10n.pkDareReport,
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy
                        ? null
                        : () => unawaited(_report(option.id)),
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFC94D),
                      size: 22,
                    ),
                  ),
              ],
            ),
            _text(context, option),
            if (winner) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.pkDareJudge,
                textScaler: _scaler(context),
                style: context.textStyles.caption.copyWith(
                  color: const Color(0xCCFFFFFF),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      key: PkDareLayer.notDoneKey,
                      variant: KButtonVariant.secondary,
                      label: l10n.pkDareNotDone,
                      onPressed: _busy
                          ? null
                          : () => unawaited(
                              _run(() async {
                                await widget.actions.onVerdict?.call(
                                  done: false,
                                );
                              }),
                            ),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: KButton(
                      key: PkDareLayer.doneKey,
                      label: l10n.pkDareDone,
                      loading: _busy,
                      onPressed: () => unawaited(
                        _run(() async {
                          await widget.actions.onVerdict?.call(done: true);
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
    return _frame(
      key: PkDareLayer.outcomeKey,
      border: done ? const Color(0xFF22C27A) : const Color(0xFFE50914),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            textScaler: _scaler(context),
            style: context.textStyles.title.copyWith(
              color: done ? const Color(0xFF7CF5B5) : const Color(0xFFFF8A8A),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (option != null) ...[
            const SizedBox(height: KSpacing.xs),
            _text(context, option, maxLines: 2),
          ],
          if (!done && dare.points != 0) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.pkRecordPoints(KFormat.signed(dare.points)),
              textScaler: _scaler(context),
              style: context.textStyles.caption.copyWith(
                color: const Color(0xCCFFFFFF),
              ),
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
class PkDareLevelChip extends StatelessWidget {
  const new({required this.level, super.key, this.dense = false});

  final PkDareLevel level;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = pkDareLevelColor(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(color: color),
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
class PkDareRing extends StatelessWidget {
  const new({required this.seconds, required this.fraction, super.key});

  final int seconds;
  final double fraction;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: fraction.clamp(0, 1),
          strokeWidth: 3.5,
          backgroundColor: const Color(0x33FFFFFF),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFC94D)),
        ),
        Text(
          '$seconds',
          textDirection: TextDirection.ltr,
          textScaler: _scaler(context),
          style: context.textStyles.label.copyWith(
            color: const Color(0xFFFFFFFF),
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// The message of a refused dare action (409 `PK_DARE_CLOSED`, else generic).
String pkDareFailureMessage(AppLocalizations l10n, Object error) {
  final failure = toAppFailure(error);
  final code = failure is ServerFailure ? failure.rawCode : null;
  return code == 'PK_DARE_CLOSED'
      ? l10n.pkFailureDareClosed
      : failureMessage(l10n, failure);
}
