import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_podcast_video.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_studio.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D363 (owner-approved mockup «بودكاست فيديو», CONVENTIONS §10.157): the
/// video podcast's full-screen vertical stage. It is the `video` layer of
/// the live room scaffold — the live's own chrome (host pill and follow,
/// ranking chips, chat, gift banners, bottom bar) stays above it, as in
/// every video live. What it draws: the director's shot (speaker, split,
/// grid, hot seat) with a cross-fade, the side thumbnails (at the reading
/// end, so mirrored in RTL), each person's name tag with the speaking wave,
/// the guest's lower third, the shot chip and «رجوع للمخرج».
abstract final class KVideoPodcast {
  /// The thumbnails: 76 × 112 dp (vertical, 2 : 3 like the full frame), 8 dp
  /// apart, 12 dp from the edge, a 12 dp corner.
  static const Size thumb = Size(76, 112);
  static const double thumbGap = KSpacing.sm;
  static const double edge = KSpacing.md;

  /// Below the host pill and the chips row of the video chrome.
  static const double chromeTop = 112;

  /// The gap between the frames of a split or a grid.
  static const double seam = 2;

  /// The speaking ring of a thumbnail (the podcast's gold).
  static const Color speaking = KPodcast.speakingRing;

  /// A frame without video: a deep neutral (never a person's picture).
  static const List<Color> emptyFrame = [Color(0xFF2A2833), Color(0xFF15141B)];

  /// The lower third stays this long after a guest appears.
  static const Duration lowerThird = Duration(seconds: 4);

  /// The hot seat card: 16 dp corner, a red tag.
  static const Color hotTag = KBrandColors.red500;
  static const double askerBubble = 56;
}

