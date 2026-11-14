import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_podcast_video.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_sheets.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_stage.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D363 scope extension (owner 2026-11-11, CONVENTIONS §10.157): the video
/// podcast's studio pieces drawn over the stage — the segments' progress
/// bar, the segment card on a change, the closing card, the listener
/// question on screen, the host's manual-control chip with «تلقائي», the
/// host's backstage strip, and the backstage guest's self-check. Kabso's
/// live glass (the chat scrim, the white 24 % edge), its red and the
/// podcast's gold only.
abstract final class KPodcastStudio {
  /// The segment card stays this long after a segment starts.
  static const Duration segmentCard = Duration(seconds: 5);

  /// The progress bar: 3 dp, the segments 3 dp apart.
  static const double bar = 3;
  static const double barGap = 3;

  /// The backstage strip's small video.
  static const Size backstageVideo = Size(40, 56);

  /// The self-check's preview.
  static const Size checkPreview = Size(180, 260);

  /// The glass of the cards (as the hot seat card and the lower third).
  static const Color card = KLiveColors.chatScrim;
  static const Color edge = Colors.white24;
}

/// Keys of the studio pieces.
abstract final class VideoPodcastStudioKeys {
  static const progress = Key('video-podcast-segments-progress');
  static const segmentCard = Key('video-podcast-segment-card');
  static const closingCard = Key('video-podcast-closing-card');
  static const nextSegment = Key('video-podcast-next-segment');
  static const questionCard = Key('video-podcast-question-card');
  static const hideQuestion = Key('video-podcast-hide-question');
  static const controlChip = Key('video-podcast-control-chip');
  static const auto = Key('video-podcast-auto');
  static const backstageStrip = Key('video-podcast-backstage-strip');
  static Key onAir(String userId) => Key('video-podcast-on-air-$userId');
  static const selfCheck = Key('video-podcast-self-check');
  static const leaveBackstage = Key('video-podcast-leave-backstage');
}

/// The segments' thin progress bar: one piece per segment, the done ones
/// and the current one filled (all of them on the closing card).
class VideoPodcastSegmentsBar extends StatelessWidget {
  const new({required this.studio, super.key});

  final LivePodcastStudio studio;

