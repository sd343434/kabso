import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The three boxes of a person's card in a live (owner, 2026-10-26): small
/// cards side by side under the stats — the family (gold), the relationship
/// (CP, rose) and the gift wall (lilac), each with the owner's 3D icon
/// (`assets/card_boxes/`) on top and its name and value centred under it.
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
              tint: const Color(0xFFFFE3A3),
              rim: const Color(0xFFEDB94E),
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
              tint: const Color(0xFFFFC8DC),
              rim: const Color(0xFFF58AB0),
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
              tint: const Color(0xFFDCCBFF),
              rim: const Color(0xFFAE8CFF),
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

/// One small box (owner, 2026-10-26): the 3D icon inside at the top, the
/// name in the box's colour, and a coloured band along the bottom with the
/// value (for the relationship: the partner's picture, name and a heart).
/// The box is a rich tint fading to white, framed twice (a coloured rim and
/// a thin white line inside it), with a coloured shadow.
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
    this.partner,
    this.onTap,
  });

  final String title;
  final String value;

  /// The value is real data.
  final bool filled;
  final bool soon;
  final ({String name, ImageProvider? avatar})? partner;
  final VoidCallback? onTap;
  final String icon;
  final Color tint;
  final Color rim;
  final Color accent;

  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    const white = Color(0xFFFFFFFF);
    final partner = this.partner;
    final valueStyle = text.caption.copyWith(
      color: filled ? white : white.withValues(alpha: 0.9),
      fontSize: 11.5,
      height: 1.2,
      fontWeight: FontWeight.w800,
    );
    final band = partner == null
        ? Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: valueStyle,
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: white,
                ),
                child: KAvatar(
                  // Initials from the name without its direction marks.
                  name: partner.name.replaceAll(RegExp('[\u2066-\u2069]'), ''),
                  image: partner.avatar,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  partner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.favorite_rounded, size: 13, color: white),
            ],
          );
    return _BoxTap(
      label: title,
      value: value,
      soon: soon,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: rim, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius - 1.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(tint, white, 0.6)!, tint],
              ),
            ),
            child: Column(
              children: [
                // The inner white line.
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(3, 3, 3, 0),
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(_radius - 4),
                        bottom: Radius.circular(8),
                      ),
                      border: Border.all(color: white.withValues(alpha: 0.85)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 48,
                          child: Image.asset(icon),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: text.bodyStrong.copyWith(
                            color: accent,
                            fontSize: 13.5,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // The band along the bottom.
                Container(
                  width: double.infinity,
                  // One height for every band (with or without a picture).
                  constraints: const BoxConstraints(minHeight: 30),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        Color.lerp(accent, white, 0.15)!,
                        Color.lerp(accent, rim, 0.45)!,
                      ],
                    ),
                  ),
                  child: band,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
