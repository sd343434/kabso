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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FamilyCard(
          key: boxKey(0),
          label: l10n.liveUserFamily,
          title: self ? l10n.liveUserFamilyNoneSelf : l10n.liveUserFamilyNone,
        ),
        const SizedBox(height: 10),
        _CpCard(key: boxKey(1), name: name, avatar: avatar),
        const SizedBox(height: 10),
        _CollectionRow(
          key: boxKey(2),
          title: l10n.liveUserGiftWall,
          thumbs: [
            'assets/live_bar/gift.png',
            CharmTier.unicorn.icon,
            CharmTier.fox.icon,
          ],
        ),
        const SizedBox(height: 8),
        _CollectionRow(
          key: boxKey(3),
          title: l10n.liveUserMedals,
          thumbs: [
            CharmTier.phoenix.icon,
            CharmTier.royal.icon,
            CharmTier.butterfly.icon,
          ],
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

/// The "soon" pill where the design has an action (Join, find a partner).
class _SoonPill extends StatelessWidget {
  const new({required this.colors, required this.ink, this.shadow});

  final List<Color> colors;
  final Color ink;
  final Color? shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
      boxShadow: [
        if (shadow case final shadow?)
          BoxShadow(color: shadow, blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 13, color: ink),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.l10n.liveUserSoon,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.caption.copyWith(
              color: ink,
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Family (empty state): Dubi's hug in a pink medallion, "not in a family
/// yet", the owner's hint, and "soon" where Join will be.
class _FamilyCard extends StatelessWidget {
  const new({required this.label, required this.title, super.key});

  final String label;
  final String title;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final hug = EmojiPack.dubi.emojis.firstWhere((e) => e.id == 'hug');
    // Large text: the pill goes under the words instead of squeezing them.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    const pill = _SoonPill(
      colors: [Color(0xFFF2B544), Color(0xFFE08A14)],
      ink: _Ink.white,
      shadow: Color(0x4DE08A14),
    );
    return _SoonTap(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF2), Color(0xFFFFF6E4)],
          ),
          border: Border.all(color: const Color(0xFFEFCF8E), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1FD6A03C),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x8CEFCF8E)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    colors: [Color(0xFFFFE9F4), Color(0xFFFFC3DF)],
                  ),
                  border: Border.fromBorderSide(
                    BorderSide(color: _Ink.white, width: 2.5),
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFF1C2D8), spreadRadius: 1.5),
                  ],
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: 0.8,
                  child: KabiEmoji(hug, size: 46, animate: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyStrong.copyWith(
                        color: _Ink.ink,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.liveUserFamilyHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.caption.copyWith(
                        color: const Color(0xFF9A7B4A),
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (stacked) ...[const SizedBox(height: 6), pill],
                  ],
                ),
              ),
              if (!stacked) ...[const SizedBox(width: 8), pill],
            ],
          ),
        ),
      ),
    );
  }
}

/// Relationship (CP), not linked: the person's picture, a faint heart and
/// an empty partner slot; "no partner yet" and "soon"; the charm creatures
/// at the end; a bar saying CP gifts are coming.
class _CpCard extends StatelessWidget {
  const new({required this.name, this.avatar, super.key});

  final String name;
  final ImageProvider? avatar;

  static const _outer = Color(0xFFF3E8FF);
  static const _rim = Color(0xFFD4B2FF);
  static const _title = Color(0xFF8B3FD9);
  static const _bar = [Color(0xFFA970F0), Color(0xFFC79BFF)];
  static const _inner = [Color(0xFFFBF6FF), Color(0xFFF6EBFF)];
  static const _picture = 42.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    Widget ring(Widget child, {Color? fill, Color border = _Ink.white}) =>
        Container(
          width: _picture,
          height: _picture,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: border, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40C83C78),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(child: child),
        );
    return _SoonTap(
      label: l10n.liveUserCp,
      child: Container(
        decoration: BoxDecoration(
          color: _outer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _rim, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _rim.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minHeight: 88),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: _inner),
                border: Border.all(color: _rim.withValues(alpha: 0.6)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // The creatures at the end (the design's king art).
                    PositionedDirectional(
                      end: 2,
                      bottom: -6,
                      child: ExcludeSemantics(
                        child: Image.asset(CharmTier.royal.icon, width: 58),
                      ),
                    ),
                    PositionedDirectional(
                      end: 44,
                      bottom: 2,
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: 0.9,
                          child: Image.asset(CharmTier.bunny.icon, width: 30),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      end: 8,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(colors: _bar),
                        ),
                        child: Text(
                          'CP',
                          style: text.caption.copyWith(
                            color: _Ink.white,
                            fontSize: 10,
                            height: 1.3,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        10,
                        74,
                        10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: _picture * 2 + 18,
                            height: _picture + 4,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PositionedDirectional(
                                  start: 0,
                                  child: ring(
                                    KAvatar(
                                      name: name,
                                      image: avatar,
                                      size: _picture,
                                    ),
                                  ),
                                ),
                                PositionedDirectional(
                                  end: 0,
                                  child: Semantics(
                                    label: l10n.liveUserCpPartner,
                                    child: ring(
                                      const Icon(
                                        Icons.add_rounded,
                                        color: _rim,
                                        size: 24,
                                      ),
                                      fill: _Ink.white.withValues(alpha: 0.6),
                                      border: _rim,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 22,
                                  color: Color(0xFFEBA9CB),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.liveUserCpNone,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyStrong.copyWith(
                                    color: _title,
                                    fontSize: 14,
                                    height: 1.25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const _SoonPill(
                                  colors: [
                                    Color(0xFFEBDDFF),
                                    Color(0xFFE3D0FF),
                                  ],
                                  ink: Color(0xFF7B2FD0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: _bar),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Text(
                l10n.liveUserCpBar,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(
                  color: _Ink.white,
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gift wall / medals: the name and "soon" (no counts until they exist),
/// three pictures and a chevron.
class _CollectionRow extends StatelessWidget {
  const new({required this.title, required this.thumbs, super.key});

  final String title;
  final List<String> thumbs;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return _SoonTap(
      label: title,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 8, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F6FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyStrong.copyWith(
                      color: _Ink.ink,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.liveUserSoon,
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
            for (final t in thumbs)
              Container(
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
                child: Opacity(
                  opacity: 0.75,
                  child: Image.asset(t, fit: BoxFit.contain),
                ),
              ),
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