  @override
  Widget build(BuildContext context) {
    final total = studio.segments.length;
    final current = studio.closing ? total : (studio.segmentIndex ?? -1) + 1;
    return Semantics(
      label: current >= 1 && !studio.closing
          ? context.l10n.podcastSegmentOf(current, total)
          : context.l10n.podcastSegmentsCount(total),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < total; i += 1) ...[
            if (i > 0) const SizedBox(width: KPodcastStudio.barGap),
            Expanded(
              child: Container(
                height: KPodcastStudio.bar,
                decoration: BoxDecoration(
                  color: i < current ? KBrandColors.red500 : Colors.white24,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «الفقرة 2 من 5 · العنوان» (shown [KPodcastStudio.segmentCard] after a
/// segment starts).
class VideoPodcastSegmentCard extends StatelessWidget {
  const new({required this.studio, super.key});

  final LivePodcastStudio studio;

  @override
  Widget build(BuildContext context) {
    final segment = studio.segment!;
    final l10n = context.l10n;
    final text = context.textStyles;
    return _Card(
      accent: KBrandColors.red500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.podcastSegmentOf(
              studio.segmentIndex! + 1,
              studio.segments.length,
            ),
            style: text.caption.copyWith(
              color: KPodcast.soft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: KSpacing.xxs),
          Row(
            children: [
              Flexible(
                child: Text(
                  segment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyStrong.copyWith(color: Colors.white),
                ),
              ),
              if (segment.minutes case final m?) ...[
                const SizedBox(width: KSpacing.sm),
                Text(
                  l10n.podcastMinutes(m),
                  style: text.caption.copyWith(color: KPodcast.soft),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Whether the card shows at [now] (a segment started a moment ago).
  static bool shows(LivePodcastStudio studio, DateTime now) {
    final at = studio.segmentStartedAt;
    if (studio.closing || studio.segment == null || at == null) return false;
    final since = now.difference(at);
    return !since.isNegative && since < KPodcastStudio.segmentCard;
  }
}

/// The closing card «نهاية الحلقة — شكراً لمتابعتكم».
class VideoPodcastClosingCard extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return _Card(
      accent: KBrandColors.gold,
      child: Row(
        children: [
          const Icon(
            Icons.celebration_rounded,
            color: KBrandColors.gold,
            size: 28,
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.podcastClosingTitle,
                  style: text.bodyStrong.copyWith(color: Colors.white),
                ),
                Text(
                  l10n.podcastClosingBody,
                  style: text.caption.copyWith(color: KPodcast.soft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The listener question on screen: «سؤال الجمهور», the asker's picture
/// and name, the question; the host's ✕ hides it.
class VideoPodcastQuestionCard extends StatelessWidget {
  const new({required this.question, super.key, this.onHide});

  final LivePodcastOnScreen question;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final user = question.user;
    return _Card(
      accent: KBrandColors.gold,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PodcastAvatar(name: user.displayName, size: 40, url: user.avatarUrl),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: KBrandColors.gold,
                        borderRadius: BorderRadius.circular(KRadius.xs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          l10n.podcastOnScreenTag,
                          style: text.caption.copyWith(
                            color: const Color(0xFF1C1B1F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpacing.xs),
                    Flexible(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.caption.copyWith(color: KPodcast.soft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.xxs),
                Text(
                  question.question,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onHide != null)
            SizedBox.square(
              dimension: 32,
              child: IconButton(
                key: VideoPodcastStudioKeys.hideQuestion,
                tooltip: l10n.podcastOnScreenHide,
                padding: EdgeInsets.zero,
                onPressed: onHide,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The host's manual control as a chip — «مثبّت: عمر» / «تخطيط ثابت:
/// نقاش» — and, for the host, the red «تلقائي» that gives the shot back to
/// the director.
class VideoPodcastControlChip extends StatelessWidget {
  const new({
    required this.studio,
    required this.nameOf,
    super.key,
    this.onAuto,
  });

  final LivePodcastStudio studio;
  final String? Function(String userId) nameOf;
  final VoidCallback? onAuto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pin = studio.pinUserId;
    final name = pin == null ? null : nameOf(pin);
    final layout = studio.layout;
    final label = name != null
        ? l10n.podcastControlPinned(name)
        : l10n.podcastControlLayout(
            podcastShotLabel(l10n, layout ?? PodcastShotKind.speaker),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VideoPodcastGlassChip(
          key: VideoPodcastStudioKeys.controlChip,
          icon: name != null ? Icons.push_pin_rounded : Icons.lock_rounded,
          label: label,
        ),
        if (onAuto != null) ...[
          const SizedBox(width: KSpacing.xs),
          Semantics(
            button: true,
            child: GestureDetector(
              key: VideoPodcastStudioKeys.auto,
              onTap: onAuto,
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Center(
                  widthFactor: 1,
                  child: VideoPodcastGlassChip(
                    icon: Icons.movie_filter_rounded,
                    label: l10n.podcastDirectorAuto,
                    accent: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The host's «الفقرة التالية» (or «ابدأ الفقرات» before the first).
class VideoPodcastNextSegment extends StatelessWidget {
  const new({required this.started, required this.onTap, super.key});

  final bool started;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      child: GestureDetector(
        key: VideoPodcastStudioKeys.nextSegment,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Center(
            widthFactor: 1,
            child: VideoPodcastGlassChip(
              icon: Icons.skip_next_rounded,
              label: started
                  ? l10n.podcastSegmentNext
                  : l10n.podcastSegmentStart,
            ),
          ),
        ),
      ),
    );
  }
}

/// A guest waiting backstage, as the host's strip shows them.
@immutable
class VideoPodcastBackstageGuest {
  const new({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.speaking = false,
    this.seatIndex = 1,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final bool speaking;
  final int seatIndex;
}

/// The host's backstage strip «خلف الكواليس»: each guest's small video
/// (their self-check, seen by the host only), the speaking wave and «على
/// الهواء».
class VideoPodcastBackstageStrip extends StatelessWidget {
  const new({
    required this.guests,
    required this.videoOf,
    required this.onAir,
    super.key,
  });

  final List<VideoPodcastBackstageGuest> guests;
  final VideoPodcastVideoOf videoOf;
  final ValueChanged<VideoPodcastBackstageGuest>? onAir;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return _Card(
      key: VideoPodcastStudioKeys.backstageStrip,
      accent: KPodcast.hostTag,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.meeting_room_rounded,
                size: 14,
                color: KPodcast.hostTag,
              ),
              const SizedBox(width: KSpacing.xs),
              Text(
                l10n.podcastBackstage,
                style: text.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final g in guests) ...[
            const SizedBox(height: KSpacing.xs),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  child: SizedBox(
                    width: KPodcastStudio.backstageVideo.width,
                    height: KPodcastStudio.backstageVideo.height,
                    child:
                        videoOf(g.userId) ??
                        ColoredBox(
                          color: KVideoPodcast.emptyFrame.first,
                          child: Center(
                            child: PodcastAvatar(
                              name: g.name,
                              size: 28,
                              url: g.avatarUrl,
                            ),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      VideoPodcastWave(on: g.speaking),
                    ],
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton(
                  key: VideoPodcastStudioKeys.onAir(g.userId),
                  onPressed: onAir == null ? null : () => onAir!(g),
                  style: FilledButton.styleFrom(
                    backgroundColor: KBrandColors.red500,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(64, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.podcastBringOnAir),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The backstage guest's self-check: their own camera (seen by the host
/// only), the microphone's state, and «مغادرة الكواليس» (back to the
/// audience).
class VideoPodcastBackstageCheck extends StatelessWidget {
  const new({
    required this.preview,
    required this.speaking,
    required this.name,
    super.key,
    this.avatarUrl,
    this.onLeave,
  });

  /// The camera preview; null = the camera is off.
  final Widget? preview;
  final bool speaking;
  final String name;
  final String? avatarUrl;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return ColoredBox(
      key: VideoPodcastStudioKeys.selfCheck,
      color: const Color(0xB3000000),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
            child: _Card(
              accent: KPodcast.hostTag,
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.meeting_room_rounded,
                        size: 18,
                        color: KPodcast.hostTag,
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Text(
                        l10n.podcastBackstageCheckTitle,
                        style: text.bodyStrong.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.lg),
                    child: SizedBox(
                      width: KPodcastStudio.checkPreview.width,
                      height: KPodcastStudio.checkPreview.height,
                      child:
                          preview ??
                          ColoredBox(
                            color: KVideoPodcast.emptyFrame.first,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PodcastAvatar(
                                  name: name,
                                  size: 64,
                                  url: avatarUrl,
                                ),
                                const SizedBox(height: KSpacing.sm),
                                Text(
                                  l10n.podcastBackstageCameraOff,
                                  style: text.caption.copyWith(
                                    color: KPodcast.soft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: KSpacing.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        speaking ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 16,
                        color: speaking ? KPodcast.speakingRing : KPodcast.soft,
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Text(
                        speaking
                            ? l10n.podcastBackstageMicOk
                            : l10n.podcastBackstageMicQuiet,
                        style: text.caption.copyWith(
                          color: speaking
                              ? KPodcast.speakingRing
                              : KPodcast.soft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs),
                      VideoPodcastWave(on: speaking),
                    ],
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Text(
                    l10n.podcastBackstageCheckBody,
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(color: Colors.white),
                  ),
                  if (onLeave != null) ...[
                    const SizedBox(height: KSpacing.md),
                    OutlinedButton(
                      key: VideoPodcastStudioKeys.leaveBackstage,
                      onPressed: onLeave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(140, 40),
                      ),
                      child: Text(l10n.podcastBackstageLeave),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The studio's glass card: the chat scrim, the white 24 % edge and a
/// coloured start edge (as the lower third).
class _Card extends StatelessWidget {
  const new({
    required this.child,
    required this.accent,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(KRadius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: KPodcastStudio.edge),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KPodcastStudio.card,
            border: BorderDirectional(
              start: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
