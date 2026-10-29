import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/application/programs_providers.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_calendar.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `YYYY-MM` of [month].
String monthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// "October 2026" / "أكتوبر 2026" with Latin digits.
String monthTitle(DateTime month, String localeTag) =>
    '${DateFormat.MMMM(localeTag).format(month)} ${month.year}';

/// `/events` (D166): the Event Center «مركز الفعاليات» in the layout of the
/// owner's reference — three tabs (calendar, permanent, regional), the intro
/// card and the month calendar with event bars. Events are created by the
/// team on the server; with none configured the lists are honestly empty.
class EventCenterScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialMonth});

  /// The first month shown (tests); else this month.
  final DateTime? initialMonth;

  static const introKey = Key('events.intro');
  static const monthTitleKey = Key('events.month');
  static const previousKey = Key('events.previous');
  static const nextKey = Key('events.next');
  static const emptyKey = Key('events.empty');

  static Key eventKey(String id) => Key('events.card.$id');

  @override
  ConsumerState<EventCenterScreen> createState() => _EventCenterScreenState();
}

class _EventCenterScreenState extends ConsumerState<EventCenterScreen> {
  int _tab = 0;
  late DateTime _month = () {
    final now = widget.initialMonth ?? DateTime.now();
    return DateTime(now.year, now.month);
  }();

  EventListKey get _key => switch (_tab) {
    1 => (tab: EventTab.permanent, month: null),
    2 => (tab: EventTab.regional, month: null),
    _ => (tab: EventTab.calendar, month: monthKey(_month)),
  };

  void _open(EventSummary e) =>
      unawaited(context.push(AppRoutes.event(e.id)));

