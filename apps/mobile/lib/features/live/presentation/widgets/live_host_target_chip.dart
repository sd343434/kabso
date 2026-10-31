import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart'
    show KViewerRoom;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D199 (owner: «تارجت» next to «ترتيب الغرف»): the host's two daily
/// targets in one chip, turning every [rotateEvery] between 🍒 today's
/// cherries against the «استقبل هدايا في بثك» band target (in cherries) and
/// the Kabso wizard hat — today's lucky-gift value against the «استقبل
/// هدايا الحظ» target (coins). A reached target shows a check and a gold
/// glow. With reduced motion nothing turns: both show side by side.
///
/// The host's tap opens their full gift stats ([showHostGiftStats]); a
/// viewer's opens today's progress and top supporters only
/// ([showHostTargetsPublic]). Not a host (or not visible): nothing.
class LiveHostTargetChip extends ConsumerStatefulWidget {
  const new({required this.username, required this.isHost, super.key});

  final String username;

  /// The host's own screen (the full stats on tap).
  final bool isHost;

  static const chipKey = Key('target.chip');
  static const cherriesKey = Key('target.cherries');
  static const luckyKey = Key('target.lucky');
  static const reachedKey = Key('target.reached');

  /// Whether the chip has anything to show (a host with a target today):
  /// the rooms add it to the chips row only then, so the row is unchanged
  /// for everyone else.
  static bool shows(LiveHostTargets? targets) =>
      targets != null &&
      (targets.cherries.hasTarget || targets.lucky.hasTarget);

  /// Tests may shorten the turn.
  static Duration rotateEvery = const Duration(seconds: 4);

  /// Captures only: turn even under the goldens' reduced motion.
  @visibleForTesting
  static bool debugIgnoreReducedMotion = false;

  /// The widest the chip grows (one face; both faces under reduced motion)
  /// before its numbers shorten with an ellipsis.
  static const maxWidth = 124.0;
  static const maxWidthBoth = 196.0;

  /// The data refreshes every this many turns (≈ a minute).
  static const refreshTurns = 15;

  @override
  ConsumerState<LiveHostTargetChip> createState() => _LiveHostTargetChipState();
}

class _LiveHostTargetChipState extends ConsumerState<LiveHostTargetChip> {
  Timer? _timer;
  int _turn = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(LiveHostTargetChip.rotateEvery, (_) {
      if (!mounted) return;
      _turn++;
      if (_turn % LiveHostTargetChip.refreshTurns == 0) {
        ref.invalidate(liveHostTargetsProvider(widget.username));
      }
      // Reduced motion: no turning (the refresh still runs).
      if (!_still(context)) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static bool _still(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) &&
      !LiveHostTargetChip.debugIgnoreReducedMotion;

  void _open() {
    final targets = ref.read(liveHostTargetsProvider(widget.username)).value;
    if (widget.isHost) {
      unawaited(showHostGiftStats(context));
    } else if (targets != null) {
      unawaited(showHostTargetsPublic(context, widget.username));
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(liveHostTargetsProvider(widget.username)).value;
    if (targets == null) return const SizedBox.shrink();
    final kinds = [
      if (targets.cherries.hasTarget) _Kind.cherries,
      if (targets.lucky.hasTarget) _Kind.lucky,
    ];
    if (kinds.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final still = _still(context);
    HostTarget of(_Kind k) =>
        k == _Kind.cherries ? targets.cherries : targets.lucky;
    String label(_Kind k) {
      final t = of(k);
      final r = KFormat.grouped(t.received);
      final g = KFormat.grouped(t.target);
      final text = k == _Kind.cherries
          ? l10n.liveTargetCherriesSemantics(r, g)
          : l10n.liveTargetLuckySemantics(r, g);
      return t.reached ? '$text, ${l10n.liveTargetReached}' : text;
    }

    final Widget content;
    final bool glow;
    if (still || kinds.length == 1) {
      glow = kinds.any((k) => of(k).reached);
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, k) in kinds.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Flexible(
              child: _Face(kind: k, target: of(k)),
            ),
          ],
        ],
      );
    } else {
      final k = kinds[_turn % kinds.length];
      glow = of(k).reached;
      content = AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.45),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _Face(key: ValueKey(k), kind: k, target: of(k)),
      );
    }
    return Semantics(
      button: true,
      label: '${l10n.liveTargetChip}: ${kinds.map(label).join(' · ')}',
      excludeSemantics: true,
      child: GestureDetector(
        key: LiveHostTargetChip.chipKey,
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 320),
          height: KViewerRoom.chipHeight,
          constraints: BoxConstraints(
            maxWidth: still && kinds.length > 1
                ? LiveHostTargetChip.maxWidthBoth
                : LiveHostTargetChip.maxWidth,
          ),
          padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
          decoration: BoxDecoration(
            color: KLiveColors.glass,
            borderRadius: BorderRadius.circular(KViewerRoom.chipHeight / 2),
            border: glow
                ? Border.all(color: const Color(0xCCFFD36E), width: 0.8)
                : null,
            boxShadow: glow
                ? const [BoxShadow(color: Color(0x99FFC547), blurRadius: 8)]
                : null,
          ),
          child: ClipRect(child: Center(widthFactor: 1, child: content)),
        ),
      ),
    );
  }
}

