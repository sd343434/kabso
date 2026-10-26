import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The four boxes of a person's card in a live (owner's design file
/// `kabso_profile_sections.dart`, light style, 2026-10-26): the family card
/// (cream with a gold rim), the relationship (CP) card (lilac, two pictures
/// and a heart, a bar under it), and the gift wall and medals rows (light
/// grey, three pictures and a chevron).
///
/// None of these exists on the server yet, so every box shows its empty
/// state and says "soon"; nothing is counted or named that does not exist.
/// A tap says it is coming. The art is Kabso's own (owner): Dubi's hug for
/// the family, the charm creatures for CP, the gift wall and the medals.
class LivePersonBoxes extends StatelessWidget {
  const new({required this.name, required this.self, this.avatar, super.key});

  /// The person's display name (their picture's initials).
  final String name;

  /// The card is the viewer's own.
  final bool self;
  final ImageProvider? avatar;

  /// Family, relationship, gift wall, medals.
  static Key boxKey(int index) => Key('room.userCard.box$index');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget thumb(Widget child) => Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _Ink.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      // Previews of what will be collected, not owned items.
      child: Opacity(opacity: 0.75, child: child),
    );
    Widget pictures(List<String> assets) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in assets) thumb(Image.asset(a, fit: BoxFit.contain)),
      ],
    );
    // Owner (2026-10-26): the four boxes are rows of one size (the gift
    // wall's).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BoxRow(
          key: boxKey(0),
          title: l10n.liveUserFamily,
          subtitle: self
              ? l10n.liveUserFamilyNoneSelf
              : l10n.liveUserFamilyNone,
          colors: const [Color(0xFFFFFBF2), Color(0xFFFFF3DC)],
          border: const Color(0xFFEFCF8E),
          titleColor: const Color(0xFF8A5A12),
          rtl: rtl,
          trailing: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFFFE9F4), Color(0xFFFFC3DF)],
              ),
              border: Border.all(color: _Ink.white, width: 2),
            ),
            alignment: Alignment.center,
            child: KabiEmoji(
              EmojiPack.dubi.emojis.firstWhere((e) => e.id == 'hug'),
              size: 34,
              animate: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _BoxRow(
          key: boxKey(1),
          title: l10n.liveUserCp,
          subtitle: l10n.liveUserCpNone,
          colors: const [Color(0xFFFBF6FF), Color(0xFFF3E6FF)],
          border: const Color(0xFFD4B2FF),
          titleColor: const Color(0xFF8B3FD9),
          rtl: rtl,
          trailing: SizedBox(
            width: 82,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PositionedDirectional(
                  start: 0,
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: 36,
                      child: KAvatar(name: name, image: avatar, size: 36),
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _Ink.white.withValues(alpha: 0.7),
                      border: Border.all(
                        color: const Color(0xFFD4B2FF),
                        width: 1.6,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: Color(0xFFB98AF0),
                    ),
                  ),
                ),
                const Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: Color(0xFFE7A6CF),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _BoxRow(
          key: boxKey(2),
          title: l10n.liveUserGiftWall,
          subtitle: l10n.liveUserSoon,
          rtl: rtl,
          trailing: pictures([
            'assets/live_bar/gift.png',
            CharmTier.unicorn.icon,
            CharmTier.fox.icon,
          ]),
        ),
        const SizedBox(height: 8),
        _BoxRow(
          key: boxKey(3),
          title: l10n.liveUserMedals,
          subtitle: l10n.liveUserSoon,
          rtl: rtl,
          trailing: pictures([
            CharmTier.phoenix.icon,
            CharmTier.royal.icon,
            CharmTier.butterfly.icon,
          ]),
        ),
      ],
    );
  }
}

// Measured on the owner's design file.
abstract final class _Ink {
  static const ink = Color(0xFF2A2233);
  static const mute = Color(0xFF9A93A6);
  static const white = Color(0xFFFFFFFF);
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

/// One box row (the design's gift wall row, used by all four): title and a
/// line under it at the start, pictures and a chevron at the end, on a tint
/// with an optional rim.
class _BoxRow extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.rtl,
    super.key,
    this.colors = const [Color(0xFFF7F6FA), Color(0xFFF7F6FA)],
    this.border,
    this.titleColor = _Ink.ink,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final bool rtl;
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
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          border: border == null ? null : Border.all(color: border, width: 1.3),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyStrong.copyWith(
                      color: titleColor,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(
                      color: _Ink.mute,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
            const SizedBox(width: 2),
            Icon(
              rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: const Color(0xFFB9B3C3),
            ),
          ],
        ),
      ),
    );
  }
}
