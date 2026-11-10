import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_live_icon.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
/// PK penalty or video podcast exists on the wire, so the owner's
/// [KabsoLiveType.pkGroup], [KabsoLiveType.pkJudge] and
/// [KabsoLiveType.podcastCam] glyphs are kept but unused).
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

  /// The owner's glyph. A PK uses the compact bolt (the tag already says
  /// «PK»; the P⚡K lettermark at 13 lp would repeat it); a multi-guest live
  /// is a camera live (the owner drew no multi glyph; its tag tells it
  /// apart).
  KabsoLiveType get glyph => switch (this) {
    pk => KabsoLiveType.pkBolt,
    streamer => KabsoLiveType.streamer,
    podcast => KabsoLiveType.podcastVoice,
    audio => KabsoLiveType.voice,
    multi => KabsoLiveType.cam,
    live => KabsoLiveType.cam,
  };

  /// The short tag beside the glyph — the owner's English tags, the same
  /// in both languages (his file: «short English tag shown next to the
  /// small icon»).
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

/// D362: a live card's room type from the outside — the owner's animated
/// white glyph ([KabsoLiveIcon], [iconSize] lp) and its tiny English tag
/// ([fontSize] sp, weight 800), both with a soft shadow so they read on a
/// bright cover. No pill, so it takes almost no room.
///
/// - The pair follows the reading direction (glyph at the start); the
///   glyphs themselves are painted and never mirrored.
/// - Decorative size: it does not grow with the text size and shrinks to
///   fit a narrow card instead of cutting its tag; the card's own label
///   carries the type for screen readers ([LiveCardKind.semanticLabel]).
/// - The glyph loops only while the card is on screen (a visibility check,
///   so a long grid never runs dozens of tickers), never with reduce motion,
///   and its tickers pause with [TickerMode] (a hidden tab).
class LiveTypeTag extends StatefulWidget {
  const new({
    required this.kind,
    super.key,
    this.iconSize = 13,
    this.fontSize = 9.5,
  });

  final LiveCardKind kind;
  final double iconSize;
  final double fontSize;

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
  State<LiveTypeTag> createState() => _LiveTypeTagState();
}

class _LiveTypeTagState extends State<LiveTypeTag> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = widget.kind;
    return Semantics(
      label: kind.semanticLabel(l10n),
      excludeSemantics: true,
      child: VisibilityDetector(
        key: ObjectKey(this),
        onVisibilityChanged: (info) {
          final visible = info.visibleFraction > 0;
          if (mounted && visible != _visible) {
            setState(() => _visible = visible);
          }
        },
        child: MediaQuery.withNoTextScaling(
          child: FittedBox(
            key: LiveTypeTag.keyOf(kind),
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KabsoLiveIcon(
                  type: kind.glyph,
                  size: widget.iconSize,
                  animate: _visible,
                ),
                SizedBox(width: widget.fontSize * .3),
                Text(
                  kind.tag(l10n),
                  key: LiveTypeTag.textKey,
                  maxLines: 1,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 0.1,
                    shadows: LiveTypeTag.shadows,
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
