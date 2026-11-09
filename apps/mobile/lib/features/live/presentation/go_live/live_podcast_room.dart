import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D212 (owner-approved mockup «بث البودكاست بعناصر كابسو», built on the audio
/// room's own golden): the podcast live — the audio room's background,
/// header, chips, chat and bar, with an episode card, one row of four
/// bigger speaker seats in the audio seats' style and one scrolling row of
/// listeners (raised hands first). Measured from the mockup's source
/// (logical px = dp at 393 × 852); values marked E are estimates.
abstract final class KPodcast {
  /// The stage's own inset (the room's scroll view adds 4 dp a side).
  static const double inset = 10;

  /// Episode card: 14 dp from the screen edges, a 16 dp corner, 9 × 12 dp
  /// padding, `rgba(20,14,40,.38)`.
  static const Color card = Color(0x61140E28);
  static const double cardRadius = 16;
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 9,
  );
  static const double metaSize = 10.5;
  static const double titleSize = 14.5;

  /// The «● مباشر» tag (brand red, 6 dp corner).
  static const Color liveTag = Color(0xFFE50914);
  static const Color topicChip = Color(0x29FFFFFF);
  static const Color soft = Color(0xBFFFFFFF);

  /// Card top → speakers top (148 → 238 in the mockup).
  static const double speakersTop = 90;

  /// Speaker seats: 66 dp circles, four equal columns.
  static const double speaker = 66;
  static const Color seatFill = Color(0xFF35343F);
  static const Color hostTag = Color(0xFF19C2A0);
  static const double hostTagSize = 8.5;

  /// The mic badge: 20 dp at the seat's top start corner, 1.5 dp ring.
  static const double micBadge = 20;

  /// The speaking ring: 3 dp gold with a soft gold glow.
  static const Color speakingRing = Color(0xFFFFC83D);
  static const Color speakingGlow = Color(0x8CFFC83D);
  static const Color mutedSlash = Color(0xFFFF3B47);
  static const double nameSize = 12;

  /// Pills under a speaker (cherries or the question timer): the mockup's
  /// `rgb(20,14,40)` at 60 % (it drew 45 %: white text then fell to 4.0 : 1
  /// over the majlis background's brightest lantern; at 60 % it is ≥ 6.2 : 1
  /// on every podcast theme), 1 × 8 dp, white 10 sp semibold Inter digits.
  static const Color pill = Color(0x99140E28);

  /// The host tag's dark outline (owner: no colour change): the green tag
  /// fell under 3 : 1 against bright theme areas (majlis lanterns).
  static const Color hostTagOutline = Color(0xD90A0418);
  static const double pillText = 10;

  /// Speakers top → listeners label (238 → 372).
  static const double listenersTop = 134;
  static const double labelSize = 11;

  /// Listener circles: 46 dp, a 1.5 dp white ring, 12 dp apart.
  static const double listener = 46;
  static const double listenerGap = 12;
  static const double listenerName = 10.5;

  /// The ✋ badge on a raised hand: 20 dp, brand red, a white ring, 6 dp
  /// outside the circle's top start corner. The row keeps [badgeRoom] above
  /// the circles so the badge is never clipped (owner feedback).
  static const double handBadge = 20;
  static const double badgeRoom = 8;

  /// Chat lines of a podcast (inline rows in the mockup's see-through
  /// bubble).
  static const Color chatBubble = Color(0x73140E28);
}

/// Topic chip text.
String podcastTopicLabel(AppLocalizations l10n, PodcastTopic topic) =>
    switch (topic) {
      PodcastTopic.business => l10n.podcastTopicBusiness,
      PodcastTopic.tech => l10n.podcastTopicTech,
      PodcastTopic.sports => l10n.podcastTopicSports,
      PodcastTopic.religion => l10n.podcastTopicReligion,
      PodcastTopic.society => l10n.podcastTopicSociety,
      PodcastTopic.entertainment => l10n.podcastTopicEntertainment,
      PodcastTopic.other => l10n.podcastTopicOther,
    };

