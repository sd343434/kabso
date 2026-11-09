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

  /// The badge's fill and ink, from the design tokens (v1.1), the same in
  /// both themes (the badge sits on the room's picture): audio
  /// `color.light.info` blue, podcast `color.brand.gold` with
  /// `color.onStatus`, multi `color.light.success` green. Contrast of the
  /// label: 5.8:1, 12.1:1 and 5.4:1.
  (Color fill, Color ink) get colors => switch (this) {
    audio => (KPalette.light.info, KPalette.light.onPrimary),
    podcast => (KBrandColors.gold, KStatusColors.onStatus),
    multi => (KPalette.light.success, KPalette.light.onPrimary),
  };
}

/// D342: a party room's kind on its picture — its icon and short name on
/// its own colour ([PartyKind.colors]). It never grows with the text size
/// (the picture has a fixed size; the card's label carries the kind), and
/// shrinks to fit a narrow cover instead of cutting its name.
class PartyKindBadge extends StatelessWidget {
  const new({required this.kind, super.key});

  final PartyKind kind;

  static Key keyOf(PartyKind kind) => Key('partyKind.${kind.name}');

  /// The badge's height (lp).
  static const double height = 16;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (fill, ink) = kind.colors;
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
            padding: const EdgeInsetsDirectional.only(start: 4, end: 5),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(KRadius.pill),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 3),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(kind.icon, size: 11, color: ink),
                const SizedBox(width: 2),
                Text(
                  kind.label(l10n),
                  maxLines: 1,
                  style: context.textStyles.caption.copyWith(
                    color: ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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
