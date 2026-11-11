import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D342 (owner: «ان يكونو بنفس الصف لكن ميز كل واحده بهم»): the three party
/// kinds the party page lists together, each told apart on its card (D362:
/// by [LiveTypeTag]; D342b's chip `PartyKindBadge` was replaced).
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

  /// The card kind drawn for this party kind.
  LiveCardKind get cardKind => switch (this) {
    audio => LiveCardKind.audio,
    podcast => LiveCardKind.podcast,
    multi => LiveCardKind.multi,
  };
}

/// D362: the room types a hub card can tell apart — only the states the
/// room data really carries (`LiveRoomSummary.mode` and `inPk`; no team PK,
/// PK penalty or video podcast exists on the wire).
enum LiveCardKind {
  /// In a PK now (`inPk`, or the legacy mode PK).
  pk,

  /// STREAMER (D213).
  streamer,

  /// PODCAST (D212, voice only).
  podcast,

  /// AUDIO.
  audio,

  /// MULTI (a multi-guest video live).
  multi,

  /// SOLO (a camera live).
  live;

  /// The kind of [room]. A PK wins on the grid card; the party list passes
  /// `withPk: false` (it shows «PK» in its own pill). A podcast is a voice
  /// room too, so it is checked before audio.
  static LiveCardKind of(LiveRoomCardData room, {bool withPk = true}) =>
      withPk && room.inPk
      ? pk
      : room.isStreamer
      ? streamer
      : room.isPodcast
      ? podcast
      : room.isMulti
      ? multi
      : room.isAudio
      ? audio
      : live;

  /// The short tag beside the live wave — the owner's English tags, the
  /// same in both languages.
  String tag(AppLocalizations l10n) => switch (this) {
    pk => l10n.pkBadge,
    streamer => l10n.liveTypeTagStreamer,
    podcast => l10n.liveTypeTagPodcast,
    audio => l10n.liveTypeTagVoice,
    multi => l10n.liveTypeTagMulti,
    live => l10n.liveTypeTagCam,
  };

  /// The type's full name in the app's language (screen readers).
  String semanticLabel(AppLocalizations l10n) => switch (this) {
    pk => l10n.pkBadge,
    streamer => l10n.liveCardTagStreamer,
    podcast => l10n.liveCategoryPodcast,
    audio => l10n.liveCategoryAudio,
    multi => l10n.liveCategoryMulti,
    live => l10n.liveCategoryLive,
  };
}

/// D362: a live card's room type from the outside — its tiny English tag
/// ([fontSize] sp, weight 800, white) with a soft shadow so it reads on a
/// bright cover, right beside the card's teal live wave. No pill and no
/// glyph (owner 2026-11-10: «لا ازل الايقونات فقط جنبي موجة الكلمة بتصنيف
/// لايف»), so it takes almost no room.
///
/// - Decorative size: it does not grow with the text size and shrinks to
///   fit a narrow card instead of cutting its tag; the card's own label
///   carries the type for screen readers ([LiveCardKind.semanticLabel]).
class LiveTypeTag extends StatelessWidget {
  const new({
    required this.kind,
    super.key,
    this.fontSize = 9.5,
    this.video = false,
  });

  final LiveCardKind kind;
  final double fontSize;

  /// D363 (§10.157): a video podcast — a tiny camera after the tag.
  final bool video;

  static const videoKey = Key('liveTypeTag.video');

  static Key keyOf(LiveCardKind kind) => Key('liveTypeTag.${kind.name}');

  /// Never taller than the cards' 18 lp top row (D342b's chip height), at
  /// any text size.
  static const double maxHeight = 18;

  /// The tag's text.
  static const textKey = Key('liveTypeTag.text');

  /// The soft shadow under the tag's text.
  static const shadows = [
    Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 0.5)),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final videoPodcast = video && kind == LiveCardKind.podcast;
    final tag = Text(
      kind.tag(l10n),
      key: textKey,
      maxLines: 1,
      style: context.textStyles.caption.copyWith(
        color: const Color(0xFFFFFFFF),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0.1,
        shadows: shadows,
      ),
    );
    return Semantics(
      label: videoPodcast
          ? '${kind.semanticLabel(l10n)} · ${l10n.podcastVideoBadge}'
          : kind.semanticLabel(l10n),
      excludeSemantics: true,
      child: MediaQuery.withNoTextScaling(
        child: FittedBox(
          key: keyOf(kind),
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: !videoPodcast
              ? tag
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    tag,
                    const SizedBox(width: 2),
                    Icon(
                      Icons.videocam_rounded,
                      key: videoKey,
                      size: fontSize + 2,
                      color: const Color(0xFFFFFFFF),
                      shadows: shadows,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
