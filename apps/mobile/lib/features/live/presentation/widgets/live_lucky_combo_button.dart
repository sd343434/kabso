import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_lucky_combo.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D145/D145a: the lucky combo's button and its chips, placed by the room
/// in a slot of its own at the bottom end, over the bar near the gift
/// button (mirrored in Arabic): the audio room's end slot (where the promo
/// box sits, which steps aside meanwhile) or the video live's chat end
/// (the chat narrows to make room). So it never covers the chat, the
/// seats or the quick replies.
///
/// From the top: the streak's winnings (compact: the coin and "+N", the
/// best ×), the round button — the gift and «كومبو / Combo» on Kabso red,
/// a gold rim, a gold → red countdown ring of [LuckyComboController
/// .ringTime] — with the one ×N badge (the gifts per recipient in the
/// server's combo, `combo.quantity`) at its top start, and the balance.
/// Each accepted tap buzzes, bounces the button and flies the gift up
/// ([LuckyComboLayer]). Nothing when no combo shows.
class LuckyComboCluster extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const buttonKey = Key('combo.button');
  static const ringKey = Key('combo.ring');
  static const countKey = Key('combo.count');
  static const balanceKey = Key('combo.balance');
  static const resultKey = Key('combo.result');

  /// The button's outer size (ring included); a 48 pt target and more.
  static const double size = 76;

  /// The cluster's width (the button and its badge; the chips scale down
  /// to it).
  static const double width = 96;

  static final _anchors = <String, GlobalKey>{};

  /// The button of [roomId]'s combo (where flights start).
  static GlobalKey anchorFor(String roomId) =>
      _anchors.putIfAbsent(roomId, GlobalKey.new);

  /// Whether [roomId]'s combo shows now (the room gives it its slot).
  static bool shows(WidgetRef ref, String roomId) =>
      ref.watch(liveLuckyComboProvider(roomId).select((s) => s.visible));

  @override
  ConsumerState<LuckyComboCluster> createState() => _LuckyComboClusterState();
}

