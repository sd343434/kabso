// D388 (owner: «اجعل عند ضغط عن اي شارة التطبيق يشرح ما هي بصندوق صغير
// شفاف»; CONVENTIONS §10.177): a tap on any badge shows what it is in a
// small translucent box beside it.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// D388: wraps a badge so a tap on it shows [message] (what the badge is,
/// in the app's language) in a small dark-glass bubble next to it.
///
/// - One bubble at a time: opening another closes the first.
/// - It closes by itself after [showFor], on a tap anywhere outside it, on a
///   tap on it, or on a second tap on the badge.
/// - It sits under the badge, or above it when there is no room below, and
///   is kept inside the screen (and its safe area) on both sides; its text
///   follows the app's direction (Arabic right to left, English left to
///   right).
/// - The tap is the badge's own: inside a tappable row (a chat line, a list
///   tile, a card) a tap on the badge shows the bubble and does not also
///   open the row. A tap beside the badge still reaches the row.
/// - Screen readers already hear each badge's own label, so the wrapper
///   adds no semantics of its own.
class KBadgeExplainer extends StatefulWidget {
  const new({
    required this.message,
    required this.child,
    super.key,
    this.enabled = true,
  });

  /// What the badge is («مستوى الثروة 25» / "Wealth level 25").
  final String message;

  final Widget child;

  /// False: the badge is drawn as it is, with no tap (a badge that is
  /// itself a picker's option, a preview, an animation).
  final bool enabled;

  /// How long the bubble stays.
  static const Duration showFor = Duration(seconds: 3);

  /// The bubble's fade and grow.
  static const Duration fadeIn = Duration(milliseconds: 140);

  static const bubbleKey = Key('k.badgeExplainer.bubble');
  static const textKey = Key('k.badgeExplainer.text');

  /// The bubble's widest (it wraps to more lines beyond it).
  static const double maxWidth = 260;

  /// The gap between the badge and the bubble.
  static const double gap = 6;

  /// The bubble's least distance from the screen's (safe) edges.
  static const double margin = 12;

  /// The dark glass: a near-black tint at 72 % over a blur of what is
  /// behind it, with a faint light edge — white text on it stays ≥ 7 : 1
  /// over any page, light or dark.
  static const Color glass = Color(0xB8121018);
  static const Color edge = Color(0x33FFFFFF);
  static const Color ink = Color(0xFFFFFFFF);
  static const double blur = 12;
  static const double radius = 12;

  /// Closes the bubble that is showing, if any.
  static void dismiss() => _KBadgeExplainerState._current?._hide();

  @override
  State<KBadgeExplainer> createState() => _KBadgeExplainerState();
}

class _KBadgeExplainerState extends State<KBadgeExplainer> {
  /// The one bubble showing in the app.
  static _KBadgeExplainerState? _current;

  final _portal = OverlayPortalController();
  final _group = Object();
  Timer? _timer;

  void _toggle() {
    if (_portal.isShowing) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    final current = _current;
    if (current != null && current != this) current._hide();
    _current = this;
    _timer?.cancel();
    _timer = Timer(KBadgeExplainer.showFor, _hide);
    _portal.show();
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    if (_current == this) _current = null;
    if (mounted && _portal.isShowing) _portal.hide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_current == this) _current = null;
    super.dispose();
  }

  /// The badge's box in the overlay's coordinates.
  Rect? _target(BuildContext overlayContext) {
    final badge = context.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (badge is! RenderBox || !badge.hasSize || overlay is! RenderBox) {
      return null;
    }
    final topLeft = badge.localToGlobal(Offset.zero, ancestor: overlay);
    return topLeft & badge.size;
  }

  Widget _bubble(BuildContext overlayContext) {
    final target = _target(overlayContext);
    if (target == null) return const SizedBox.shrink();
    final safe = MediaQuery.paddingOf(context);
    return CustomSingleChildLayout(
      delegate: KBadgeExplainerLayout(target: target, safe: safe),
      child: TapRegion(
        groupId: _group,
        onTapOutside: (_) => _hide(),
        child: GestureDetector(
          onTap: _hide,
          child: KBadgeExplainerBubble(message: widget.message),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _bubble,
      child: TapRegion(
        groupId: _group,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _toggle,
          child: widget.child,
        ),
      ),
    );
  }
}

/// D388: the bubble itself — [message] in white on the dark glass.
class KBadgeExplainerBubble extends StatelessWidget {
  const new({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).extension<KTheme>()?.text.caption ??
        const TextStyle(fontSize: 13);
    const shape = BorderRadius.all(Radius.circular(KBadgeExplainer.radius));
    // Reduce motion: the bubble appears at once.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? Duration.zero : KBadgeExplainer.fadeIn,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: Semantics(
        liveRegion: true,
        label: message,
        excludeSemantics: true,
        child: ClipRRect(
          key: KBadgeExplainer.bubbleKey,
          borderRadius: shape,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: KBadgeExplainer.blur,
              sigmaY: KBadgeExplainer.blur,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KBadgeExplainer.glass,
                borderRadius: shape,
                border: Border.all(color: KBadgeExplainer.edge, width: 0.6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  message,
                  key: KBadgeExplainer.textKey,
                  textAlign: TextAlign.center,
                  style: base.copyWith(
                    color: KBadgeExplainer.ink,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D388: where the bubble goes — centred on the badge ([target]), under it
/// when it fits, else above it; always inside the screen less its [safe]
/// area and [KBadgeExplainer.margin]. Symmetric, so it is the same in both
/// reading directions.
class KBadgeExplainerLayout extends SingleChildLayoutDelegate {
  const new({required this.target, required this.safe});

  final Rect target;
  final EdgeInsets safe;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    const m = KBadgeExplainer.margin;
    final width = math.max<double>(
      0,
      math.min(KBadgeExplainer.maxWidth, constraints.maxWidth - 2 * m),
    );
    final height = math.max<double>(
      0,
      constraints.maxHeight - safe.vertical - 2 * m,
    );
    return BoxConstraints(maxWidth: width, maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const m = KBadgeExplainer.margin;
    const g = KBadgeExplainer.gap;
    final top = safe.top + m;
    final bottom = size.height - safe.bottom - m;
    final below = target.bottom + g;
    final above = target.top - g - childSize.height;
    final y = below + childSize.height <= bottom || above < top ? below : above;
    final x = target.center.dx - childSize.width / 2;
    final left = safe.left + m;
    final right = size.width - safe.right - m - childSize.width;
    return Offset(
      right < left ? left : x.clamp(left, right),
      math.max(top, math.min(y, bottom - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(KBadgeExplainerLayout old) =>
      old.target != target || old.safe != safe;
}
