import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_level_ticker.dart';
import 'package:kabso_live/features/live/domain/live_level_ticker.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D254 (owner's reference, 393 × 852 pt: a dark translucent pill with a
/// thin gold border right under the header row, ≈ 8 pt to 384 pt wide,
/// ≈ 21 pt tall): «🎉 تهانينا لـ فلان على الترقية إلى المستوى 31 في غرفة
/// البث المباشر الخاصة بـ …» — the person's support badge or charm badge at
/// the start, the text scrolling ([LiveMarqueeText]) for
/// [LiveLevelTickers.showTime]. A tap opens that live ([onOpenRoom]; none,
/// or this very live: not a button), as the gift strip (D178).
class LiveLevelTickerBar extends ConsumerWidget {
  const new({required this.roomId, super.key, this.onOpenRoom});

  final String roomId;
  final ValueChanged<String>? onOpenRoom;

  static const tickerKey = Key('level.global.ticker');

  /// The ref's height and side insets.
  static const double height = 21;
  static const double start = 8;
  static const double end = 9;

  /// The banner's top for a top inset of [inset]: right under the header
  /// row's pill (ref: ≈ 5 pt under it), over the second row, above the
  /// side cards (`KLiveRoomScaffold.sideEndTop`).
  static double topFor(double inset) =>
      KLiveRoomScaffold.headerTop(inset) + 46.5;

  static const Color fill = Color(0xE0141018);
  static const Color border = Color(0xCCF3D27A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticker = ref.watch(liveLevelTickersProvider(roomId));
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: ticker == null
          ? const SizedBox.shrink()
          : _bar(context, ref, ticker),
    );
  }

  Widget _bar(BuildContext context, WidgetRef ref, LevelTicker ticker) {
    final l10n = context.l10n;
    final text = l10n.liveLevelTicker(
      KFormat.bidiIsolate(ticker.user.displayName),
      ticker.level,
      KFormat.bidiIsolate(ticker.room.host.displayName),
    );
    final kind = ticker.category == LevelCategory.support
        ? l10n.liveLevelTickerSupport
        : l10n.liveLevelTickerCharm;
    final open = ticker.room.id == roomId ? null : onOpenRoom;
    final bar = Container(
      height: height,
      padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        children: [
          MediaQuery.withNoTextScaling(
            child: ticker.category == LevelCategory.support
                ? KLevelBadge(
                    category: LevelCategory.support,
                    levelNumber: ticker.level,
                    height: 12,
                  )
                : CharmLevelBadge(level: ticker.level, height: 11),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.celebration_rounded,
            size: 13,
            color: Color(0xFFFFD66B),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: LiveMarqueeText(
              text,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
    void tap() {
      ref.read(liveLevelTickersProvider(roomId).notifier).dismiss();
      open!(ticker.room.id);
    }

    return Semantics(
      key: ValueKey('levelTicker.${ticker.id}'),
      container: true,
      liveRegion: true,
      button: open != null,
      label: '$kind. $text',
      excludeSemantics: true,
      onTap: open == null ? null : tap,
      child: KeyedSubtree(
        key: tickerKey,
        child: open == null
            ? bar
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tap,
                child: bar,
              ),
      ),
    );
  }
}

/// D254: one line of text that scrolls in the reading direction when it is
/// wider than its room — it waits [pause] at its start, then moves at
/// [speed] pt/s until its copy ([gap] after it) is back at the start, and
/// again. Text that fits, or reduced motion («تقليل الحركة»), does not move:
/// it ends in an ellipsis.
class LiveMarqueeText extends StatefulWidget {
  const new(
    this.text, {
    required this.style,
    super.key,
    this.speed = 40,
    this.gap = 48,
    this.pause = const Duration(seconds: 1),
  });

  final String text;
  final TextStyle style;

  /// Points per second.
  final double speed;
  final double gap;
  final Duration pause;

  /// The moving row (tests read its offset).
  static const movingKey = Key('marquee.moving');

  /// The still, ellipsized text.
  static const stillKey = Key('marquee.still');

  @override
  State<LiveMarqueeText> createState() => _LiveMarqueeTextState();
}

class _LiveMarqueeTextState extends State<LiveMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Starts (or retimes) the loop after this frame: never while building.
  void _run(Duration period) {
    if (_controller.duration == period && _controller.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.duration == period && _controller.isAnimating) return;
      _controller
        ..duration = period
        ..repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 1, maxScaleFactor: 1.2);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        final lineHeight = painter.height;
        painter.dispose();
        final still = MediaQuery.disableAnimationsOf(context);
        if (still || width <= constraints.maxWidth) {
          if (_controller.isAnimating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _controller.stop();
            });
          }
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              widget.text,
              key: LiveMarqueeText.stillKey,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: widget.style,
            ),
          );
        }
        final travel = width + widget.gap;
        final moveMs = (travel / widget.speed * 1000).round();
        final period = widget.pause + Duration(milliseconds: moveMs);
        _run(period);
        final hold = widget.pause.inMilliseconds / period.inMilliseconds;
        final curve = Interval(hold, 1);
        final sign = direction == TextDirection.rtl ? 1.0 : -1.0;
        Widget line() => Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          textScaler: scaler,
          style: widget.style,
        );
        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            height: lineHeight,
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: double.infinity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.translate(
                  key: LiveMarqueeText.movingKey,
                  offset: Offset(
                    sign * travel * curve.transform(_controller.value),
                    0,
                  ),
                  child: child,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    line(),
                    SizedBox(width: widget.gap),
                    line(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
