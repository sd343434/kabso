import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The three boxes of a person's card in a live (owner, 2026-10-26): small
/// light grey cards side by side under the stats — the family (gold title),
/// the relationship (CP, rose) and the gift wall (lilac), each with the
/// owner's 3D icon (`assets/card_boxes/`).
/// Medals are not a box: up to six chosen medals sit in a row under the
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
    this.cpPartner,
    this.onFamily,
    this.onCp,
  });

  /// The family box's line; null = "None yet".
  final String? familyValue;

  /// The relationship box's line when there is no partner (e.g. "Send a
  /// request"); null = "None yet".
  final String? cpValue;

  /// The partner (owner, 2026-10-26): their picture, name and a heart along
  /// the box's bottom instead of a line.
  final ({String name, ImageProvider? avatar})? cpPartner;

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
              icon: 'assets/card_boxes/family.webp',
              accent: const Color(0xFFB0670A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Box(
              key: boxKey(1),
              title: l10n.liveUserCp,
              value: cpPartner?.name ?? cpValue ?? l10n.liveUserNone,
              filled: cpPartner != null || cpValue != null,
              partner: cpPartner,
              onTap: onCp,
              icon: 'assets/card_boxes/cp.webp',
              accent: const Color(0xFFD62A66),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Box(
              key: boxKey(2),
              title: l10n.liveUserGiftWall,
              value: l10n.liveUserSoon,
              soon: true,
              icon: 'assets/card_boxes/gift_wall.webp',
              accent: const Color(0xFF6E3FE0),
            ),
          ),
        ],
      ),
    );
  }
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

/// One small box (owner, 2026-10-26: simple, like the medal wall row): a
/// light grey rounded rectangle, the name in the box's colour over the value
/// at the start, the 3D icon at the end. For the relationship the value is
/// the partner's small picture, name and a heart.
class _Box extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    super.key,
    this.filled = false,
    this.soon = false,
    this.partner,
    this.onTap,
  });

  final String title;
  final String value;

  /// The value is real data (dark ink; otherwise grey).
  final bool filled;
  final bool soon;
  final ({String name, ImageProvider? avatar})? partner;
  final VoidCallback? onTap;
  final String icon;

  /// The title's colour (gold, rose, lilac).
  final Color accent;

  static const _grey = Color(0xFFF4F4F7);
  static const _ink = Color(0xFF2E3130);
  static const _soft = Color(0xFF9A9BA5);

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final partner = this.partner;
    final valueStyle = text.caption.copyWith(
      color: filled ? _ink : _soft,
      fontSize: 11.5,
      height: 1.25,
      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
    );
    final line = partner == null
        ? Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          )
        : Row(
            children: [
              KAvatar(
                // Initials from the name without its direction marks.
                name: partner.name.replaceAll(RegExp('[\u2066-\u2069]'), ''),
                image: partner.avatar,
                size: 16,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  partner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.favorite_rounded, size: 11, color: accent),
            ],
          );
    return _BoxTap(
      label: title,
      value: value,
      soon: soon,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 5, 8),
        decoration: BoxDecoration(
          color: _grey,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // A long name shrinks a little to stay on one line.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: text.bodyStrong.copyWith(
                        color: accent,
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  line,
                ],
              ),
            ),
            const SizedBox(width: 3),
            SizedBox.square(dimension: 32, child: Image.asset(icon)),
          ],
        ),
      ),
    );
  }
}