/// A person on the video podcast's stage.
@immutable
class VideoPodcastPerson {
  const new({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.host = false,
    this.speaking = false,
    this.muted = false,
    this.guestTitle,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final bool host;
  final bool speaking;
  final bool muted;

  /// The title the host gave when inviting (the lower third).
  final String? guestTitle;
}

/// The hot seat: the asker's question card.
@immutable
class VideoPodcastHotSeat {
  const new({
    required this.askerId,
    required this.question,
    required this.votes,
    this.endsAt,
    this.seconds = 60,
  });

  final String askerId;
  final String question;
  final int votes;

  /// When the asker goes back to the listeners (`LiveSeat.demoteAt`).
  final DateTime? endsAt;

  /// The hot seat's full time (the circular timer's 100 %).
  final int seconds;
}

/// The video of [userId], or null (no track yet, the camera off): the
/// frame then shows the person's picture on a neutral background.
typedef VideoPodcastVideoOf = Widget? Function(String userId);

class VideoPodcastStage extends StatefulWidget {
  const new({
    required this.shot,
    required this.people,
    required this.videoOf,
    super.key,
    this.free = false,
    this.onThumbTap,
    this.onBackToDirector,
    this.hotSeat,
    this.studio,
    this.onAuto,
    this.onNextSegment,
    this.onHideQuestion,
    this.backstage = const [],
    this.onBringOnAir,
  });

  static const shotChipKey = Key('video-podcast-shot-chip');
  static const backToDirectorKey = Key('video-podcast-back-to-director');
  static const lowerThirdKey = Key('video-podcast-lower-third');
  static const hotSeatKey = Key('video-podcast-hot-seat');
  static Key thumbKey(String userId) => Key('video-podcast-thumb-$userId');
  static Key frameKey(String userId) => Key('video-podcast-frame-$userId');

  /// The shot to draw (the director's, or the viewer's own pick).
  final PodcastDirectorShot shot;

  /// Everyone on stage by user id (the host and the seated speakers).
  final Map<String, VideoPodcastPerson> people;
  final VideoPodcastVideoOf videoOf;

  /// The viewer watches someone of their choice («رجوع للمخرج» shows).
  final bool free;
  final ValueChanged<String>? onThumbTap;
  final VoidCallback? onBackToDirector;
  final VideoPodcastHotSeat? hotSeat;

  /// D363 scope extension: the studio (manual control, segments, the
  /// question on screen); null = none (an older server).
  final LivePodcastStudio? studio;

  /// The host's «تلقائي» (null: not the host — the chip only).
  final VoidCallback? onAuto;

  /// The host's «الفقرة التالية» (null: not the host).
  final VoidCallback? onNextSegment;

  /// The host's ✕ on the question card (null: not the host).
  final VoidCallback? onHideQuestion;

  /// The host's backstage strip (empty for everyone else).
  final List<VideoPodcastBackstageGuest> backstage;
  final ValueChanged<VideoPodcastBackstageGuest>? onBringOnAir;

  @override
  State<VideoPodcastStage> createState() => _VideoPodcastStageState();
}

class _VideoPodcastStageState extends State<VideoPodcastStage> {
  /// Guests already introduced (the lower third shows once per switch).
  String? _lowerThird;
  Timer? _lowerThirdTimer;

  @override
  void initState() {
    super.initState();
    _introduce(widget.shot.main);
  }

  @override
  void didUpdateWidget(VideoPodcastStage old) {
    super.didUpdateWidget(old);
    if (old.shot.main != widget.shot.main) _introduce(widget.shot.main);
  }

  /// A guest who becomes the main picture gets the lower third.
  void _introduce(String? id) {
    final person = id == null ? null : widget.people[id];
    _lowerThirdTimer?.cancel();
    if (person == null || person.host) {
      _lowerThird = null;
      return;
    }
    _lowerThird = id;
    _lowerThirdTimer = Timer(KVideoPodcast.lowerThird, () {
      if (mounted) setState(() => _lowerThird = null);
    });
  }

  @override
  void dispose() {
    _lowerThirdTimer?.cancel();
    super.dispose();
  }

  VideoPodcastPerson? _person(String id) => widget.people[id];

  @override
  Widget build(BuildContext context) {
    final shot = widget.shot;
    final ids = [
      for (final id in shot.userIds)
        if (widget.people.containsKey(id)) id,
    ];
    final padding = MediaQuery.paddingOf(context);
    final main = ids.firstOrNull;
    final thumbs = switch (shot.kind) {
      PodcastShotKind.speaker || PodcastShotKind.hotSeat => ids.skip(1),
      PodcastShotKind.split => ids.skip(2),
      PodcastShotKind.grid => const <String>[],
    }.toList();
    final lowerThird = _lowerThird == null ? null : _person(_lowerThird!);
    final studio = widget.studio;
    final now = clock.now();
    final cards = <Widget>[
      if (widget.hotSeat case final hot?
          when shot.kind == PodcastShotKind.hotSeat &&
              _person(hot.askerId) != null)
        _HotSeatCard(
          key: VideoPodcastStage.hotSeatKey,
          hot: hot,
          asker: _person(hot.askerId)!,
        ),
      if (studio?.onScreen case final question?)
        VideoPodcastQuestionCard(
          key: VideoPodcastStudioKeys.questionCard,
          question: question,
          onHide: widget.onHideQuestion,
        ),
      if (studio != null && studio.closing)
        const VideoPodcastClosingCard(key: VideoPodcastStudioKeys.closingCard)
      else if (studio != null && VideoPodcastSegmentCard.shows(studio, now))
        VideoPodcastSegmentCard(
          key: VideoPodcastStudioKeys.segmentCard,
          studio: studio,
        ),
      if (lowerThird != null &&
          main == lowerThird.userId &&
          shot.kind == PodcastShotKind.speaker)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _LowerThird(
            key: VideoPodcastStage.lowerThirdKey,
            person: lowerThird,
          ),
        ),
      if (widget.backstage.isNotEmpty)
        VideoPodcastBackstageStrip(
          guests: widget.backstage,
          videoOf: widget.videoOf,
          onAir: widget.onBringOnAir,
        ),
    ];
    return ColoredBox(
      color: KVideoPodcast.emptyFrame.last,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: KMotion.of(context, KMotion.slow),
            switchInCurve: KMotion.standard,
            switchOutCurve: KMotion.standard,
            child: KeyedSubtree(
              key: ValueKey('${shot.kind.name}:${ids.take(4).join(',')}'),
              child: _layout(shot.kind, ids),
            ),
          ),
          if (thumbs.isNotEmpty)
            PositionedDirectional(
              end: KVideoPodcast.edge,
              top: padding.top + KVideoPodcast.chromeTop + 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final id in thumbs) ...[
                    _Thumb(
                      key: VideoPodcastStage.thumbKey(id),
                      person: _person(id)!,
                      video: widget.videoOf(id),
                      onTap: widget.onThumbTap == null
                          ? null
                          : () => widget.onThumbTap!(id),
                    ),
                    const SizedBox(height: KVideoPodcast.thumbGap),
                  ],
                ],
              ),
            ),
          PositionedDirectional(
            start: KVideoPodcast.edge,
            end: KVideoPodcast.edge,
            top: padding.top + KVideoPodcast.chromeTop,
            child: Wrap(
              spacing: KSpacing.xs,
              runSpacing: KSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ShotChip(key: VideoPodcastStage.shotChipKey, kind: shot.kind),
                if (widget.free && widget.onBackToDirector != null)
                  _BackToDirector(onTap: widget.onBackToDirector!),
                if (studio != null && !studio.automatic)
                  VideoPodcastControlChip(
                    studio: studio,
                    nameOf: (id) => _person(id)?.name,
                    onAuto: widget.onAuto,
                  ),
                if (studio != null &&
                    widget.onNextSegment != null &&
                    studio.segments.isNotEmpty &&
                    !studio.closing)
                  VideoPodcastNextSegment(
                    started: studio.segmentIndex != null,
                    onTap: widget.onNextSegment!,
                  ),
              ],
            ),
          ),
          if (studio != null && studio.segments.isNotEmpty)
            PositionedDirectional(
              start: KVideoPodcast.edge,
              end: KVideoPodcast.edge,
              top: padding.top + KVideoPodcast.chromeTop - 10,
              child: VideoPodcastSegmentsBar(
                key: VideoPodcastStudioKeys.progress,
                studio: studio,
              ),
            ),
          if (cards.isNotEmpty)
            // Beside the thumbnails, never over them; one under the other.
            PositionedDirectional(
              start: KVideoPodcast.edge,
              end: thumbs.isEmpty
                  ? KVideoPodcast.edge
                  : KVideoPodcast.edge + KVideoPodcast.thumb.width + 8,
              top: padding.top + KVideoPodcast.chromeTop + 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, card) in cards.indexed) ...[
                    if (i > 0) const SizedBox(height: KSpacing.sm),
                    card,
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _layout(PodcastShotKind kind, List<String> ids) {
    if (ids.isEmpty) return const SizedBox.expand();
    Widget frame(String id, {bool big = true, bool tagTop = false}) => _Frame(
      key: VideoPodcastStage.frameKey(id),
      person: _person(id)!,
      video: widget.videoOf(id),
      big: big,
      tagTop: tagTop,
    );
    switch (kind) {
      case PodcastShotKind.split when ids.length >= 2:
        return Column(
          children: [
            // The tags meet at the seam: the lower one stays clear of the
            // chat at the bottom.
            Expanded(child: frame(ids[0], big: false)),
            const SizedBox(height: KVideoPodcast.seam),
            Expanded(child: frame(ids[1], big: false, tagTop: true)),
          ],
        );
      case PodcastShotKind.grid when ids.length >= 3:
        final rows = <List<String>>[
          for (var i = 0; i < ids.length; i += 2)
            ids.sublist(i, math.min(i + 2, ids.length)),
        ];
        return Column(
          children: [
            for (final (r, row) in rows.indexed) ...[
              if (r > 0) const SizedBox(height: KVideoPodcast.seam),
              Expanded(
                child: Row(
                  children: [
                    for (final (c, id) in row.indexed) ...[
                      if (c > 0) const SizedBox(width: KVideoPodcast.seam),
                      Expanded(child: frame(id, big: false)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      case PodcastShotKind.hotSeat:
        // The host's (or the main guest's) picture behind the card; the
        // asker is the card's bubble (audio, the camera off by default).
        final behind = ids.length > 1 ? ids[1] : ids[0];
        return frame(behind);
      case PodcastShotKind.speaker ||
          PodcastShotKind.split ||
          PodcastShotKind.grid:
        return frame(ids.first);
    }
  }
}

/// One person's picture: the video, else their avatar on a neutral frame;
/// the name tag with the speaking wave at the bottom start.
class _Frame extends StatelessWidget {
  const new({
    required this.person,
    required this.video,
    required this.big,
    super.key,
    this.tagTop = false,
  });

  final VideoPodcastPerson person;
  final Widget? video;
  final bool big;

  /// The tag at the frame's top start (a split's lower frame).
  final bool tagTop;

  @override
  Widget build(BuildContext context) {
    final bottom = big ? 0.42 : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        video ?? _NoVideo(person: person, size: big ? 112 : 64),
        // A soft shade under the tag so white text reads on any picture.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x00000000), Color(0x59000000)],
            ),
          ),
        ),
        if (!big)
          PositionedDirectional(
            start: KSpacing.sm,
            top: tagTop ? KSpacing.sm : null,
            bottom: tagTop ? null : KSpacing.sm,
            end: KSpacing.sm,
            child: Align(
              alignment: tagTop
                  ? AlignmentDirectional.topStart
                  : AlignmentDirectional.bottomStart,
              child: _NameTag(person: person, compact: !tagTop),
            ),
          )
        else
          // A full frame's tag sits above the chat (the chrome's lower part).
          Align(
            alignment: AlignmentDirectional(-1, 1 - 2 * bottom),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: KVideoPodcast.edge,
              ),
              child: _NameTag(person: person),
            ),
          ),
      ],
    );
  }
}

class _NoVideo extends StatelessWidget {
  const new({required this.person, required this.size});

  final VideoPodcastPerson person;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: KVideoPodcast.emptyFrame,
      ),
    ),
    child: Center(
      child: PodcastAvatar(
        name: person.name,
        size: size,
        url: person.avatarUrl,
      ),
    ),
  );
}

