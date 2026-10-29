import 'package:flutter/foundation.dart' show immutable;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/program_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One event's bar inside one week: columns [startCol]…[endCol] (0 = the
/// week's first day, inclusive) on [lane].
@immutable
class CalendarSegment {
  const new({
    required this.event,
    required this.startCol,
    required this.endCol,
    required this.lane,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final EventSummary event;
  final int startCol;
  final int endCol;
  final int lane;

  /// The event started in an earlier week / goes on in a later one.
  final bool continuesBefore;
  final bool continuesAfter;
}

/// One row of the month grid: seven days and the bars over them.
@immutable
class CalendarWeek {
  const new({required this.days, required this.segments});

  final List<DateTime> days;
  final List<CalendarSegment> segments;

  int get lanes =>
      segments.fold(0, (max, s) => s.lane + 1 > max ? s.lane + 1 : max);
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Lays out [month] (any day in it) as weeks starting on [firstWeekday]
/// (0 = Sunday … 6 = Saturday, `MaterialLocalizations.firstDayOfWeekIndex`)
/// with every event as bars spanning its days in local time, wrapping
/// across weeks; overlapping bars take the lowest free lane.
List<CalendarWeek> layoutMonth(
  DateTime month,
  int firstWeekday,
  List<EventSummary> events,
) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final offset = (first.weekday % 7 - firstWeekday) % 7;
  final weeks = ((offset + daysInMonth) / 7).ceil();
  final gridStart = DateTime(first.year, first.month, 1 - offset);
  final result = <CalendarWeek>[];
  for (var w = 0; w < weeks; w++) {
    final days = [
      for (var d = 0; d < 7; d++)
        DateTime(gridStart.year, gridStart.month, gridStart.day + w * 7 + d),
    ];
    final weekStart = days.first;
    final weekEnd = days.last;
    final pieces = <(EventSummary, int, int, bool, bool)>[];
    for (final e in events) {
      final start = _day(e.startsAt.toLocal());
      final endsAt = e.endsAt;
      // The last day the event runs (its end is exclusive).
      final last = endsAt == null
          ? weekEnd
          : _day(
              endsAt.toLocal().subtract(const Duration(milliseconds: 1)),
            );
      if (last.isBefore(weekStart) || start.isAfter(weekEnd)) continue;
      final from = start.isBefore(weekStart) ? weekStart : start;
      final to = last.isAfter(weekEnd) ? weekEnd : last;
      pieces.add((
        e,
        days.indexOf(from),
        days.indexOf(to),
        start.isBefore(weekStart),
        last.isAfter(weekEnd),
      ));
    }
    pieces.sort((a, b) {
      final byStart = a.$2.compareTo(b.$2);
      if (byStart != 0) return byStart;
      return (b.$3 - b.$2).compareTo(a.$3 - a.$2);
    });
    final laneEnds = <int>[];
    final segments = <CalendarSegment>[];
    for (final (e, from, to, before, after) in pieces) {
      var lane = laneEnds.indexWhere((end) => end < from);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(to);
      } else {
        laneEnds[lane] = to;
      }
      segments.add(
        CalendarSegment(
          event: e,
          startCol: from,
          endCol: to,
          lane: lane,
          continuesBefore: before,
          continuesAfter: after,
        ),
      );
    }
    result.add(CalendarWeek(days: days, segments: segments));
  }
  return result;
}

/// The month grid of the Event Center (the reference's calendar): weekday
/// names, then each week's dates and its event bars. Days outside [month]
/// are greyed; bars carry «انتهت» (ended) or «رائج» (featured). RTL
/// mirrors the columns.
class EventCalendar extends StatelessWidget {
  const new({
    required this.month,
    required this.events,
    required this.onOpen,
    super.key,
    this.today,
  });

  final DateTime month;
  final List<EventSummary> events;
  final ValueChanged<EventSummary> onOpen;

  /// Today (tests pass a fixed day).
  final DateTime? today;

  static const double barHeight = 22;
  static const double barGap = 3;
  static const int maxLanes = 3;

