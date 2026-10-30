import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The recharge agent's entrance (v1.54-social, D185, CONVENTIONS §10.48):
/// when a `join` data message's `user` carries `rechargeAgent` (an ACTIVE
/// agent), the owner's entrance bar crosses the room — in from the reading
/// end, a short stay, out to the reading start — with «دخل وكيل الشحن
/// coin0001» in its red plate; the mascot stays on the emblem. The timing
/// is the CP entrance's (3.2 s; 2.2 s standing still with reduced motion).
/// Several arrive one after another (at most [maxQueued] waiting). Never
/// takes taps.
class LiveRechargeEntranceLayer extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  /// Tests and captures turn the slide off (the bar still shows and leaves
  /// on time).
  static bool animate = true;

  static const barKey = Key('live.rechargeEntrance');
  static const textKey = Key('live.rechargeEntrance.text');

  /// The CP entrance's timing (CP-021, §10.24).
  static const duration = Duration(milliseconds: 3200);
  static const stillDuration = Duration(milliseconds: 2200);
  static const maxQueued = 5;

  @override
  ConsumerState<LiveRechargeEntranceLayer> createState() =>
      _LiveRechargeEntranceLayerState();
}

class _LiveRechargeEntranceLayerState
    extends ConsumerState<LiveRechargeEntranceLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final _queue = Queue<LiveChatJoinLine>();
  LiveChatJoinLine? _current;
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _seen = ref.read(liveChatProvider(widget.roomId)).latestJoin?.serial ?? -1;
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _onChat(LiveChatState next) {
    if (next.latestJoin case final line?) {
      if (line.serial <= _seen) return;
      _seen = line.serial;
      if (line.user.rechargeAgentCode == null) return;
      if (_current == null) {
        _show(line);
      } else if (_queue.length < LiveRechargeEntranceLayer.maxQueued) {
        _queue.add(line);
      }
    }
  }

  void _show(LiveChatJoinLine line) {
    final still =
        !LiveRechargeEntranceLayer.animate ||
        MediaQuery.disableAnimationsOf(context);
    _clock.duration = still
        ? LiveRechargeEntranceLayer.stillDuration
        : LiveRechargeEntranceLayer.duration;
    setState(() => _current = line);
    _clock.forward(from: 0);
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      setState(() => _current = null);
    } else {
      _show(_queue.removeFirst());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveChatProvider(widget.roomId), (_, next) => _onChat(next));
    final current = _current;
    final code = current?.user.rechargeAgentCode;
    if (current == null || code == null) return const SizedBox.shrink();
    final moving =
        LiveRechargeEntranceLayer.animate &&
        !MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final bar = RechargeEntranceBar(
      key: ValueKey('rechargeEntrance.${current.serial}'),
      code: code,
    );
    return IgnorePointer(
      child: Align(
        // Above the CP entrance's place, under the gift banners.
        // Owner (D185 feedback): a smaller strip anchored at the leading side,
        // above the chat (clear of the seats and the host's video centre).
        alignment: const AlignmentDirectional(-1, 0.26),
        child: moving
            ? AnimatedBuilder(
                animation: _clock,
                builder: (context, child) {
                  final t = _clock.value;
                  final double dx;
                  // In from the leading side, a short stay, out across the room
                  // to the trailing side (fractions of the bar's width).
                  if (t < 0.14) {
                    dx = -1.2 * (1 - Curves.easeOutCubic.transform(t / 0.14));
                  } else if (t > 0.86) {
                    dx = 2.4 * Curves.easeInCubic.transform((t - 0.86) / 0.14);
                  } else {
                    dx = 0;
                  }
                  return FractionalTranslation(
                    translation: Offset(rtl ? -dx : dx, 0),
                    child: child,
                  );
                },
                child: bar,
              )
            : bar,
      ),
    );
  }
}

/// The bar itself: the owner's entrance art (the mascot on the emblem at the
/// left, never mirrored) and «دخل وكيل الشحن coin0001» fitted into its red
/// plate. Owner feedback (D185): 65 % of the room's width and at most
/// [maxHeight] high, the art's proportions kept; the text scales with the
/// bar down to [minFontSize], then ends with an ellipsis.
class RechargeEntranceBar extends StatelessWidget {
  const new({required this.code, super.key});

  final String code;

  /// Owner feedback (D185): the bar's share of the room's width, its
  /// largest height on phones and the smallest readable text.
  static const widthFactor = 0.65;
  static const maxHeight = 64.0;
  static const minFontSize = 11.0;

  // The plate's text box on the art (2000 × 667).
  static const _left = 0.44;
  static const _right = 0.915;
  static const _top = 0.367;
  static const _bottom = 0.675;

  // The whole dark-red inside of the plate (the two-line layout).
  static const _left2 = 0.425;
  static const _right2 = 0.93;
  static const _top2 = 0.335;
  static const _bottom2 = 0.70;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = l10n.rechargeEntranceJoined(KFormat.bidiIsolate(code));
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(
          box.maxWidth * widthFactor,
          maxHeight * RechargeAgentArt.entranceAspect,
        );
        final height = width / RechargeAgentArt.entranceAspect;
        final plateH = height * (_bottom - _top);
        final style = context.textStyles.title.copyWith(
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: RechargeAgentArt.plateText,
          shadows: const [
            Shadow(
              color: Color(0xCC3A0000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        );
        final direction = Directionality.of(context);
        final plateW = width * (_right - _left);
        final pad = plateH * 0.15;
        final size = rechargeFitFontSize(
          text,
          style,
          plateW - 2 * pad,
          max: math.max(minFontSize, plateH * 0.62),
          min: minFontSize,
          direction: direction,
        );
        // One line when the whole text fits at [minFontSize] or larger.
        final oneLine = rechargeTextFits(
          text,
          style.copyWith(fontSize: size),
          plateW - 2 * pad,
          direction,
        );
        // The phrase without the code (for the two-line layout).
        final phrase = text
            .replaceAll(KFormat.bidiIsolate(code), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return Semantics(
          liveRegion: true,
          label: text,
          excludeSemantics: true,
          child: SizedBox(
            key: LiveRechargeEntranceLayer.barKey,
            width: width,
            height: height,
            // The art reads left to right in both languages (the emblem stays
            // on the left); the text inside follows the language.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      RechargeAgentArt.entrance,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    left: width * (oneLine ? _left : _left2),
                    width: oneLine ? plateW : width * (_right2 - _left2),
                    top: height * (oneLine ? _top : _top2),
                    height:
                        height * (oneLine ? _bottom - _top : _bottom2 - _top2),
                    child: Directionality(
                      textDirection: direction,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: oneLine ? pad : 1,
                          ),
                          child: oneLine
                              ? Text(
                                  text,
                                  key: LiveRechargeEntranceLayer.textKey,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  textScaler: TextScaler.noScaling,
                                  style: style.copyWith(fontSize: size),
                                )
                              // Too narrow for one readable line: the phrase
                              // over the code, both at least [minFontSize].
                              : Column(
                                  key: LiveRechargeEntranceLayer.textKey,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final (i, line) in [
                                      phrase,
                                      code,
                                    ].indexed)
                                      Text(
                                        line,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        textDirection: i == 1
                                            ? TextDirection.ltr
                                            : null,
                                        textScaler: TextScaler.noScaling,
                                        style: style.copyWith(
                                          fontSize: minFontSize,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
