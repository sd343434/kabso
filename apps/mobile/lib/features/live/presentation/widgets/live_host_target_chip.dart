import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/presentation/widgets/host_target_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart'
    show KViewerRoom;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D199 (owner: «تارجت» next to «ترتيب الغرف»): the host's two daily
/// targets in one chip, turning every [rotateEvery] between 🍒 today's
/// cherries (the «استقبل هدايا في بثك» band target, in cherries) and the
/// Kabso wizard hat — today's lucky-gift value (the «استقبل هدايا الحظ»
/// target, coins). A reached target shows a check and a gold glow. With
/// reduced motion nothing turns: both show side by side.
///
/// D199b (owner): the chip shows the amount RECEIVED only («12.4K»); the
/// target itself is in the sheet the tap opens (the host's
/// [showHostGiftStats], a viewer's [showHostTargetsPublic], both the
/// ranking sheet [HostTargetSheet]). Not a host (or not visible): nothing.
///
/// D214 (owner): the chip is ALWAYS shown once the targets have loaded, in
/// every live (video, multi, audio, podcast; the host's screen and the
/// viewer's) — both faces turning as before, each with what was received
/// today, «0» when nothing was, also with no target set today. The check and
/// the glow only for a target that exists and is reached. While loading, or
/// for a 404 (not a host / hidden): nothing.
class LiveHostTargetChip extends ConsumerStatefulWidget {
  const new({
    required this.username,
    required this.isHost,
    super.key,
    this.onSupport,
    this.plain = false,
  });

  /// D253 (the host's reference «⭐0 ⏱0/50»): both faces side by side as
  /// plain icon + text, no chip and no turning.
  final bool plain;

  final String username;

  /// The host's own screen (the full stats on tap).
  final bool isHost;

  /// A viewer's «ادعم» in the sheet: the room's gift panel (null: none).
  final VoidCallback? onSupport;

  static const chipKey = Key('target.chip');
  static const cherriesKey = Key('target.cherries');
  static const luckyKey = Key('target.lucky');
  static const reachedKey = Key('target.reached');

  /// Whether the rooms add the chip to their chips row (D214: whenever the
  /// targets data exists — loaded, not a 404 — with or without a target
  /// today; never a placeholder while loading).
  static bool shows(LiveHostTargets? targets) => targets != null;

  /// D214: a face's check and glow — only for a target that exists today
  /// and is reached.
  static bool reachedOf(HostTarget target) =>
      target.hasTarget && target.reached;

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
      unawaited(
        showHostTargetsPublic(
          context,
          widget.username,
          onSupport: widget.onSupport,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(liveHostTargetsProvider(widget.username)).value;
    if (targets == null) return const SizedBox.shrink();
    // D214: both faces always (0 received shows «0»).
    const kinds = _Kind.values;
    final l10n = context.l10n;
    final still = widget.plain || _still(context);
    HostTarget of(_Kind k) =>
        k == _Kind.cherries ? targets.cherries : targets.lucky;
    String label(_Kind k) {
      final t = of(k);
      final r = KFormat.grouped(t.received);
      final text = k == _Kind.cherries
          ? l10n.liveTargetCherriesSemantics(r)
          : l10n.liveTargetLuckySemantics(r);
      return LiveHostTargetChip.reachedOf(t)
          ? '$text, ${l10n.liveTargetReached}'
          : text;
    }

    final Widget content;
    final bool glow;
    if (still) {
      glow = kinds.any((k) => LiveHostTargetChip.reachedOf(of(k)));
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, k) in kinds.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Flexible(
              child: _Face(kind: k, target: of(k), plain: widget.plain),
            ),
          ],
        ],
      );
    } else {
      final k = kinds[_turn % kinds.length];
      glow = LiveHostTargetChip.reachedOf(of(k));
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
        child: widget.plain
            ? SizedBox(
                height: KViewerRoom.chipHeight,
                child: Center(widthFactor: 1, child: content),
              )
            : AnimatedContainer(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                height: KViewerRoom.chipHeight,
                constraints: BoxConstraints(
                  maxWidth: still
                      ? LiveHostTargetChip.maxWidthBoth
                      : LiveHostTargetChip.maxWidth,
                ),
                padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
                decoration: BoxDecoration(
                  color: KLiveColors.glass,
                  borderRadius: BorderRadius.circular(
                    KViewerRoom.chipHeight / 2,
                  ),
                  border: glow
                      ? Border.all(color: const Color(0xCCFFD36E), width: 0.8)
                      : null,
                  boxShadow: glow
                      ? const [
                          BoxShadow(color: Color(0x99FFC547), blurRadius: 8),
                        ]
                      : null,
                ),
                child: ClipRect(child: Center(widthFactor: 1, child: content)),
              ),
      ),
    );
  }
}

enum _Kind { cherries, lucky }

/// One face of the chip: the icon, the amount received (D199b: never the
/// target) and, once reached, a check.
class _Face extends StatelessWidget {
  const new({
    required this.kind,
    required this.target,
    super.key,
    this.plain = false,
  });

  final _Kind kind;
  final HostTarget target;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: kind == _Kind.cherries
          ? LiveHostTargetChip.cherriesKey
          : LiveHostTargetChip.luckyKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kind == _Kind.cherries)
          KCherryIcon(size: plain ? 12 : 16)
        else
          KWizardHatIcon(size: plain ? 12 : 16),
        SizedBox(width: plain ? 4 : 3),
        Flexible(
          child: Text(
            _short(target.received),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(
              // D253: the reference's «0/50» (≈ 14 pt).
              fontSize: plain ? 14 : 11.5,
              height: 1,
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
              shadows: KLiveColors.glassShadow,
            ),
          ),
        ),
        if (LiveHostTargetChip.reachedOf(target)) ...[
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

/// The chip's short Latin form ("12.4K", "3K", "1.2M"): one LTR run that
/// fits the 23 pt chip in both languages; the full grouped numbers are in
/// its label and the sheet.
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
