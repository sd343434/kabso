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
/// None of these exists on the server yet, so every box shows its empty
/// state; nothing is counted or named that does not exist. A tap says it is
/// coming.
class LivePersonBoxes extends StatelessWidget {
  const new({super.key});

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
              value: l10n.liveUserNone,
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
              value: l10n.liveUserNone,
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
}

/// A box: a button that says its feature is coming, and sinks a little
/// while pressed (the design's `_Press`).
class _SoonTap extends StatefulWidget {
  const new({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  State<_SoonTap> createState() => _SoonTapState();
}

class _SoonTapState extends State<_SoonTap> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: '${widget.label}, ${l10n.liveUserSoon}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () => KSnack.info(context, l10n.liveUserBoxSoon(widget.label)),
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
  });

  final String title;
  final String value;
  final String icon;
  final Color tint;
  final Color rim;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return _SoonTap(
      label: title,
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
                      color: _Ink.mute,
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