enum _Kind { cherries, lucky }

/// One face of the chip: the icon, «received/target» and, once reached, a
/// check.
class _Face extends StatelessWidget {
  const new({required this.kind, required this.target, super.key});

  final _Kind kind;
  final HostTarget target;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: kind == _Kind.cherries
          ? LiveHostTargetChip.cherriesKey
          : LiveHostTargetChip.luckyKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kind == _Kind.cherries)
          const KCherryIcon(size: 16)
        else
          const KWizardHatIcon(size: 16),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${_short(target.received)}/${_short(target.target)}',
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(
              fontSize: 11.5,
              height: 1,
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
              shadows: KLiveColors.glassShadow,
            ),
          ),
        ),
        if (target.reached) ...[
          const SizedBox(width: 3),
          Container(
            key: LiveHostTargetChip.reachedKey,
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 10,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ],
      ],
    );
  }
}

/// The chip's short Latin form ("12.4K", "3K", "1.2M", as the reference's
/// "3.51K/5K"): one LTR run that fits the 23 pt chip in both languages; the
/// full grouped numbers are in its label and the sheets.
String _short(int value) {
  if (value < 1000) return '${value < 0 ? 0 : value}';
  final (divisor, suffix) = value >= 1000000 ? (1000000, 'M') : (1000, 'K');
  final tenths = value * 10 ~/ divisor;
  return tenths % 10 == 0
      ? '${tenths ~/ 10}$suffix'
      : '${tenths ~/ 10}.${tenths % 10}$suffix';
}

/// D199: the Kabso wizard hat (drawn here, no third-party art) — the
/// «هدايا الحظ» mark: a violet cone leaning back with a gold band, a brim
/// and two gold stars.
class KWizardHatIcon extends StatelessWidget {
  const new({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: WizardHatPainter()),
  );
}

class WizardHatPainter extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The cone, its tip leaning to the end.
    final cone = Path()
      ..moveTo(w * 0.20, h * 0.80)
      ..quadraticBezierTo(w * 0.40, h * 0.42, w * 0.62, h * 0.06)
      ..quadraticBezierTo(w * 0.70, h * 0.30, w * 0.80, h * 0.80)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB57BFF), Color(0xFF6A2BD9)],
        ).createShader(Offset.zero & size),
    );
    // The band.
    final band = Path()
      ..moveTo(w * 0.24, h * 0.70)
      ..quadraticBezierTo(w * 0.50, h * 0.62, w * 0.77, h * 0.70)
      ..lineTo(w * 0.79, h * 0.79)
      ..quadraticBezierTo(w * 0.50, h * 0.72, w * 0.21, h * 0.79)
      ..close();
    canvas
      ..drawPath(band, Paint()..color = const Color(0xFFFFC547))
      // The brim.
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.83),
          width: w * 0.94,
          height: h * 0.20,
        ),
        Paint()..color = const Color(0xFF4B1BA6),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.815),
          width: w * 0.80,
          height: h * 0.11,
        ),
        Paint()..color = const Color(0xFF7D3CF0),
      );
    final gold = Paint()..color = const Color(0xFFFFE08A);
    _star(canvas, Offset(w * 0.47, h * 0.45), w * 0.10, gold);
    _star(canvas, Offset(w * 0.61, h * 0.27), w * 0.065, gold);
  }

  static void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? r : r * 0.38;
      final a = -math.pi / 2 + i * math.pi / 4;
      final o = c + Offset(math.cos(a) * radius, math.sin(a) * radius);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(p..close(), paint);
  }

  @override
  bool shouldRepaint(WizardHatPainter oldDelegate) => false;
}

abstract final class _Ink {
  static const sheet = Color(0xFF1F1D24);
  static const text = Color(0xFFFFFFFF);
  static const soft = Color(0xFFB9B6C2);
  static const tile = Color(0x14FFFFFF);
  static const cherry = Color(0xFFFF5A7A);
  static const magic = Color(0xFFB57BFF);
  static const gold = Color(0xFFFFD36E);
}

/// The sheet keeps the room's providers even where the scope sits under
/// the navigator (as in `LiveDataNowPage`).
Future<void> _sheet(BuildContext context, Widget child) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _Ink.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
    ),
    builder: (_) =>
        UncontrolledProviderScope(container: container, child: child),
  );
}