/// The name tag: a glass pill, the speaking wave (or a muted mic), the name.
class _NameTag extends StatelessWidget {
  const new({required this.person, this.compact = false});

  final VideoPodcastPerson person;

  /// A thumbnail's tag: the name before the host's mark.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: person.speaking ? '${person.name}، ${l10n.podcastSpeaking}' : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KLiveColors.glass,
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person.muted)
                const Icon(
                  Icons.mic_off_rounded,
                  size: 12,
                  color: KBrandColors.red400,
                )
              // A thumbnail keeps its room for the name: the wave only
              // while the person speaks.
              else if (!compact || person.speaking)
                VideoPodcastWave(on: person.speaking),
              if (person.muted || !compact || person.speaking)
                const SizedBox(width: KSpacing.xs),
              Flexible(
                child: Text(
                  person.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: KLiveColors.glassShadow,
                  ),
                ),
              ),
              if (person.host && !compact) ...[
                const SizedBox(width: KSpacing.xs),
                const Icon(
                  Icons.mic_external_on_rounded,
                  size: 11,
                  color: KPodcast.hostTag,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Three bars that move while the person speaks (still bars otherwise, and
/// with animations off — goldens and «reduce motion»).
class VideoPodcastWave extends StatefulWidget {
  const new({required this.on, super.key});

  final bool on;

  @override
  State<VideoPodcastWave> createState() => _VideoPodcastWaveState();
}

class _VideoPodcastWaveState extends State<VideoPodcastWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VideoPodcastWave old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate =
        widget.on &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 2.5,
            height: widget.on
                ? 4 +
                      6 *
                          (0.5 +
                              0.5 * math.sin((_c.value + i / 3) * 2 * math.pi))
                : 3,
            margin: const EdgeInsets.symmetric(horizontal: 0.75),
            decoration: BoxDecoration(
              color: widget.on ? KVideoPodcast.speaking : Colors.white70,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

class _Thumb extends StatelessWidget {
  const new({required this.person, required this.video, super.key, this.onTap});

  final VideoPodcastPerson person;
  final Widget? video;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: person.name,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: KVideoPodcast.thumb.width,
        height: KVideoPodcast.thumb.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: person.speaking ? KVideoPodcast.speaking : Colors.white24,
            width: person.speaking ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KRadius.md - 1),
          child: _Frame(person: person, video: video, big: false),
        ),
      ),
    ),
  );
}

