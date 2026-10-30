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
          : _day(endsAt.toLocal().subtract(const Duration(milliseconds: 1)));
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

/// The hue of an event's bar: its tone (v1.50-social, D176), else a stable
/// hue from its id.
Color eventHue(EventSummary e) => switch (e.tone) {
  EventTone.red => KBrandColors.red500,
  EventTone.gold => const Color(0xFFE0A21B),
  EventTone.teal => const Color(0xFF14B8A6),
  EventTone.blue => const Color(0xFF4DA3FF),
  EventTone.pink => const Color(0xFFFF3B6B),
  EventTone.amber => const Color(0xFFF5A623),
  null => ProgramHues.of(e.id),
};

/// The month grid of the Event Center in the layout of the owner's
/// reference (D176): weekday names on the page colour, then full-width week
/// rows on a light grid (thin column lines), the dates large and centred,
/// days outside the month faded, and each event as a rounded tinted bar
/// over its days — its name, an optional second line (`summary`, a short
/// prize line) and a small «انتهت» or «رائج» tag over its start. Bars wrap
/// across weeks; overlapping ones take lanes. RTL mirrors the columns; the
/// week starts on the locale's first day (`firstDayOfWeekIndex`: Sunday in
/// English, Saturday in Arabic).
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

  // The reference's measured geometry (D176 spec, 393 lp wide).
  /// Space before the first and after the last column (the grid itself is
  /// full width).
  static const double gridInset = 10;

  /// A week row at least this tall; taller when its bars need it.
  static const double weekHeight = 127;

  /// The dates' centre from the row's top.
  static const double dateCentre = 25.5;

  /// The first lane's top from the row's top.
  static const double barsTop = 61;
  static const double barHeight = 27;
  static const double barHeightTwoLines = 48;
  static const double barGap = 6;
  static const double barInset = 4;
  static const int maxLanes = 3;

  static Key barKey(String eventId, int week) =>
      Key('events.bar.$eventId.$week');

  static Key tagKey(String eventId) => Key('events.tag.$eventId');

  /// The grid's background (the reference's light grey, from the palette).
  static Color gridColor(BuildContext context) {
    final p = context.palette;
    return Color.alphaBlend(
      p.textPrimary.withValues(alpha: 0.035),
      p.background,
    );
  }

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: gridInset),
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                for (final name in names)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          maxLines: 1,
                          style: t.label.copyWith(
                            color: p.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final (w, week) in weeks.indexed)
          _WeekRow(
            index: w,
            week: week,
            month: month,
            today: now,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

/// One week: the grid, the dates and the bars.
class _WeekRow extends StatelessWidget {
  const new({
    required this.index,
    required this.week,
    required this.month,
    required this.today,
    required this.onOpen,
  });

  final int index;
  final CalendarWeek week;
  final DateTime month;
  final DateTime today;
  final ValueChanged<EventSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final lanes = week.lanes.clamp(0, EventCalendar.maxLanes);
    // A lane is two lines tall when one of its bars has a second line.
    double laneHeight(int lane) =>
        week.segments.any((s) => s.lane == lane && s.event.summary != null)
        ? EventCalendar.barHeightTwoLines
        : EventCalendar.barHeight;
    final laneHeights = [
      for (var lane = 0; lane < lanes; lane++) laneHeight(lane),
    ];
    final laneTops = <double>[];
    var top = EventCalendar.barsTop;
    for (final h in laneHeights) {
      laneTops.add(top);
      top += h + EventCalendar.barGap;
    }
    final hidden = week.segments.where((s) => s.lane >= lanes).length;
    final height = [
      EventCalendar.weekHeight,
      top + (hidden > 0 ? 20 : 8),
    ].reduce((a, b) => a > b ? a : b);
    final line = p.border.withValues(alpha: 0.5);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final col = (constraints.maxWidth - 2 * EventCalendar.gridInset) / 7;
          double colStart(int i) => EventCalendar.gridInset + i * col;
          final segments = [
            for (final s in week.segments)
              if (s.lane < lanes) s,
          ];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: EventCalendar.gridColor(context),
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                ),
              ),
              for (var i = 1; i < 7; i++)
                PositionedDirectional(
                  start: colStart(i),
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(color: line),
                ),
              for (final (i, day) in week.days.indexed)
                PositionedDirectional(
                  start: colStart(i),
                  width: col,
                  top: EventCalendar.dateCentre - 16,
                  height: 32,
                  child: _DayNumber(
                    day: day,
                    inMonth: day.month == month.month,
                    today: day == today,
                  ),
                ),
              for (final s in segments)
                PositionedDirectional(
                  key: EventCalendar.barKey(s.event.id, index),
                  start: colStart(s.startCol) + EventCalendar.barInset,
                  width:
                      (s.endCol - s.startCol + 1) * col -
                      2 * EventCalendar.barInset,
                  top: laneTops[s.lane],
                  height: laneHeights[s.lane],
                  child: _Bar(segment: s, onOpen: onOpen),
                ),
              for (final s in segments)
                if (!s.continuesBefore && _tagOf(s.event) != null)
                  PositionedDirectional(
                    key: EventCalendar.tagKey(s.event.id),
                    start: colStart(s.startCol) + EventCalendar.barInset,
                    top: laneTops[s.lane] - 5,
                    child: ExcludeSemantics(
                      child: _BarTag(
                        label: _tagOf(s.event) == _Tag.ended
                            ? l10n.eventsEnded
                            : l10n.eventsFeatured,
                        color: _tagOf(s.event) == _Tag.ended
                            ? p.textTertiary
                            : KBrandColors.red500,
                      ),
                    ),
                  ),
              if (hidden > 0)
                PositionedDirectional(
                  start: EventCalendar.gridInset + KSpacing.xs,
                  bottom: KSpacing.xs,
                  child: Text(
                    l10n.eventsMore('$hidden'),
                    style: context.textStyles.caption.copyWith(
                      color: p.textTertiary,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _Tag { ended, featured }

/// «انتهت» for an ended event, else «رائج» when featured, else none.
_Tag? _tagOf(EventSummary e) => e.status == EventStatus.ended
    ? _Tag.ended
    : e.featured
    ? _Tag.featured
    : null;

class _BarTag extends StatelessWidget {
  const new({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(KRadius.pill),
      border: Border.all(color: context.palette.surfaceRaised),
    ),
    child: Text(
      label,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: context.textStyles.caption.copyWith(
        color: const Color(0xFFFFFFFF),
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        height: 1.25,
      ),
    ),
  );
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
      maxLines: 1,
      style: context.textStyles.title.copyWith(
        color: today
            ? p.onPrimary
            : inMonth
            ? p.textPrimary
            : p.textTertiary.withValues(alpha: 0.35),
        fontSize: 18.5,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
    return Center(
      child: today
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: p.primary,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 32,
                child: Center(child: FittedBox(child: text)),
              ),
            )
          : FittedBox(fit: BoxFit.scaleDown, child: text),
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
    final hue = eventHue(e);
    final ink = Color.lerp(hue, const Color(0xFF000000), 0.35)!;
    final textColor = ended ? ink.withValues(alpha: 0.5) : ink;
    final summary = e.summary;
    final radius = BorderRadius.circular(5);
    return Semantics(
      button: true,
      label: [
        e.title,
        ?summary,
        if (ended) l10n.eventsEnded,
        if (e.featured && !ended) l10n.eventsFeatured,
      ].join('، '),
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(
          hue.withValues(alpha: ended ? 0.13 : 0.2),
          p.surface,
        ),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => onOpen(e),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 9, end: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.15),
                  style: context.textStyles.caption.copyWith(
                    color: textColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (summary != null)
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 1.15),
                    style: context.textStyles.caption.copyWith(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.3,
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