/// The host's own gift stats (D199): يومي / أسبوعي / شهري / الكل.
Future<void> showHostGiftStats(BuildContext context) =>
    _sheet(context, const HostGiftStatsSheet());

/// A viewer's view (D199): today's progress and top supporters only.
Future<void> showHostTargetsPublic(BuildContext context, String username) =>
    _sheet(context, HostTargetsPublicSheet(username: username));

class HostGiftStatsSheet extends ConsumerStatefulWidget {
  const new({super.key});

  static const sheetKey = Key('targetStats.sheet');
  static const chartKey = Key('targetStats.chart');
  static const taskCenterKey = Key('targetStats.taskCenter');
  static const targetsKey = Key('targetStats.targets');
  static Key periodKey(HostStatsPeriod p) =>
      Key('targetStats.period.${p.wire}');
  static Key totalKey(String id) => Key('targetStats.total.$id');

  @override
  ConsumerState<HostGiftStatsSheet> createState() => _HostGiftStatsSheetState();
}

class _HostGiftStatsSheetState extends ConsumerState<HostGiftStatsSheet> {
  HostStatsPeriod _period = HostStatsPeriod.day;
  HostGiftStats? _stats;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final stats = _stats?.period == _period ? _stats : null;
    final labels = {
      HostStatsPeriod.day: l10n.liveTargetPeriodDay,
      HostStatsPeriod.week: l10n.liveTargetPeriodWeek,
      HostStatsPeriod.month: l10n.liveTargetPeriodMonth,
      HostStatsPeriod.all: l10n.liveTargetPeriodAll,
    };
    final Widget body;
    if (stats == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : KErrorState(
                  title: l10n.liveTargetLoadError,
                  message: failureMessage(l10n, toAppFailure(_error!)),
                  retryLabel: l10n.actionRetry,
                  onRetry: () => unawaited(_load()),
                  compact: true,
                ),
        ),
      );
    } else {
      final targets = stats.targets;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (targets != null) ...[
            _TargetsCard(key: HostGiftStatsSheet.targetsKey, targets: targets),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.liveTargetConversion(targets.band),
              style: t.caption.copyWith(color: _Ink.soft, fontSize: 10.5),
            ),
            const SizedBox(height: KSpacing.sm),
            KButton(
              key: HostGiftStatsSheet.taskCenterKey,
              label: l10n.liveTargetTaskCenter,
              icon: Icons.task_alt_rounded,
              variant: KButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(context.push(AppRoutes.taskCenter));
              },
            ),
            const SizedBox(height: KSpacing.md),
          ],
          _SectionTitle(
            icon: const KCherryIcon(size: 18),
            text: l10n.liveTargetCherriesSection,
          ),
          const SizedBox(height: KSpacing.xs),
          _Totals(
            items: [
              ('cherries', l10n.liveTargetReceived, stats.cherries),
              ('gifts', l10n.liveTargetGifts, stats.gifts),
              ('givers', l10n.liveTargetGivers, stats.givers),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            l10n.liveTargetChart,
            style: t.caption.copyWith(color: _Ink.soft),
          ),
          const SizedBox(height: KSpacing.xs),
          Semantics(
            key: HostGiftStatsSheet.chartKey,
            label: l10n.liveTargetChart,
            child: SizedBox(
              height: 90,
              child: CustomPaint(
                painter: _CherryBarsPainter(
                  values: [for (final b in stats.series) b.cherries],
                  rtl: Directionality.of(context) == TextDirection.rtl,
                ),
              ),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          _Supporters(
            title: l10n.liveTargetTopSupporters,
            supporters: stats.topSupporters,
          ),
          const SizedBox(height: KSpacing.md),
          _SectionTitle(
            icon: const KWizardHatIcon(size: 18),
            text: l10n.liveTargetLuckySection,
          ),
          const SizedBox(height: KSpacing.xs),
          _Totals(
            items: [
              ('lucky', l10n.liveTargetLuckyValue, stats.luckyCoins),
              ('luckyGifts', l10n.liveTargetGifts, stats.luckyGifts),
              ('luckyGivers', l10n.liveTargetGivers, stats.luckyGivers),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          _Supporters(
            title: l10n.liveTargetTopLucky,
            supporters: stats.luckySupporters,
          ),
        ],
      );
    }
    return SafeArea(
      top: false,
      child: Semantics(
        key: HostGiftStatsSheet.sheetKey,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveTargetStatsTitle,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.md,
              14,
              KSpacing.md,
              KSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.liveTargetStatsTitle,
                    style: t.title.copyWith(color: _Ink.text),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.liveTargetZoneHint,
                  style: t.caption.copyWith(color: _Ink.soft),
                ),
                const SizedBox(height: KSpacing.sm),
                Row(
                  children: [
                    for (final p in HostStatsPeriod.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            key: HostGiftStatsSheet.periodKey(p),
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                labels[p]!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            selected: p == _period,
                            showCheckmark: false,
                            onSelected: (_) {
                              if (p == _period) return;
                              setState(() => _period = p);
                              unawaited(_load());
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: KSpacing.md),
                body,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The viewer's small sheet: today's two targets and the top supporters.
class HostTargetsPublicSheet extends ConsumerWidget {
  const new({required this.username, super.key});

  final String username;

  static const sheetKey = Key('targetPublic.sheet');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final targets = ref.watch(liveHostTargetsProvider(username)).value;
    return SafeArea(
      top: false,
      child: Semantics(
        key: sheetKey,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveTargetPublicTitle,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            14,
            KSpacing.md,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.liveTargetPublicTitle,
                  style: t.title.copyWith(color: _Ink.text),
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              if (targets == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: KSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _TargetsCard(targets: targets),
                const SizedBox(height: KSpacing.md),
                _Supporters(
                  title: l10n.liveTargetTopSupporters,
                  supporters: targets.topSupporters,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const new({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        icon,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: context.textStyles.bodyStrong.copyWith(color: _Ink.text),
          ),
        ),
      ],
    ),
  );
}

/// Today's two targets with their progress bars.
class _TargetsCard extends StatelessWidget {
  const new({required this.targets, super.key});

  final LiveHostTargets targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    Widget row(Widget icon, String title, HostTarget target, Color color) {
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: _Ink.text),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    textDirection: TextDirection.ltr,
                    style: t.caption.copyWith(
                      color: target.reached ? _Ink.gold : _Ink.soft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (target.reached) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF34C759),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: target.progress,
                  minHeight: 6,
                  backgroundColor: _Ink.tile,
                  color: target.reached ? _Ink.gold : color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: _Ink.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.liveTargetToday,
              style: t.bodyStrong.copyWith(color: _Ink.text),
            ),
          ),
          row(
            const KCherryIcon(size: 16),
            l10n.liveTargetCherriesGoal,
            targets.cherries,
            _Ink.cherry,
          ),
          row(
            const KWizardHatIcon(size: 16),
            l10n.liveTargetLuckyGoal,
            targets.lucky,
            _Ink.magic,
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const new({required this.items});

  final List<(String, String, int)> items;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Row(
      children: [
        for (final (i, (id, label, value)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Semantics(
              key: HostGiftStatsSheet.totalKey(id),
              container: true,
              label: '$label: ${KFormat.grouped(value)}',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: KSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: _Ink.tile,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        KFormat.grouped(value),
                        maxLines: 1,
                        style: t.bodyStrong.copyWith(
                          color: _Ink.text,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(
                        color: _Ink.soft,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Supporters extends StatelessWidget {
  const new({required this.title, required this.supporters});

  final String title;
  final List<HostSupporter> supporters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const medals = [Color(0xFFFFC547), Color(0xFFC9D1DC), Color(0xFFE09A62)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: t.caption.copyWith(color: _Ink.soft)),
        const SizedBox(height: KSpacing.xs),
        if (supporters.isEmpty)
          Text(
            l10n.liveTargetNoSupporters,
            style: t.caption.copyWith(color: _Ink.soft),
          )
        else
          for (final (i, s) in supporters.indexed)
            Semantics(
              container: true,
              label:
                  '${i + 1}. ${s.user.displayName}: '
                  '${KFormat.grouped(s.coins)}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: medals[i % medals.length],
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: t.caption.copyWith(
                          color: const Color(0xFF3A2A00),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KAvatar(
                      name: s.user.displayName,
                      imageUrl: s.user.avatarUrl,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(color: _Ink.text),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const KabsoArtIcon(KabsoArt.coin, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      KFormat.compact(s.coins, l10n),
                      textDirection: TextDirection.ltr,
                      style: t.caption.copyWith(
                        color: _Ink.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Bars of the cherries per bucket (oldest first, in the reading direction).
class _CherryBarsPainter extends CustomPainter {
  new({required this.values, required this.rtl});

  final List<int> values;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = _Ink.tile;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), base);
    if (values.isEmpty) return;
    final top = values.reduce(math.max);
    final slot = size.width / values.length;
    final width = math.max(1.5, slot * 0.6);
    final bar = Paint()..color = _Ink.cherry;
    for (var i = 0; i < values.length; i++) {
      final h = top == 0 ? 0.0 : (values[i] / top) * (size.height - 4);
      if (h <= 0) continue;
      final index = rtl ? values.length - 1 - i : i;
      final x = index * slot + (slot - width) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 1 - h, width, h),
          const Radius.circular(2),
        ),
        bar,
      );
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(_CherryBarsPainter old) =>
      old.rtl != rtl || !_same(old.values, values);
}