class _ShotChip extends StatelessWidget {
  const new({required this.kind, super.key});

  final PodcastShotKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (kind) {
      PodcastShotKind.speaker => l10n.podcastShotSpeaker,
      PodcastShotKind.split => l10n.podcastShotSplit,
      PodcastShotKind.grid => l10n.podcastShotGrid,
      PodcastShotKind.hotSeat => l10n.podcastShotHotSeat,
    };
    return VideoPodcastGlassChip(
      icon: Icons.movie_creation_outlined,
      label: label,
    );
  }
}

class _BackToDirector extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      key: VideoPodcastStage.backToDirectorKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: VideoPodcastGlassChip(
          icon: Icons.undo_rounded,
          label: context.l10n.podcastBackToDirector,
          accent: true,
        ),
      ),
    ),
  );
}

class VideoPodcastGlassChip extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent ? KBrandColors.red500 : KLiveColors.glass,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: KSpacing.xs),
          Text(
            label,
            style: context.textStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: accent ? null : KLiveColors.glassShadow,
            ),
          ),
        ],
      ),
    ),
  );
}

/// «الضيف: الاسم — اللقب».
class _LowerThird extends StatelessWidget {
  const new({required this.person, super.key});

  final VideoPodcastPerson person;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = person.guestTitle;
    final text = title == null || title.isEmpty
        ? l10n.podcastGuestLowerThirdName(person.name)
        : l10n.podcastGuestLowerThird(person.name, title);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.sm),
        border: const BorderDirectional(
          start: BorderSide(color: KBrandColors.red500, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.body.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// The hot seat card: the tag, the question, its votes, the asker's bubble
/// and the circular timer.
class _HotSeatCard extends StatelessWidget {
  const new({required this.hot, required this.asker, super.key});

  final VideoPodcastHotSeat hot;
  final VideoPodcastPerson asker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AskerBubble(hot: hot, asker: asker),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: KVideoPodcast.hotTag,
                          borderRadius: BorderRadius.circular(KRadius.xs),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            l10n.podcastShotHotSeat,
                            style: context.textStyles.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: l10n.podcastVotes(hot.votes),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 14,
                              color: KBrandColors.gold,
                            ),
                            Text(
                              KFormat.compactLatin(hot.votes),
                              style: context.textStyles.caption.copyWith(
                                fontFamily: KFonts.latin,
                                color: KBrandColors.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    l10n.podcastHotSeatFrom(asker.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.caption.copyWith(
                      color: KPodcast.soft,
                    ),
                  ),
                  const SizedBox(height: KSpacing.xxs),
                  Text(
                    hot.question,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

class _AskerBubble extends StatefulWidget {
  const new({required this.hot, required this.asker});

  final VideoPodcastHotSeat hot;
  final VideoPodcastPerson asker;

  @override
  State<_AskerBubble> createState() => _AskerBubbleState();
}

class _AskerBubbleState extends State<_AskerBubble> {
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
  Widget build(BuildContext context) {
    final ends = widget.hot.endsAt;
    final left = ends == null
        ? Duration.zero
        : ends.difference(clock.now()).isNegative
        ? Duration.zero
        : ends.difference(clock.now());
    final total = math.max(widget.hot.seconds, 1);
    final share = ends == null ? 0.0 : (left.inMilliseconds / (total * 1000));
    const size = KVideoPodcast.askerBubble;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: size + 8,
                child: CircularProgressIndicator(
                  value: share.clamp(0, 1),
                  strokeWidth: 3,
                  color: widget.asker.speaking
                      ? KVideoPodcast.speaking
                      : KBrandColors.red400,
                  backgroundColor: Colors.white24,
                ),
              ),
              PodcastAvatar(
                name: widget.asker.name,
                size: size,
                url: widget.asker.avatarUrl,
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.xxs),
        Text(
          podcastClock(left),
          style: context.textStyles.caption.copyWith(
            fontFamily: KFonts.latin,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// A neutral placeholder "video" frame for previews, goldens and demos: a
/// soft gradient and a silhouette (D40: never a real person's picture).
class VideoPodcastPlaceholderFrame extends StatelessWidget {
  const new({required this.seed, super.key});

  final int seed;

  static const _tones = [
    [Color(0xFF3B4A63), Color(0xFF1C2433)],
    [Color(0xFF4F3B5E), Color(0xFF241A2E)],
    [Color(0xFF2F5752), Color(0xFF15292A)],
    [Color(0xFF5C4A33), Color(0xFF2A2117)],
    [Color(0xFF34455A), Color(0xFF161E29)],
  ];

  @override
  Widget build(BuildContext context) {
    final tone = _tones[seed % _tones.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tone,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: const Alignment(0, 0.35),
          child: Icon(
            Icons.person_rounded,
            size: math.min(box.maxWidth, box.maxHeight) * 0.7,
            color: const Color(0x2EFFFFFF),
          ),
        ),
      ),
    );
  }
}
