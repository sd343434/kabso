import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D342 (owner: «ان يكونو بنفس الصف لكن ميز كل واحده بهم»): the three party
/// kinds the party page lists together, each told apart by its own badge.
enum PartyKind {
  audio,
  podcast,
  multi;

  /// The party kind of [room] (`null`: a video live — solo, PK, streamer).
  /// A podcast is a voice room too, so it is checked first.
  static PartyKind? of(LiveRoomCardData room) => room.isPodcast
      ? podcast
      : room.isMulti
      ? multi
      : room.isAudio
      ? audio
      : null;

  /// The short name on the badge.
  String label(AppLocalizations l10n) => switch (this) {
    audio => l10n.livePartyKindAudio,
    podcast => l10n.livePartyKindPodcast,
    multi => l10n.livePartyKindMulti,
  };

  /// The full name a screen reader hears (the card's kind).
  String semanticLabel(AppLocalizations l10n) => switch (this) {
    audio => l10n.liveCategoryAudio,
    podcast => l10n.liveCategoryPodcast,
    multi => l10n.liveCategoryMulti,
  };

  IconData get icon => switch (this) {
    audio => Icons.mic_rounded,
    podcast => Icons.podcasts_rounded,
    multi => Icons.groups_rounded,
  };

  /// The icon's tint on the dark glass, from the design tokens (v1.1,
  /// the dark palette: they are drawn on black): audio `color.dark.info`
  /// blue, podcast `color.brand.gold`, multi `color.dark.success` green.
  Color get tint => switch (this) {
    audio => KPalette.dark.info,
    podcast => KBrandColors.gold,
    multi => KPalette.dark.success,
  };
}

/// D342: a party room's kind on its picture. D342b (owner: «شكل ايقونة
/// صوتي او بودكاست سيء حاول جعلها احترافية واصغر حجماً»): a small dark
/// glass chip instead of a saturated block — black 45 % with a 0.5 lp
/// white 15 % edge, the kind's icon in its colour ([PartyKind.tint]) and a
/// white 10 sp semibold name (≥ 4.5 : 1 on any picture: the glass is at
/// least 45 % black over the card's scrim). 18 lp tall in the list and the
/// grid, at the picture's top start. Decorative: it never grows with the
/// text size and shrinks to fit a narrow cover instead of cutting its
/// name; the card's label carries the kind for screen readers.
class PartyKindBadge extends StatelessWidget {
  const new({required this.kind, super.key});

  final PartyKind kind;

  static Key keyOf(PartyKind kind) => Key('partyKind.${kind.name}');

  /// The chip's height (lp).
  static const double height = 18;

  /// Its glass and edge.
  static const Color glass = Color(0x73000000);
  static const Color edge = Color(0x26FFFFFF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: kind.semanticLabel(l10n),
      excludeSemantics: true,
      child: MediaQuery.withNoTextScaling(
        child: FittedBox(
          key: keyOf(kind),
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: glass,
              borderRadius: BorderRadius.circular(KRadius.pill),
              border: Border.all(color: edge, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(kind.icon, size: 11, color: kind.tint),
                const SizedBox(width: 3),
                Text(
                  kind.label(l10n),
                  maxLines: 1,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