  Future<void> _refresh() async {
    ref.invalidate(eventListProvider(_key));
    try {
      await ref.read(eventListProvider(_key).future);
    } on Object {
      // The page shows the failure with a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final key = _key;
    final list = ref.watch(eventListProvider(key));
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    final List<Widget> content = switch (list) {
      AsyncValue(:final value?) => _tab == 0
          ? [
              EventCalendar(
                month: _month,
                events: value.events,
                onOpen: _open,
              ),
              if (value.events.isEmpty)
                KEmptyState(
                  key: EventCenterScreen.emptyKey,
                  icon: Icons.event_busy_rounded,
                  title: l10n.eventsEmptyMonth,
                  message: l10n.eventsEmptyBody,
                  compact: true,
                ),
            ]
          : value.events.isEmpty
          ? [
              KEmptyState(
                key: EventCenterScreen.emptyKey,
                icon: _tab == 2
                    ? Icons.public_rounded
                    : Icons.event_available_rounded,
                title: _tab == 2 && value.country == null
                    ? l10n.eventsNoCountry
                    : l10n.eventsEmpty,
                message: _tab == 2 && value.country == null
                    ? l10n.eventsNoCountryBody
                    : l10n.eventsEmptyBody,
                compact: true,
              ),
            ]
          : [
              for (final e in value.events)
                _EventCard(event: e, localeTag: localeTag, onOpen: _open),
            ],
      AsyncValue(:final error?, isLoading: false) => [
        FailureErrorState(
          title: l10n.eventsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(eventListProvider(key)),
          compact: true,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(KSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };

    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.meHubEventCenter),
      ),
      body: Column(
        children: [
          KPrimaryTabs(
            labels: [
              l10n.eventsTabCalendar,
              l10n.eventsTabPermanent,
              l10n.eventsTabRegional,
            ],
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KSpacing.lg,
                  KSpacing.sm,
                  KSpacing.lg,
                  KSpacing.xl,
                ),
                children: [
                  if (_tab == 0) ...[
                    const _IntroCard(),
                    _MonthHeader(
                      title: l10n.eventsCalendarMonth(
                        monthTitle(_month, localeTag),
                      ),
                      onPrevious: () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                      onNext: () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                    ),
                  ],
                  ...content,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference's intro card, in Kabso tokens: a short explanation and a
/// calendar composed from icons (owner art can replace it).
class _IntroCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      key: EventCenterScreen.introKey,
      margin: const EdgeInsets.only(bottom: KSpacing.lg),
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.alphaBlend(p.primary.withValues(alpha: 0.12), p.surface),
            Color.alphaBlend(
              KBrandColors.gold.withValues(alpha: 0.14),
              p.surface,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(KRadius.lg),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.eventsIntroTitle,
                  style: t.title.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.eventsIntroBody,
                  style: t.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.md),
          const ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [KBrandColors.red400, KBrandColors.red600],
                ),
              ),
              child: SizedBox.square(
                dimension: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 34,
                      color: Color(0xFFFFFFFF),
                    ),
                    PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: KBrandColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const new({
    required this.title,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              key: EventCenterScreen.monthTitleKey,
              style: context.textStyles.title.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        IconButton(
          key: EventCenterScreen.previousKey,
          tooltip: l10n.eventsPreviousMonth,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          key: EventCenterScreen.nextKey,
          tooltip: l10n.eventsNextMonth,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// An event of the permanent and regional tabs: banner (or a token
/// gradient), title, dates and state.
class _EventCard extends StatelessWidget {
  const new({
    required this.event,
    required this.localeTag,
    required this.onOpen,
  });

  final EventSummary event;
  final String localeTag;
  final ValueChanged<EventSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final hue = ProgramHues.of(event.id);
    final dates = eventDates(l10n, event, localeTag);
    return Padding(
      key: EventCenterScreen.eventKey(event.id),
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Semantics(
        button: true,
        label: [event.title, dates, eventStatusLabel(l10n, event)].join('، '),
        excludeSemantics: true,
        child: Material(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(event),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EventBanner(event: event, hue: hue, height: 96),
                Padding(
                  padding: const EdgeInsets.all(KSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                            const SizedBox(height: KSpacing.xxs),
                            Text(
                              dates,
                              style: t.caption.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      EventStatusTag(event: event),
                    ],
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

/// «من … إلى …», «منذ …» for a permanent event without an end.
String eventDates(AppLocalizations l10n, EventSummary e, String localeTag) {
  final start = KFormat.date(e.startsAt, localeTag);
  final end = e.endsAt;
  return end == null
      ? l10n.eventsSince(start)
      : l10n.eventsDates(start, KFormat.date(end, localeTag));
}

String eventStatusLabel(AppLocalizations l10n, EventSummary e) =>
    switch (e.status) {
      EventStatus.upcoming => l10n.eventsUpcoming,
      EventStatus.running => l10n.eventsRunning,
      EventStatus.ended => l10n.eventsEnded,
    };

/// The state tag of an event («قريباً», «جارية», «انتهت»), «رائج» first
/// when featured and not ended.
class EventStatusTag extends StatelessWidget {
  const new({required this.event, super.key});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (event.featured && event.status != EventStatus.ended) ...[
          ProgramTag(l10n.eventsFeatured, color: KBrandColors.red500),
          const SizedBox(width: KSpacing.xxs),
        ],
        ProgramTag(
          eventStatusLabel(l10n, event),
          color: switch (event.status) {
            EventStatus.upcoming => p.info,
            EventStatus.running => p.success,
            EventStatus.ended => p.textTertiary,
          },
        ),
      ],
    );
  }
}

/// An event's banner picture, or a token gradient with an icon when there
/// is none (owner art).
class EventBanner extends StatelessWidget {
  const new({
    required this.event,
    required this.hue,
    required this.height,
    super.key,
  });

  final EventSummary event;
  final Color hue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = event.bannerUrl;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [hue, Color.lerp(hue, const Color(0xFF000000), 0.35)!],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.emoji_events_rounded,
          size: 40,
          color: Color(0xCCFFFFFF),
        ),
      ),
    );
    return SizedBox(
      height: height,
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