  static Key barKey(String eventId, int week) =>
      Key('events.bar.$eventId.$week');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    final material = MaterialLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final firstWeekday = material.firstDayOfWeekIndex;
    final weeks = layoutMonth(month, firstWeekday, events);
    final now = _day(today ?? DateTime.now());
    final weekdayFormat = DateFormat.E(localeTag);
    // 2026-11-01 is a Sunday: weekday names from it, in display order.
    final names = [
      for (var i = 0; i < 7; i++)
        weekdayFormat.format(DateTime(2026, 11, 1 + (firstWeekday + i) % 7)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final name in names)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name,
                      maxLines: 1,
                      style: t.label.copyWith(color: p.textSecondary),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final (w, week) in weeks.indexed)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final day in week.days)
                        Expanded(
                          child: _DayNumber(
                            day: day,
                            inMonth: day.month == month.month,
                            today: day == now,
                          ),
                        ),
                    ],
                  ),
                  _bars(context, w, week),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _bars(BuildContext context, int w, CalendarWeek week) {
    final l10n = context.l10n;
    final p = context.palette;
    final lanes = week.lanes.clamp(0, maxLanes);
    final hidden = week.segments.where((s) => s.lane >= maxLanes).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: lanes == 0 ? KSpacing.md : lanes * (barHeight + barGap),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final col = constraints.maxWidth / 7;
              return Stack(
                children: [
                  for (final s in week.segments)
                    if (s.lane < maxLanes)
                      PositionedDirectional(
                        key: barKey(s.event.id, w),
                        start: s.startCol * col + (s.continuesBefore ? 0 : 2),
                        width:
                            (s.endCol - s.startCol + 1) * col -
                            (s.continuesBefore ? 0 : 2) -
                            (s.continuesAfter ? 0 : 2),
                        top: s.lane * (barHeight + barGap),
                        height: barHeight,
                        child: _Bar(segment: s, onOpen: onOpen),
                      ),
                ],
              );
            },
          ),
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: KSpacing.xs),
            child: Text(
              l10n.eventsMore('$hidden'),
              style: context.textStyles.caption.copyWith(
                color: p.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayNumber extends StatelessWidget {
  const new({required this.day, required this.inMonth, required this.today});

  final DateTime day;
  final bool inMonth;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Text(
      day.day.toString().padLeft(2, '0'),
      textAlign: TextAlign.center,
      style: context.textStyles.bodyStrong.copyWith(
        color: today
            ? p.onPrimary
            : inMonth
            ? p.textPrimary
            : p.textTertiary.withValues(alpha: 0.5),
        fontWeight: inMonth ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
      child: Center(
        child: today
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 30,
                  child: Center(child: text),
                ),
              )
            : SizedBox(height: 30, child: Center(child: text)),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.segment, required this.onOpen});

  final CalendarSegment segment;
  final ValueChanged<EventSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final e = segment.event;
    final ended = e.status == EventStatus.ended;
    final hue = ProgramHues.of(e.id);
    final radius = BorderRadiusDirectional.horizontal(
      start: Radius.circular(segment.continuesBefore ? 0 : KRadius.sm),
      end: Radius.circular(segment.continuesAfter ? 0 : KRadius.sm),
    );
    return Semantics(
      button: true,
      label: [
        e.title,
        if (ended) l10n.eventsEnded,
        if (e.featured) l10n.eventsFeatured,
      ].join('، '),
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(
          hue.withValues(alpha: ended ? 0.10 : 0.22),
          p.surface,
        ),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius.resolve(Directionality.of(context)),
          onTap: () => onOpen(e),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
            child: Row(
              children: [
                if (!segment.continuesBefore && ended) ...[
                  ProgramTag(l10n.eventsEnded, color: p.textTertiary),
                  const SizedBox(width: KSpacing.xxs),
                ] else if (!segment.continuesBefore && e.featured) ...[
                  ProgramTag(l10n.eventsFeatured, color: KBrandColors.red500),
                  const SizedBox(width: KSpacing.xxs),
                ],
                Expanded(
                  child: Text(
                    e.title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: context.textStyles.caption.copyWith(
                      color: ended ? p.textTertiary : p.textPrimary,
                      fontWeight: FontWeight.w700,
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
}
