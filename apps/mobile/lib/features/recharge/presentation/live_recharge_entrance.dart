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
/// end, a short stay, out to the reading start — with «دخل سارة البث» (the
/// person's display name, owner feedback) in its red plate; the mascot
/// stays on the emblem. The timing is the CP entrance's (3.2 s; 2.2 s
/// standing still with reduced motion).
/// Several arrive one after another (at most [maxQueued] waiting). Never
/// takes taps.
///
/// v1.58-social (D189, §10.52): a host agent's join (`user.hostAgent`) shows
/// the host-agent bar the same way — same size, place and timing — with
/// the same «دخل سارة البث». A person who is both gets
/// the recharge-agent bar (owner proposal D189 d: the recharge agent's art
/// wins).
class LiveRechargeEntranceLayer extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  /// Tests and captures turn the slide off (the bar still shows and leaves
  /// on time).
  static bool animate = true;

  static const barKey = Key('live.rechargeEntrance');
  static const textKey = Key('live.rechargeEntrance.text');
  static const nameKey = Key('live.rechargeEntrance.name');

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
      if (line.user.rechargeAgentCode == null &&
          line.user.hostAgentCode == null) {
        return;
      }
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
    if (current == null) return const SizedBox.shrink();
    final rechargeCode = current.user.rechargeAgentCode;
    final AgentEntranceStyle style;
    if (rechargeCode != null) {
      style = AgentEntranceStyle.recharge;
    } else if (current.user.hostAgentCode != null) {
      style = AgentEntranceStyle.host;
    } else {
      return const SizedBox.shrink();
    }
    // Owner feedback: the bar names the person by their display name (the
    // username only when they have none).
    final displayName = current.user.displayName.trim();
    final name = displayName.isEmpty ? current.user.username : displayName;
    final moving =
        LiveRechargeEntranceLayer.animate &&
        !MediaQuery.disableAnimationsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final bar = RechargeEntranceBar(
      key: ValueKey('rechargeEntrance.${current.serial}'),
      name: name,
      style: style,
    );
    return IgnorePointer(
      child: Padding(
        // Owner feedback: fully on screen, [RechargeEntranceBar.sideMargin]
        // from each edge.
        padding: const EdgeInsets.symmetric(
          horizontal: RechargeEntranceBar.sideMargin,
        ),
        child: Align(
          // Above the CP entrance's place, under the gift banners:
          // anchored at the leading side, above the chat (clear of the
          // seats and the host's video centre).
          alignment: const AlignmentDirectional(-1, 0.26),
          child: moving
              ? AnimatedBuilder(
                  animation: _clock,
                  builder: (context, child) {
                    final t = _clock.value;
                    final double dx;
                    // In from the leading side, a short stay, out across the
                    // room to the trailing side (fractions of the bar's
                    // width).
                    if (t < 0.14) {
                      dx = -1.2 * (1 - Curves.easeOutCubic.transform(t / 0.14));
                    } else if (t > 0.86) {
                      dx =
                          2.4 * Curves.easeInCubic.transform((t - 0.86) / 0.14);
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
      ),
    );
  }
}

/// An agent's entrance art and where its text goes (fractions of the art).
/// v1.58-social (D189): the recharge agent's (D185) and the host agent's.
enum AgentEntranceStyle {
  /// D185: the red plate of the recharge agent's bar (2000 × 667 original).
  recharge(
    art: RechargeAgentArt.entrance,
    aspect: RechargeAgentArt.entranceAspect,
    left: 0.44,
    right: 0.915,
    top: 0.367,
    bottom: 0.675,
    left2: 0.425,
    right2: 0.93,
    top2: 0.335,
    bottom2: 0.70,
    shadow: Color(0xCC3A0000),
  ),

  /// D189: the blue plate of the host agent's bar (1050 × 389, trimmed),
  /// clear of the gems on its top and bottom edges.
  host(
    art: HostAgentArt.entrance,
    aspect: HostAgentArt.entranceAspect,
    left: 0.42,
    right: 0.865,
    top: 0.40,
    bottom: 0.68,
    left2: 0.41,
    right2: 0.875,
    top2: 0.37,
    bottom2: 0.73,
    shadow: Color(0xCC001A4D),
  );

  new({
    required this.art,
    required this.aspect,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.left2,
    required this.right2,
    required this.top2,
    required this.bottom2,
    required this.shadow,
  });

  final String art;
  final double aspect;

  /// The plate's one-line text box.
  final double left;
  final double right;
  final double top;
  final double bottom;

  /// The whole inside of the plate (the two-line layout).
  final double left2;
  final double right2;
  final double top2;
  final double bottom2;
  final Color shadow;

  /// The screen-reader label, which keeps the agent type: «دخل وكيل الشحن
  /// سارة البث» / «دخل وكيل المضيفين سارة البث» ([name]: the display name,
  /// isolated so a Latin or mixed name keeps its order).
  String label(AppLocalizations l10n, String name) => this == host
      ? l10n.hostAgentEntranceJoined(KFormat.bidiIsolate(name))
      : l10n.rechargeEntranceJoined(KFormat.bidiIsolate(name));
}

/// The bar itself: the owner's entrance art (the emblem at the left, never
/// mirrored) and, in its plate, «دخل سارة البث» / "Sara joined the live" —
/// the same words for both agent types (the art says which; the
/// screen-reader label keeps the type, [AgentEntranceStyle.label]).
///
/// Owner (after D189): [widthFactor] of the screen's width (≈ 216 lp at
/// 393), never wider than the room less [sideMargin] on each side, the art's
/// proportions kept. The text is ONE line, centred, scaled down to
/// [minFontSize]; when it still does not fit, only the name ends with an
/// ellipsis — «دخل … البث» stays whole.
class RechargeEntranceBar extends StatelessWidget {
  const new({
    required this.name,
    super.key,
    this.style = AgentEntranceStyle.recharge,
  });

  /// The person's display name.
  final String name;
  final AgentEntranceStyle style;

  /// Owner: the bar's share of the screen's width, its margin from the
  /// screen's edges and the smallest text.
  static const widthFactor = 0.55;
  static const sideMargin = 16.0;
  static const minFontSize = 9.0;

  /// The name's slot in the localized text (split around it).
  static const _slot = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = style;
    final isolated = KFormat.bidiIsolate(name);
    final full = l10n.agentEntranceJoined(isolated);
    final parts = l10n.agentEntranceJoined(_slot).split(_slot);
    final before = parts.first.trim();
    final after = parts.length > 1 ? parts.last.trim() : '';
    final screen = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth.isFinite ? box.maxWidth : screen;
        final width = math.min(screen * widthFactor, room);
        final height = width / s.aspect;
        final plateW = width * (s.right - s.left);
        final plateH = height * (s.bottom - s.top);
        final pad = plateH * 0.12;
        final textStyle = context.textStyles.title.copyWith(
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: RechargeAgentArt.plateText,
          shadows: [
            Shadow(color: s.shadow, blurRadius: 3, offset: const Offset(0, 1)),
          ],
        );
        final direction = Directionality.of(context);
        final size = rechargeFitFontSize(
          full,
          textStyle,
          plateW - 2 * pad,
          max: math.max(minFontSize, plateH * 0.62),
          min: minFontSize,
          direction: direction,
        );
        final sized = textStyle.copyWith(fontSize: size);
        // The room left for the name once «دخل … البث» is laid out whole (at
        // least a few letters, so a long name still shows its start).
        double widthOf(String t) {
          if (t.isEmpty) return 0;
          final painter = TextPainter(
            text: TextSpan(text: t, style: sized),
            textDirection: direction,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }

        final gaps =
            (before.isEmpty ? 0 : size * 0.3) +
            (after.isEmpty ? 0 : size * 0.3);
        final nameRoom = math.max(
          size * 3,
          plateW - 2 * pad - widthOf(before) - widthOf(after) - gaps,
        );
        Text piece(String t) => Text(
          t,
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
          style: sized,
        );
        return Semantics(
          liveRegion: true,
          label: s.label(l10n, name),
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
                      s.art,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned(
                    left: width * s.left,
                    width: plateW,
                    top: height * s.top,
                    height: plateH,
                    child: Directionality(
                      textDirection: direction,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        // One line, centred: the phrase whole, the name
                        // ellipsized when nothing else fits.
                        // Only when even the phrase cannot fit at the
                        // smallest size (a very narrow bar) does the line
                        // scale down as a whole.
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              key: LiveRechargeEntranceLayer.textKey,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (before.isNotEmpty) ...[
                                  piece(before),
                                  SizedBox(width: size * 0.3),
                                ],
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: nameRoom,
                                  ),
                                  child: Text(
                                    isolated,
                                    key: LiveRechargeEntranceLayer.nameKey,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    // An ellipsized name leaves no gap
                                    // before «البث».
                                    textWidthBasis: TextWidthBasis.longestLine,
                                    textScaler: TextScaler.noScaling,
                                    style: sized,
                                  ),
                                ),
                                if (after.isNotEmpty) ...[
                                  SizedBox(width: size * 0.3),
                                  piece(after),
                                ],
                              ],
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
