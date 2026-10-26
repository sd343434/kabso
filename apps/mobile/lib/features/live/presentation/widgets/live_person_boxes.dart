import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The three boxes of a person's card in a live (owner, 2026-10-26): small
/// rectangles side by side under the stats, like the reference's tiles — the
/// family (cream with a gold rim), the relationship (CP, lilac) and the gift
/// wall (light grey). Medals are not a box: up to six chosen medals sit in a
/// row under the levels (CP-018).
///
/// None of these exists on the server yet, so every box shows its empty
/// state; nothing is counted or named that does not exist. A tap says it is
/// coming. The art is Kabso's own (owner): Dubi's hug for the family, a
/// heart for CP, the gift box for the gift wall.
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
              colors: const [Color(0xFFFFFBF2), Color(0xFFFFF3DC)],
              border: const Color(0xFFEFCF8E),
              titleColor: const Color(0xFF8A5A12),
              art: KabiEmoji(
                EmojiPack.dubi.emojis.firstWhere((e) => e.id == 'hug'),
                size: 30,
                animate: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Box(
              key: boxKey(1),
              title: l10n.liveUserCp,
              value: l10n.liveUserNone,
              colors: const [Color(0xFFFBF6FF), Color(0xFFF3E6FF)],
              border: const Color(0xFFD4B2FF),
              titleColor: const Color(0xFF8B3FD9),
              art: const Icon(
                Icons.favorite_rounded,
                size: 24,
                color: Color(0xFFE7A6CF),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Box(
              key: boxKey(2),
              title: l10n.liveUserGiftWall,
              value: l10n.liveUserSoon,
              art: Image.asset(
                'assets/live_bar/gift.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Measured on the owner's design file.
abstract final class _Ink {
  static const ink = Color(0xFF2A2233);
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

/// One small box: its picture at the start, the title over a short value.
class _Box extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.art,
    super.key,
    this.colors = const [Color(0xFFF7F6FA), Color(0xFFF7F6FA)],
    this.border,
    this.titleColor = _Ink.mute,
  });

  final String title;
  final String value;
  final Widget art;
  final List<Color> colors;
  final Color? border;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final border = this.border;
    return _SoonTap(
      label: title,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 6, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          children: [
            SizedBox.square(dimension: 30, child: Center(child: art)),
            const SizedBox(width: 6),
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
                      color: titleColor,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyStrong.copyWith(
                      color: _Ink.ink,
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
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