class _LuckyComboClusterState extends ConsumerState<LuckyComboCluster>
    with TickerProviderStateMixin {
  // The ring is the time left, not decoration: it runs at its real speed
  // with reduced motion too.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: LuckyComboController.ringTime,
    animationBehavior: AnimationBehavior.preserve,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onTap() {
    final ok = ref.read(liveLuckyComboProvider(widget.roomId).notifier).tap();
    if (ok) unawaited(HapticFeedback.mediumImpact());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = liveLuckyComboProvider(widget.roomId);
    ref.listen(provider, (previous, next) {
      if (next.ring != previous?.ring && next.visible) {
        _ring.forward(from: 0);
      }
    });
    final combo = ref.watch(provider);
    final gift = combo.gift;
    if (!combo.visible || gift == null) {
      if (_pulse.isAnimating) _pulse.stop();
      return const SizedBox.shrink();
    }
    // The balance is kept read while the combo shows (its answers set it).
    final coins = ref.watch(liveCoinsProvider).value;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!reduce && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (reduce && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (!_ring.isAnimating && _ring.value == 0) _ring.forward(from: 0);
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final name = catalogue?.byCode(gift.code)?.name;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final media = MediaQuery.of(context);
    return SizedBox(
      width: LuckyComboCluster.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (combo.last case final last?)
            _ResultChip(
              key: LuckyComboCluster.resultKey,
              id: combo.lastId,
              coinsWon: combo.coinsWon,
              topMultiplier: combo.topMultiplier,
              lastWon: last.coinsWon,
              scaler: scaler,
            ),
          const SizedBox(height: KSpacing.xxs),
          SizedBox(
            width: LuckyComboCluster.width,
            height: LuckyComboCluster.size + 6,
            child: Stack(
              children: [
                Align(
                  alignment: AlignmentDirectional.bottomEnd,
                  child: Semantics(
                    button: true,
                    label: l10n.liveComboSemantics(
                      KFormat.bidiIsolate(name ?? l10n.liveGiftGeneric),
                      combo.comboQuantity,
                    ),
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: LuckyComboCluster.buttonKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: _onTap,
                      child: KeyedSubtree(
                        key: LuckyComboCluster.anchorFor(widget.roomId),
                        child: _ComboButton(
                          ring: _ring,
                          pulse: _pulse,
                          taps: combo.taps,
                          reduce: reduce,
                          assetKey: gift.assetKey,
                          imageUrl: gift.imageUrl,
                          label: l10n.liveComboLabel,
                          scaler: scaler,
                        ),
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: ExcludeSemantics(
                    child: MediaQuery(
                      data: media.copyWith(
                        textScaler: scaler.clamp(maxScaleFactor: 1.15),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KLiveColors.chatScrim,
                          borderRadius: BorderRadius.circular(KRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: KGiftComboCounter(
                            key: LuckyComboCluster.countKey,
                            count: combo.comboQuantity,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (coins != null) ...[
            const SizedBox(height: 2),
            _Balance(coins: coins, scaler: scaler),
          ],
        ],
      ),
    );
  }
}

/// D145: what the combo shows over the room besides its button: the gift
/// flying from the button up to who receives it on every accepted tap
/// (none with reduced motion), and, when the combo stops on a refusal, the
/// reason over the bar for [messageTime]. Takes no taps.
class LuckyComboLayer extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    super.key,
    this.bottom = audioBottom,
    this.hostUsername,
  });

  final String roomId;

  /// The message's distance from the bottom safe edge (over the bar).
  final double bottom;

  /// The host: a combo to the host alone flies to the host's pill at the
  /// top start; any other flies toward the seats in the upper middle.
  final String? hostUsername;

  /// [bottom] in an audio room (over its bar) and in a video live (over
  /// the quick replies above its bar).
  static const double audioBottom = 60;
  static const double videoBottom = 100;

  static const messageKey = Key('combo.message');
  static const flightKey = Key('combo.flight');
  static const messageTime = Duration(seconds: 3);
  static const flightTime = Duration(milliseconds: 700);

  @override
  ConsumerState<LuckyComboLayer> createState() => _LuckyComboLayerState();
}

class _LuckyComboLayerState extends ConsumerState<LuckyComboLayer> {
  String? _message;
  Timer? _messageTimer;

  /// Flights: id → where it starts (the button's centre then).
  final _flights = <int, Offset>{};

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String text) {
    _messageTimer?.cancel();
    _messageTimer = Timer(LuckyComboLayer.messageTime, () {
      if (mounted) setState(() => _message = null);
    });
    setState(() => _message = text);
  }

  Offset? _buttonCentre() {
    final anchor = LuckyComboCluster.anchorFor(widget.roomId).currentContext;
    final mine = context.findRenderObject();
    final box = anchor?.findRenderObject();
    if (box is! RenderBox || mine is! RenderBox || !box.attached) return null;
    return mine.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = liveLuckyComboProvider(widget.roomId);
    ref.listen(provider, (previous, next) {
      if (next.taps != (previous?.taps ?? 0) &&
          !MediaQuery.disableAnimationsOf(context)) {
        final from = _buttonCentre();
        if (from != null) setState(() => _flights[next.taps] = from);
      }
      final stop = next.stop;
      if (stop != null && stop.id != previous?.stop?.id) {
        _showMessage(
          stop.notEnoughCoins || stop.failure == null
              ? l10n.liveGiftNotEnoughCoins
              : failureMessage(l10n, stop.failure!),
        );
      }
    });
    final gift = ref.watch(provider.select((s) => s.gift));
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final media = MediaQuery.of(context);
    final children = <Widget>[];
    if (_message case final text?) {
      children.add(
        Positioned(
          left: KSpacing.lg,
          right: KSpacing.lg,
          bottom: media.padding.bottom + widget.bottom,
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Container(
                key: LuckyComboLayer.messageKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6000000),
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  textScaler: scaler,
                  style: context.textStyles.label.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (gift != null) {
      final toHost =
          gift.recipients.length == 1 &&
          gift.recipients.first == widget.hostUsername;
      for (final MapEntry(key: id, value: from) in _flights.entries) {
        children.add(
          _Flight(
            key: ValueKey('flight.$id'),
            from: from,
            to: toHost
                ? Offset(
                    Directionality.of(context) == TextDirection.rtl
                        ? media.size.width - 40
                        : 40,
                    media.padding.top + 24,
                  )
                : Offset(media.size.width / 2, media.size.height * 0.28),
            assetKey: gift.assetKey,
            imageUrl: gift.imageUrl,
            onDone: () {
              if (mounted) setState(() => _flights.remove(id));
            },
          ),
        );
      }
    }
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: children),
    );
  }
}

/// The round button: the gift and "Combo" on Kabso red, a gold → red
/// countdown ring that empties over the ring time, a soft pulse (none with
/// reduced motion) and a bounce on each tap.
class _ComboButton extends StatelessWidget {
  const new({
    required this.ring,
    required this.pulse,
    required this.taps,
    required this.reduce,
    required this.assetKey,
    required this.imageUrl,
    required this.label,
    required this.scaler,
  });

  final Animation<double> ring;
  final Animation<double> pulse;
  final int taps;
  final bool reduce;
  final String assetKey;
  final String? imageUrl;
  final String label;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    const size = LuckyComboCluster.size;
    final face = Container(
      width: size - 12,
      height: size - 12,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 0.9,
          colors: [KBrandColors.red400, KBrandColors.red600],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: KBrandColors.gold, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KGiftImage(assetKey, imageUrl: imageUrl, size: 34),
          Text(
            label,
            maxLines: 1,
            // D145c: the Latin "MAX X" in every language.
            textDirection: TextDirection.ltr,
            textScaler: scaler.clamp(maxScaleFactor: 1.15),
            style: context.textStyles.caption.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.1,
              shadows: KLiveColors.glassShadow,
            ),
          ),
        ],
      ),
    );
    final ringed = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            key: LuckyComboCluster.ringKey,
            animation: Listenable.merge([ring, pulse]),
            builder: (context, _) => CustomPaint(
              size: const Size.square(size),
              painter: ComboRingPainter(
                remaining: 1 - ring.value,
                glow: reduce ? 0 : pulse.value,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) => Transform.scale(
              scale: reduce ? 1 : 1 + 0.05 * pulse.value,
              child: child,
            ),
            child: face,
          ),
        ],
      ),
    );
    final bounce = KMotion.of(context, const Duration(milliseconds: 220));
    if (bounce == Duration.zero) return ringed;
    return TweenAnimationBuilder<double>(
      key: ValueKey('bounce.$taps'),
      tween: Tween(begin: taps == 0 ? 1 : 0.86, end: 1),
      duration: bounce,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: ringed,
    );
  }
}

