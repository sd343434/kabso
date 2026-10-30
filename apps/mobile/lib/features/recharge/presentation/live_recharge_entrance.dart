import 'dart:collection';

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
        alignment: const Alignment(0, 0.12),
        child: moving
            ? AnimatedBuilder(
                animation: _clock,
                builder: (context, child) {
                  final t = _clock.value;
                  final double dx;
                  if (t < 0.14) {
                    dx = 1.1 * (1 - Curves.easeOutCubic.transform(t / 0.14));
                  } else if (t > 0.86) {
                    dx = -1.1 * Curves.easeInCubic.transform((t - 0.86) / 0.14);
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
/// plate. 92 % of the room's width, at most 420 lp.
class RechargeEntranceBar extends StatelessWidget {
  const new({required this.code, super.key});

  final String code;

  // The plate's text box on the art (2000 × 667).
  static const _left = 0.44;
  static const _right = 0.915;
  static const _top = 0.367;
  static const _bottom = 0.675;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = l10n.rechargeEntranceJoined(KFormat.bidiIsolate(code));
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth * 0.92).clamp(0.0, 420.0);
        final height = width / RechargeAgentArt.entranceAspect;
        final plateH = height * (_bottom - _top);
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
                    left: width * _left,
                    width: width * (_right - _left),
                    top: height * _top,
                    height: plateH,
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: plateH * 0.2,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              text,
                              key: LiveRechargeEntranceLayer.textKey,
                              maxLines: 1,
                              textScaler: TextScaler.noScaling,
                              style: context.textStyles.title.copyWith(
                                fontSize: plateH * 0.42,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: RechargeAgentArt.plateText,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xCC3A0000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
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