/// m:ss (h:mm:ss past an hour), Latin digits (KFormat, DESIGN_SYSTEM §3.3).
String podcastClock(Duration d) => KFormat.countdown(d);

TextStyle _digits(BuildContext context, double size, {Color? color}) =>
    context.textStyles.caption.copyWith(
      fontFamily: KFonts.latin,
      fontSize: size,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: color ?? KAudioRoom.text,
    );

/// A ticking clock for the timers (one per stage; none with
/// [TickerMode] off, e.g. in goldens the frame is fixed by `clock`).
class _Tick extends StatefulWidget {
  const new({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The episode card: «● مباشر», the topic chip, «الحلقة N», the elapsed
/// time at the end, then the title.
class PodcastEpisodeCard extends StatelessWidget {
  const new({
    required this.title,
    required this.podcast,
    required this.startedAt,
    super.key,
  });

  final String title;
  final LivePodcast podcast;
  final DateTime startedAt;

  static const cardKey = Key('podcast.episode');
  static const timerKey = Key('podcast.episode.timer');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meta = context.textStyles.caption.copyWith(
      fontSize: KPodcast.metaSize,
      height: 1.3,
      color: KPodcast.soft,
    );
    Widget chip(String text, Color fill, {bool bold = false}) => Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: meta.copyWith(
          color: bold ? KAudioRoom.text : KPodcast.soft,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
    return Container(
      key: cardKey,
      padding: KPodcast.cardPadding,
      decoration: BoxDecoration(
        color: KPodcast.card,
        borderRadius: BorderRadius.circular(KPodcast.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              chip('● ${l10n.podcastLiveTag}', KPodcast.liveTag, bold: true),
              const SizedBox(width: 6),
              Flexible(
                child: chip(
                  podcastTopicLabel(l10n, podcast.topic),
                  KPodcast.topicChip,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.podcastEpisode(podcast.episodeNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 6),
              _Tick(
                builder: (context) => Text(
                  podcastClock(clock.now().difference(startedAt)),
                  key: timerKey,
                  style: _digits(context, KPodcast.metaSize),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodyStrong.copyWith(
              fontSize: KPodcast.titleSize,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: KAudioRoom.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// One speaker place of the row (the host is the first).
@immutable
class PodcastSpeakerData {
  const new({
    required this.name,
    this.userId,
    this.avatarUrl,
    this.points = 0,
    this.host = false,
    this.muted = false,
    this.speaking = false,
    this.demoteAt,
    this.seatIndex,
    this.onTap,
    this.overlay,
  });

  /// An empty speaker seat ([seatIndex] 1–3).
  const new empty(int this.seatIndex, {this.onTap})
    : overlay = null,
      name = '',
      userId = null,
      avatarUrl = null,
      points = 0,
      host = false,
      muted = false,
      speaking = false,
      demoteAt = null;

  final String name;
  final String? userId;
  final String? avatarUrl;
  final int points;
  final bool host;
  final bool muted;

  /// LiveKit's active speaker: the gold glowing ring.
  final bool speaking;

  /// A question's end (the pill counts down to it); null = cherries.
  final DateTime? demoteAt;

  /// 1–3 (null for the host's place).
  final int? seatIndex;
  final VoidCallback? onTap;

  /// D225: what plays over the picture now — an emoji played on this seat
  /// («إيموجي على مقعدي», D138); null: nothing.
  final Widget? overlay;

  bool get isEmpty => userId == null && !host;
}

/// The row of four speaker seats (the host and up to 3).
class PodcastSpeakers extends StatelessWidget {
  const new({required this.speakers, super.key});

  final List<PodcastSpeakerData> speakers;

  static Key seatKey(int place) => Key('podcast.speaker.$place');
  static const ringKey = Key('podcast.speaker.speaking');
  static const hostTagKey = Key('podcast.speaker.hostTag');
  static const questionKey = Key('podcast.speaker.question');

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, s) in speakers.indexed)
        Expanded(
          child: _Speaker(key: seatKey(i), data: s),
        ),
    ],
  );
}

class _Speaker extends StatelessWidget {
  const new({required this.data, super.key});

  final PodcastSpeakerData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = data;
    if (d.isEmpty) {
      return Semantics(
        button: d.onTap != null,
        label: l10n.liveSeatNumberLabel(d.seatIndex ?? 0),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: d.onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: KPodcast.speaker,
                height: KPodcast.speaker,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x8C2A2140),
                  border: Border.all(
                    color: const Color(0xD9FFFFFF),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  color: Color(0xD9FFFFFF),
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final circle = ClipOval(
      child: SizedBox.square(
        dimension: KPodcast.speaker,
        child: PodcastAvatar(
          name: d.name,
          url: d.avatarUrl,
          size: KPodcast.speaker,
        ),
      ),
    );
    final demoteAt = d.demoteAt;
    final labelParts = [
      d.name,
      if (d.host) l10n.goLiveHostTag,
      if (d.speaking) l10n.podcastSpeaking,
      if (d.muted) l10n.podcastMuted,
    ];
    return Semantics(
      button: d.onTap != null,
      label: labelParts.join(' · '),
      excludeSemantics: demoteAt == null,
      child: GestureDetector(
        onTap: d.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: KPodcast.speaker,
              height: KPodcast.speaker,
              child: Stack(
                // The ring, the host tag and the mic badge stand outside
                // the circle: never clipped (owner).
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      key: d.speaking ? PodcastSpeakers.ringKey : null,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: d.speaking
                            ? const [
                                BoxShadow(
                                  color: KPodcast.speakingRing,
                                  spreadRadius: 3,
                                ),
                                BoxShadow(
                                  color: KPodcast.speakingGlow,
                                  blurRadius: 18,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: circle,
                    ),
                  ),
                  if (d.host)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Center(
                        child: Container(
                          key: PodcastSpeakers.hostTagKey,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: KPodcast.hostTag,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: KPodcast.hostTagOutline),
                          ),
                          child: Text(
                            l10n.goLiveHostTag,
                            maxLines: 1,
                            style: context.textStyles.caption.copyWith(
                              fontSize: KPodcast.hostTagSize,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: KAudioRoom.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (d.overlay case final overlay?)
                    Positioned.fill(child: IgnorePointer(child: overlay)),
                  PositionedDirectional(
                    top: -2,
                    start: -2,
                    child: _MicBadge(muted: d.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  fontSize: KPodcast.nameSize,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: KAudioRoom.text,
                  shadows: const [
                    Shadow(color: Color(0xCC000000), blurRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (demoteAt != null)
              _Tick(
                builder: (context) => PodcastQuestionPill(
                  key: PodcastSpeakers.questionKey,
                  left: demoteAt.difference(clock.now()),
                ),
              )
            else
              _CherryPill(points: d.points, cherries: d.host),
          ],
        ),
      ),
    );
  }
}

/// A speaker's received points (the audio seats' points pill style); D259:
/// the host's tile shows their real cherries with the cherry, a speaker's
/// points the points mark.
class _CherryPill extends StatelessWidget {
  const new({required this.points, this.cherries = false});

  final int points;

  /// [points] are the host's real cherries (D259).
  final bool cherries;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      color: KPodcast.pill,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              KFormat.grouped(points),
              maxLines: 1,
              style: _digits(context, KPodcast.pillText),
            ),
          ),
        ),
        const SizedBox(width: 3),
        if (cherries)
          const KCherryIcon(size: 11)
        else
          const KPointsIcon(size: 11),
      ],
    ),
  );
}

/// Owner feedback: the question timer as a pill in the cherry pill's style
/// — a small red circle with a white ✋ at the start, then «سؤال · m:ss» in
/// white semibold (white on the pill over the darkest theme pixel stays
/// ≥ 4.5 : 1; checked by the D212 contrast test).
class PodcastQuestionPill extends StatelessWidget {
  const new({required this.left, super.key});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = podcastClock(left);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 1, 8, 1),
      decoration: BoxDecoration(
        color: KPodcast.pill,
        borderRadius: BorderRadius.circular(KRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: KPodcast.liveTag,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.front_hand_rounded,
              size: 9,
              color: KAudioRoom.text,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [TextSpan(text: l10n.podcastQuestionPill(time))],
                ),
                maxLines: 1,
                style: context.textStyles.caption.copyWith(
                  fontSize: KPodcast.pillText,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: KAudioRoom.text,
                  fontFamilyFallback: const [KFonts.latin],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicBadge extends StatelessWidget {
  const new({required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    width: KPodcast.micBadge,
    height: KPodcast.micBadge,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: KPodcast.seatFill,
      border: Border.all(color: const Color(0x80FFFFFF), width: 1.5),
    ),
    child: Icon(
      muted ? Icons.mic_off_rounded : Icons.mic_rounded,
      size: 11,
      color: muted ? KPodcast.mutedSlash : KAudioRoom.text,
    ),
  );
}

/// A round picture, or (D337) the owner's default picture — it replaced
/// the mockup's initial on the dark seat colour.
class PodcastAvatar extends StatelessWidget {
  const new({required this.name, required this.size, super.key, this.url});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    // D337: no photo (or a broken one) → the owner's default picture.
    final fallback = ClipOval(child: KDefaultAvatarImage(size: size));
    final u = url;
    if (u == null || u.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// One listener of the row.
@immutable
class PodcastListenerData {
  const new({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.handUp = false,
    this.onTap,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final bool handUp;
  final VoidCallback? onTap;
}

/// Puts raised hands first (in [handsUp] order), then the others as they
/// came.
List<PodcastListenerData> podcastListenerOrder(
  List<PodcastListenerData> listeners,
  List<String> handsUp,
) {
  final rank = {for (final (i, id) in handsUp.indexed) id: i};
  final up = [
    for (final l in listeners)
      if (rank.containsKey(l.userId)) l,
  ]..sort((a, b) => rank[a.userId]!.compareTo(rank[b.userId]!));
  return [
    for (final l in up)
      PodcastListenerData(
        userId: l.userId,
        name: l.name,
        avatarUrl: l.avatarUrl,
        handUp: true,
        onTap: l.onTap,
      ),
    for (final l in listeners)
      if (!rank.containsKey(l.userId)) l,
  ];
}

/// «المستمعون · N» and «عرض الكل ‹», then one horizontally scrolling row.
class PodcastListeners extends StatelessWidget {
  const new({
    required this.listeners,
    required this.count,
    super.key,
    this.onSeeAll,
  });

  final List<PodcastListenerData> listeners;

  /// The room's viewer count (the row shows the first page).
  final int count;
  final VoidCallback? onSeeAll;

  static const rowKey = Key('podcast.listeners');
  static const seeAllKey = Key('podcast.listeners.all');
  static Key listenerKey(String id) => Key('podcast.listener.$id');
  static Key handKey(String id) => Key('podcast.listener.$id.hand');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = context.textStyles.caption.copyWith(
      fontSize: KPodcast.labelSize,
      height: 1.3,
      color: const Color(0xB3FFFFFF),
    );
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final nameHeight = scaler.scale(KPodcast.listenerName) * 1.3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.podcastListeners(KFormat.compact(count, l10n)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label,
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  key: seeAllKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onSeeAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 16),
                    child: Center(
                      child: Text(l10n.podcastSeeAll, style: label),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          // The badge room above the circles keeps the ✋ whole (owner).
          height: KPodcast.badgeRoom + KPodcast.listener + 3 + nameHeight + 2,
          child: ListView.separated(
            key: rowKey,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(
              start: KPodcast.inset,
              end: KPodcast.inset,
              top: KPodcast.badgeRoom,
            ),
            itemCount: listeners.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: KPodcast.listenerGap),
            itemBuilder: (context, i) => _Listener(data: listeners[i]),
          ),
        ),
      ],
    );
  }
}

class _Listener extends StatelessWidget {
  const new({required this.data});

  final PodcastListenerData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = data;
    return Semantics(
      button: d.onTap != null,
      label: d.handUp ? '${d.name} · ✋' : d.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: PodcastListeners.listenerKey(d.userId),
        onTap: d.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: KPodcast.listener,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: KPodcast.listener,
                height: KPodcast.listener,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xBFFFFFFF),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: PodcastAvatar(
                            name: d.name,
                            url: d.avatarUrl,
                            size: KPodcast.listener - 3,
                          ),
                        ),
                      ),
                    ),
                    if (d.handUp)
                      PositionedDirectional(
                        top: -6,
                        start: -6,
                        child: Container(
                          key: PodcastListeners.handKey(d.userId),
                          width: KPodcast.handBadge,
                          height: KPodcast.handBadge,
                          decoration: BoxDecoration(
                            color: KPodcast.liveTag,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFFFFF),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.front_hand_rounded,
                            size: 11,
                            color: KAudioRoom.text,
                            semanticLabel: l10n.podcastHandUp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  fontSize: KPodcast.listenerName,
                  height: 1.3,
                  color: KAudioRoom.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The podcast's stage in the audio room layout's stage slot: the episode
/// card, the speakers 90 dp under its top, the listeners 134 dp under the
/// speakers (mockup).
class PodcastStage extends StatelessWidget {
  const new({
    required this.title,
    required this.podcast,
    required this.startedAt,
    required this.speakers,
    required this.listeners,
    required this.listenerCount,
    super.key,
    this.onSeeAll,
  });

  final String title;
  final LivePodcast podcast;
  final DateTime startedAt;
  final List<PodcastSpeakerData> speakers;
  final List<PodcastListenerData> listeners;
  final int listenerCount;
  final VoidCallback? onSeeAll;

  static const stageKey = Key('podcast.stage');

  @override
  Widget build(BuildContext context) => Column(
    key: stageKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: KPodcast.inset),
        child: PodcastEpisodeCard(
          title: title,
          podcast: podcast,
          startedAt: startedAt,
        ),
      ),
      const _AtLeast(height: KPodcast.speakersTop, child: SizedBox.shrink()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: PodcastSpeakers(speakers: speakers),
      ),
      // Speakers' pills → the listeners label (mockup: 372 − 238 − 118).
      const SizedBox(height: 24),
      PodcastListeners(
        listeners: listeners,
        count: listenerCount,
        onSeeAll: onSeeAll,
      ),
    ],
  );
}

/// The gap between the card's top and the speakers: [height] from the
/// card's top in the mockup, but never less than 26 dp after a taller card
/// (two title lines, large text).
class _AtLeast extends StatelessWidget {
  const new({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    // The one-line card is ≈ 56 dp tall at 1.0 (9 + 14 + 4 + 20 + 9).
    final card =
        9 +
        scaler.scale(KPodcast.metaSize) * 1.3 +
        4 +
        scaler.scale(KPodcast.titleSize) * 1.4 +
        9 +
        2;
    return SizedBox(height: math.max(26, height - card));
  }
}

/// The red ✋ in the bottom bar, the size of the other bar buttons (it
/// takes the ∞ button's place in podcasts only). [raised]: this person's
/// hand is up (a white ring); [badge]: the host's count of hands.
class PodcastHandButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onTap,
    super.key,
    this.raised = false,
    this.badge = 0,
  });

  final String label;
  final VoidCallback? onTap;
  final bool raised;
  final int badge;

  static const buttonKey = Key('podcast.hand');

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: raised,
    label: badge > 0 ? '$label · $badge' : label,
    excludeSemantics: true,
    child: GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: KAudioRoom.barTarget,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: KAudioRoom.barButton,
                height: KAudioRoom.barButton,
                decoration: BoxDecoration(
                  color: KPodcast.liveTag,
                  shape: BoxShape.circle,
                  border: raised
                      ? Border.all(color: const Color(0xFFFFFFFF), width: 2)
                      : null,
                ),
                child: const Icon(
                  Icons.front_hand_rounded,
                  color: Color(0xFFFFFFFF),
                  size: 22,
                ),
              ),
              if (badge > 0)
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: _digits(context, 11, color: KPodcast.liveTag),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