/// The countdown ring: a dim track and the time left as a gold → red arc
/// from the top, clockwise; [glow] (0–1) widens a soft halo.
class ComboRingPainter extends CustomPainter {
  const new({required this.remaining, this.glow = 0});

  final double remaining;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.5;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    if (glow > 0) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width / 2 - 2,
        Paint()
          ..color = KBrandColors.red500.withValues(alpha: 0.25 + 0.2 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 4 * glow),
      );
    }
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x66000000),
    );
    final sweep = 2 * math.pi * remaining.clamp(0, 1);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [KBrandColors.gold, KBrandColors.red400, KBrandColors.gold],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(ComboRingPainter old) =>
      old.remaining != remaining || old.glow != glow;
}

/// The streak's lucky winnings, compact for the cluster's width: the coin,
/// "+N" (gold) and the best × (or "0" while nothing was won); it pops on
/// every answer. Screen readers hear the whole sentence.
class _ResultChip extends StatelessWidget {
  const new({
    required this.id,
    required this.coinsWon,
    required this.topMultiplier,
    required this.lastWon,
    required this.scaler,
    super.key,
  });

  final int id;
  final int coinsWon;
  final int? topMultiplier;
  final int lastWon;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spoken = coinsWon > 0
        ? l10n.liveLuckyWon(
            KFormat.bidiIsolate(KFormat.grouped(coinsWon)),
            KFormat.grouped(topMultiplier ?? 0),
          )
        : l10n.liveLuckyNoWin;
    final won = coinsWon > 0;
    final style = context.textStyles.caption.copyWith(
      color: won ? KBrandColors.gold : const Color(0xFFFFFFFF),
      fontWeight: FontWeight.w800,
      height: 1.2,
    );
    final chip = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(3, 2, 7, 2),
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
        border: Border.all(
          color: lastWon > 0 ? KBrandColors.gold : const Color(0x33FFFFFF),
          width: KMetrics.thinStroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KabsoArtIcon(KabsoArt.coin, size: 14),
          const SizedBox(width: 3),
          Text(
            // Digits and signs read left to right in both languages.
            won ? '+${KFormat.grouped(coinsWon)}' : '0',
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            style: style,
          ),
          if (won && topMultiplier != null) ...[
            const SizedBox(width: 4),
            Text(
              l10n.giftCombo(topMultiplier!),
              textScaler: scaler,
              style: style.copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ],
        ],
      ),
    );
    final pop = KMotion.of(context, KMotion.giftComboBump);
    return Semantics(
      liveRegion: true,
      label: spoken,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: pop == Duration.zero
            ? chip
            : TweenAnimationBuilder<double>(
                key: ValueKey('result.$id'),
                tween: Tween(begin: lastWon > 0 ? 1.15 : 1, end: 1),
                duration: pop * 2,
                curve: KMotion.standard,
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: chip,
              ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const new({required this.coins, required this.scaler});

  final int coins;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.liveComboBalance(KFormat.grouped(coins)),
    excludeSemantics: true,
    child: Container(
      key: LuckyComboCluster.balanceKey,
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const KabsoArtIcon(KabsoArt.coin, size: 14),
          const SizedBox(width: 3),
          Text(
            KFormat.grouped(coins),
            textScaler: scaler,
            style: context.textStyles.caption.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
              shadows: KLiveColors.glassShadow,
            ),
          ),
        ],
      ),
    ),
  );
}

/// One gift flying from the button up to [to], shrinking and fading at the
/// end (never with reduced motion: no flight is started then).
class _Flight extends StatefulWidget {
  const new({
    required this.from,
    required this.to,
    required this.assetKey,
    required this.imageUrl,
    required this.onDone,
    super.key,
  });

  final Offset from;
  final Offset to;
  final String assetKey;
  final String? imageUrl;
  final VoidCallback onDone;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: LuckyComboLayer.flightTime,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward().whenComplete(widget.onDone));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          // A slight arc: up first, then across.
          final x = widget.from.dx + (widget.to.dx - widget.from.dx) * t * t;
          final y = widget.from.dy + (widget.to.dy - widget.from.dy) * t;
          final scale = 1.2 - 0.6 * t;
          final opacity = _c.value > 0.8 ? (1 - _c.value) / 0.2 : 1.0;
          return Transform.translate(
            offset: Offset(x - _size / 2, y - _size / 2),
            child: Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: KGiftImage(
          widget.assetKey,
          key: LuckyComboLayer.flightKey,
          imageUrl: widget.imageUrl,
          size: _size,
        ),
      ),
    ),
  );

  static const _size = 40.0;
}
