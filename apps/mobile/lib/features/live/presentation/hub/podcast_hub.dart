import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D212: the hub's announced podcast episodes (`GET /live/podcasts/
/// scheduled`), refreshed with the party list (D342).
final FutureProvider<List<LiveScheduledPodcast>> scheduledPodcastsProvider =
    FutureProvider.autoDispose<List<LiveScheduledPodcast>>(
      (ref) => ref.watch(liveRepositoryProvider).scheduledPodcasts(),
    );

/// D212 geometry of the announced-podcast cards (Kabso's own design).
abstract final class KPodcastHub {
  static const double inset = 14;
  static const double gap = 10;
  static const double radius = 16;
}

/// D212: the announced episodes above the live ones (D342: above the party
/// page's mixed list; the podcast tab and its episode cards are gone) — a
/// heading, then a
/// dashed card each with «🔔 ذكّرني» (it follows the host: the CP-016 C
/// reminder reaches the host's followers 15 minutes before). Nothing when
/// none is announced or the list failed (the live list says the rest).
class ScheduledPodcastsSection extends ConsumerWidget {
  const new({super.key});

  static const sectionKey = Key('podcastHub.scheduled');
  static Key remindKey(String id) => Key('podcastHub.remind.$id');

  /// D363: the «فيديو» badge of an announced video episode.
  static const videoBadgeKey = Key('podcastHub.videoBadge');

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
                // D363: an announced video episode.
                if (e.video) ...[const _VideoBadge(), const SizedBox(width: 4)],
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

/// D363 (§10.157): the small «فيديو» badge of a video episode.
class _VideoBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Container(
    key: ScheduledPodcastsSection.videoBadgeKey,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: KPodcast.liveTag,
      borderRadius: BorderRadius.circular(KRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          context.l10n.podcastVideoBadge,
          style: context.textStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
