import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D212: the hub's announced podcast episodes (`GET /live/podcasts/
/// scheduled`), refreshed with the podcast tab.
final FutureProvider<List<LiveScheduledPodcast>> scheduledPodcastsProvider =
    FutureProvider.autoDispose<List<LiveScheduledPodcast>>(
      (ref) => ref.watch(liveRepositoryProvider).scheduledPodcasts(),
    );

/// D212 geometry of the podcast hub cards (Kabso's own design).
abstract final class KPodcastHub {
  static const double inset = 14;
  static const double gap = 10;
  static const double radius = 16;
  static const double avatar = 28;
  static const double avatarOverlap = 9;
}

/// D212: the «بث بودكاست» tab's list — one full-width card per live
/// episode.
abstract final class PodcastHubList {
  static const listKey = Key('podcastHub.list');
  static Key cardKey(String id) => Key('podcastHub.card.$id');

  static Widget sliver({
    required List<LiveRoomCardData> rooms,
    ValueChanged<LiveRoomCardData>? onOpenRoom,
  }) => SliverPadding(
    key: listKey,
    padding: const EdgeInsets.fromLTRB(
      KPodcastHub.inset,
      KSpacing.xs,
      KPodcastHub.inset,
      KSpacing.lg,
    ),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: KPodcastHub.gap),
          child: PodcastHubCard(
            room: rooms[i],
            onOpen: onOpenRoom == null ? null : () => onOpenRoom(rooms[i]),
          ),
        ),
        childCount: rooms.length,
      ),
    ),
  );
}

/// A live podcast: the live tag and the listener count, the title, the
/// speakers' pictures stacked with their names, and the topic.
class PodcastHubCard extends StatelessWidget {
  const new({required this.room, super.key, this.onOpen});

  final LiveRoomCardData room;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final podcast = room.podcast;
    final people = <({String name, String? url})>[
      (name: room.hostName, url: null),
      for (final s in podcast?.speakers ?? const <LivePodcastSpeaker>[])
        (name: s.displayName, url: s.avatarUrl),
    ];
    final count = room.viewerCount;
    final card = Container(
      key: room.roomId == null ? null : PodcastHubList.cardKey(room.roomId!),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KPodcastHub.radius),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: KPodcast.liveTag,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '● ${l10n.podcastLiveTag}',
                  style: text.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.headphones_rounded, size: 15, color: p.textSecondary),
              const SizedBox(width: 3),
              Text(
                KFormat.compact(count, l10n),
                style: text.caption.copyWith(color: p.textSecondary),
              ),
              const Spacer(),
              if (podcast != null)
                Flexible(
                  child: Text(
                    l10n.podcastEpisode(podcast.episodeNumber),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: p.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            room.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyStrong.copyWith(
              fontSize: 15,
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stack(people: people),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  people.map((e) => e.name).join('، '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.caption.copyWith(color: p.textSecondary),
                ),
              ),
              if (podcast != null) ...[
                const SizedBox(width: 8),
                _TopicChip(label: podcastTopicLabel(l10n, podcast.topic)),
              ],
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: onOpen != null,
      label: [
        l10n.podcastLiveTag,
        room.title,
        people.map((e) => e.name).join('، '),
        l10n.podcastListeners(KFormat.compact(count, l10n)),
      ].join(' · '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: card,
      ),
    );
  }
}

class _Stack extends StatelessWidget {
  const new({required this.people});

  final List<({String name, String? url})> people;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(4).toList();
    const size = KPodcastHub.avatar;
    const pitch = size - KPodcastHub.avatarOverlap;
    return SizedBox(
      width: size + pitch * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, person) in shown.indexed)
            PositionedDirectional(
              start: pitch * i,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.palette.surfaceRaised,
                    width: 1.5,
                  ),
                ),
                child: PodcastAvatar(
                  name: person.name,
                  url: person.url,
                  size: size - 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: context.palette.surfaceOverlay,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Text(
      label,
      style: context.textStyles.caption.copyWith(
        color: context.palette.textSecondary,
      ),
    ),
  );
}

/// D212: the announced episodes above the live ones — a heading, then a
/// dashed card each with «🔔 ذكّرني» (it follows the host: the CP-016 C
/// reminder reaches the host's followers 15 minutes before). Nothing when
/// none is announced or the list failed (the live list says the rest).
class ScheduledPodcastsSection extends ConsumerWidget {
  const new({super.key});

  static const sectionKey = Key('podcastHub.scheduled');
  static Key remindKey(String id) => Key('podcastHub.remind.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(scheduledPodcastsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final p = context.palette;
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.fromLTRB(
        KPodcastHub.inset,
        KSpacing.xs,
        KPodcastHub.inset,
        KSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.podcastUpcoming,
            style: context.textStyles.bodyStrong.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 6),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: KPodcastHub.gap),
              child: ScheduledPodcastCard(episode: e),
            ),
        ],
      ),
    );
  }
}

class ScheduledPodcastCard extends ConsumerStatefulWidget {
  const new({required this.episode, super.key});

  final LiveScheduledPodcast episode;

  @override
  ConsumerState<ScheduledPodcastCard> createState() =>
      _ScheduledPodcastCardState();
}

class _ScheduledPodcastCardState extends ConsumerState<ScheduledPodcastCard> {
  late bool _reminder = widget.episode.reminder;
  bool _busy = false;

  Future<void> _remind() async {
    if (_reminder || _busy) return;
    setState(() => _busy = true);
    try {
      // A private host's follow is a request: no reminder until accepted.
      final state = await ref
          .read(profileRepositoryProvider)
          .follow(widget.episode.host.username);
      if (mounted) setState(() => _reminder = state.isFollowing);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final e = widget.episode;
    // Latin digits in both languages (KFormat, DESIGN_SYSTEM §3.3).
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when = l10n.liveScheduleWhen(
      KFormat.date(e.startsAt, locale),
      KFormat.time(e.startsAt, locale),
    );
    return CustomPaint(
      painter: _Dashed(color: p.border, radius: KPodcastHub.radius),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: p.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    when,
                    style: text.caption.copyWith(color: p.textSecondary),
                  ),
                ),
                _TopicChip(label: podcastTopicLabel(l10n, e.podcastTopic)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              e.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyStrong.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                PodcastAvatar(
                  name: e.host.displayName,
                  url: e.host.avatarUrl,
                  size: 26,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e.host.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption.copyWith(color: p.textSecondary),
                  ),
                ),
                TextButton.icon(
                  key: ScheduledPodcastsSection.remindKey(e.id),
                  onPressed: _reminder ? null : () => unawaited(_remind()),
                  style: TextButton.styleFrom(
                    foregroundColor: KPodcast.liveTag,
                    minimumSize: const Size(48, 40),
                  ),
                  icon: Icon(
                    _reminder
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _reminder ? l10n.podcastReminderOn : l10n.podcastRemindMe,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed rounded outline (an announced, not yet live, episode).
class _Dashed extends CustomPainter {
  const new({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.7),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color || old.radius != radius;
}

/// D212: «بث ستريمر» until D213 — an honest «قريباً», no list, no call.
class StreamerSoon extends StatelessWidget {
  const new({super.key});

  static const soonKey = Key('liveHub.streamerSoon');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Center(
      key: soonKey,
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_share_outlined, size: 48, color: p.textSecondary),
            const SizedBox(height: KSpacing.md),
            Text(
              l10n.liveStreamerSoonTitle,
              textAlign: TextAlign.center,
              style: context.textStyles.title.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              l10n.liveStreamerSoonBody,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
