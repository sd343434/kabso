import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The three boxes of a person's card in a live (owner, 2026-10-26): small
/// cards side by side under the stats — the family (gold), the relationship
/// (CP, rose) and the gift wall (lilac), each with a 3D icon from Kabso's own
/// art (the leaderboard's gold shield and heart, D84; the owner's gift box,
/// D74). Medals are not a box: up to six chosen medals sit in a row under the
/// levels (CP-018).
///
/// CP-018 (§10.21): the family and relationship boxes show the person's
/// real family ([familyValue], e.g. its name and level) and couple
/// ([cpValue], the partner and tier) from `GET /users/{username}`, and open
/// what exists through [onFamily] / [onCp] (null: nothing to open, the box
/// is not a button). The gift wall has no API yet: it says it is coming.
class LivePersonBoxes extends StatelessWidget {
  const new({
    super.key,
    this.familyValue,
    this.cpValue,
    this.onFamily,
    this.onCp,
  });

  /// The family box's line; null = "None yet".
  final String? familyValue;

  /// The relationship box's line; null = "None yet".
  final String? cpValue;

  final VoidCallback? onFamily;
  final VoidCallback? onCp;

  /// Family, relationship, gift wall.
  static Key boxKey(int index) => Key('room.userCard.box$index');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // One height for the three, the tallest one's (a title may wrap).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Box(
              key: boxKey(0),
              title: l10n.liveUserFamily,
              value: familyValue ?? l10n.liveUserNone,
              filled: familyValue != null,
              onTap: onFamily,
              icon: 'assets/leaderboard/rank_shield_1.webp',
              tint: const Color(0xFFFFF4DA),
              rim: const Color(0xFFF1D08A),
              accent: const Color(0xFFA8670A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Box(
              key: boxKey(1),
              title: l10n.liveUserCp,
              value: cpValue ?? l10n.liveUserNone,
              filled: cpValue != null,
              onTap: onCp,
              icon: 'assets/leaderboard/heart.webp',
              tint: const Color(0xFFFFE8F0),
              rim: const Color(0xFFF6B7CB),
              accent: const Color(0xFFD03468),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Box(
              key: boxKey(2),
              title: l10n.liveUserGiftWall,
              value: l10n.liveUserSoon,
              soon: true,
              icon: 'assets/art/kabso_gift_box.webp',
              tint: const Color(0xFFF0EAFF),
              rim: const Color(0xFFCDBBFF),
              accent: const Color(0xFF7448DC),
            ),
          ),
        ],
      ),
    );
  }
}

// Measured on the owner's design file.
abstract final class _Ink {
  static const mute = Color(0xFF9A93A6);
  static const ink = Color(0xFF2E3130);
}

/// A box as a button: it opens [onTap], or with [soon] says its feature is
/// coming, and sinks a little while pressed (the design's `_Press`).
/// Neither: not a button.
class _BoxTap extends StatefulWidget {
  const new({
    required this.label,
    required this.value,
    required this.child,
    this.onTap,
    this.soon = false,
  });

  final String label;
  final String value;
  final Widget child;
  final VoidCallback? onTap;
  final bool soon;

  @override
  State<_BoxTap> createState() => _BoxTapState();
}

class _BoxTapState extends State<_BoxTap> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tap = widget.soon
        ? () => KSnack.info(context, l10n.liveUserBoxSoon(widget.label))
        : widget.onTap;
    if (tap == null) {
      return Semantics(
        label: '${widget.label}, ${widget.value}',
        excludeSemantics: true,
        child: widget.child,
      );
    }
    return Semantics(
      button: true,
      label: '${widget.label}, ${widget.value}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: tap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// One small box: a 3D icon on a soft glow at the start, the title in the
/// box's colour over a short value, on a tint that fades to white with a
/// thin rim and a coloured shadow.
class _Box extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.rim,
    required this.accent,
    super.key,
    this.filled = false,
    this.soon = false,
    this.onTap,
  });

  final String title;
  final String value;

  /// The value is real data (darker, like the title's ink).
  final bool filled;
  final bool soon;
  final VoidCallback? onTap;
  final String icon;
  final Color tint;
  final Color rim;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return _BoxTap(
      label: title,
      value: value,
      soon: soon,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsetsDirectional.fromSTEB(7, 7, 6, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [tint, const Color(0xFFFFFFFF)],
          ),
          border: Border.all(color: rim.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFFFFFFF), tint.withValues(alpha: 0)],
                ),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                icon,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(
                      color: accent,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(
                      color: filled ? _Ink.ink : _Ink.mute,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
